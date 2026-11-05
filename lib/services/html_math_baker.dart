// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Builds a temporary, trusted MathJax runtime and validates its persisted SVG.
///
/// Imported scripts are removed before this service is used. Only Not3's
/// bundled MathJax asset runs, and the stored result contains no JavaScript.
class HtmlMathBaker {
  const HtmlMathBaker._();

  static const assetPath = 'assets/mathjax/tex-svg-full-3.2.2.js';
  static const maximumBakedBytes = 12 * 1024 * 1024;
  static const maximumFormulaCount = 1000;
  static const _sourceMeta = 'not3-math-source';
  static const _macrosMeta = 'not3-math-macros';
  static const _bakedMeta = 'not3-math-baked';
  static const _version = 'mathjax-3.2.2-svg';
  static const _runtimeNonce = 'not3-math-runtime-v1';
  static const _activeContentSelector =
      'script, iframe, frame, frameset, object, embed, foreignobject, '
      'form, input, button, textarea, select, option, video, audio, '
      'set, animate, animatemotion, animatetransform, discard';

  static final RegExp _texDelimiter = RegExp(
    r'\\\([\s\S]*?\\\)|\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$',
  );

  static const _offlineCsp =
      "default-src 'none'; img-src data:; font-src data:; "
      "style-src 'unsafe-inline'; script-src 'none'; connect-src 'none'; "
      "media-src 'none'; frame-src 'none'; object-src 'none'; "
      "base-uri 'none'; form-action 'none'";

  static const _runtimeCsp =
      "default-src 'none'; img-src data:; font-src data:; "
      "style-src 'unsafe-inline'; script-src 'nonce-$_runtimeNonce'; "
      "connect-src 'none'; media-src 'none'; frame-src 'none'; "
      "object-src 'none'; base-uri 'none'; form-action 'none'";

  static int formulaCount(dom.Document document) =>
      _texDelimiter.allMatches(document.body?.text ?? '').length;

  /// Records safe declarative macro configuration before source scripts are
  /// discarded. The actual imported script is never retained or executed.
  static void preserveSourceConfiguration(
    dom.Document document,
    String originalSource,
  ) {
    if (formulaCount(document) == 0) return;
    final head = document.head ?? dom.Element.tag('head');
    if (head.parent == null) {
      (document.documentElement ?? document).nodes.insert(0, head);
    }
    head.append(
      dom.Element.tag('meta')
        ..attributes['name'] = _sourceMeta
        ..attributes['content'] = 'tex',
    );

    final macros = _extractSafeMacros(originalSource);
    if (macros.isEmpty) return;
    head.append(
      dom.Element.tag('meta')
        ..attributes['name'] = _macrosMeta
        ..attributes['content'] = base64UrlEncode(
          utf8.encode(jsonEncode(macros)),
        ),
    );
  }

  static bool needsBake(String html) {
    final document = html_parser.parse(html);
    if (document.querySelector('meta[name="$_bakedMeta"]') != null) {
      return false;
    }
    if (document.querySelector('meta[name="$_sourceMeta"]') != null) {
      return true;
    }
    return _texDelimiter.hasMatch(document.body?.text ?? '');
  }

  /// Adds the bundled renderer to an in-memory copy. This string is never
  /// written to note storage.
  static String runtimeHtml(String sanitizedHtml, String mathJaxSource) {
    final document = html_parser.parse(sanitizedHtml);
    final html = document.documentElement ?? dom.Element.tag('html');
    final head = document.head ?? dom.Element.tag('head');
    if (head.parent == null) html.nodes.insert(0, head);
    _removeActiveContent(document);
    _validatePassiveTree(document);
    _setScriptPolicy(head, allowTrustedInlineScript: true);

    final macros = _readMacros(document);
    final config = <String, Object>{
      'tex': <String, Object>{
        'packages': <String, Object>{
          '[-]': <String>['html', 'require', 'autoload'],
        },
        'inlineMath': <List<String>>[
          <String>['\\(', '\\)'],
        ],
        'displayMath': <List<String>>[
          <String>['\\[', '\\]'],
          <String>['\$\$', '\$\$'],
        ],
        if (macros.isNotEmpty) 'macros': macros,
      },
      'svg': <String, Object>{'fontCache': 'global'},
      'startup': <String, Object>{'typeset': false},
    };

    head.append(
      dom.Element.tag('script')
        ..attributes['data-not3-math-runtime'] = 'config'
        ..attributes['nonce'] = _runtimeNonce
        ..text = 'window.MathJax = ${jsonEncode(config)};',
    );
    head.append(
      dom.Element.tag('script')
        ..attributes['data-not3-math-runtime'] = 'library'
        ..attributes['nonce'] = _runtimeNonce
        ..text = mathJaxSource,
    );
    head.append(
      dom.Element.tag('script')
        ..attributes['data-not3-math-runtime'] = 'bake'
        ..attributes['nonce'] = _runtimeNonce
        ..text = _bootstrap,
    );
    return '<!doctype html>\n${html.outerHtml}';
  }

  /// Removes the temporary runtime, restores the offline CSP, and rejects any
  /// active content or external SVG references before persistence.
  static String sanitizeBaked(String bakedHtml) {
    if (utf8.encode(bakedHtml).length > maximumBakedBytes) {
      throw const FormatException('Rendered math output is too large.');
    }
    final document = html_parser.parse(bakedHtml);
    final html = document.documentElement ?? dom.Element.tag('html');
    final head = document.head ?? dom.Element.tag('head');
    if (head.parent == null) html.nodes.insert(0, head);

    _removeActiveContent(document);

    for (final element in document.querySelectorAll('*')) {
      final inMath = _isInMath(element);
      for (final name in element.attributes.keys.toList()) {
        final lower = name.toString().toLowerCase();
        final value = element.attributes[name] ?? '';
        if (lower.startsWith('on') || lower == 'srcdoc') {
          element.attributes.remove(name);
        } else if ((lower == 'href' || lower == 'xlink:href') &&
            !_isAllowedHref(element, value)) {
          throw const FormatException('Rendered math contains an unsafe link.');
        } else if (const {
              'src',
              'srcset',
              'poster',
              'background',
              'action',
              'formaction',
            }.contains(lower) &&
            !_isAllowedResourceAttribute(element, lower, value)) {
          throw const FormatException(
            'Rendered math contains an unsafe resource.',
          );
        } else if (inMath && lower == 'style' && _hasUnsafeCss(value)) {
          element.attributes.remove(name);
        }
      }
    }

    _setScriptPolicy(head, allowTrustedInlineScript: false);
    head
        .querySelectorAll('meta[name="$_bakedMeta"]')
        .forEach((e) => e.remove());
    head.append(
      dom.Element.tag('meta')
        ..attributes['name'] = _bakedMeta
        ..attributes['content'] = _version,
    );
    final output = '<!doctype html>\n${html.outerHtml}';
    if (utf8.encode(output).length > maximumBakedBytes) {
      throw const FormatException('Rendered math output is too large.');
    }
    return output;
  }

  static Map<String, Object> _readMacros(dom.Document document) {
    final encoded = document
        .querySelector('meta[name="$_macrosMeta"]')
        ?.attributes['content'];
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      final value = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (value is! Map) return const {};
      return {
        for (final entry in value.entries)
          if (entry.key is String &&
              (entry.value is String || entry.value is List))
            entry.key as String: entry.value as Object,
      };
    } catch (_) {
      return const {};
    }
  }

  static void _setScriptPolicy(
    dom.Element head, {
    required bool allowTrustedInlineScript,
  }) {
    head.querySelectorAll('meta[http-equiv]').forEach((meta) => meta.remove());
    final csp = dom.Element.tag('meta')
      ..attributes['http-equiv'] = 'Content-Security-Policy';
    head.nodes.insert(0, csp);
    csp.attributes['content'] = allowTrustedInlineScript
        ? _runtimeCsp
        : _offlineCsp;
  }

  static void _removeActiveContent(dom.Document document) {
    for (final element
        in document.querySelectorAll(_activeContentSelector).toList()) {
      element.remove();
    }
  }

  static void _validatePassiveTree(dom.Document document) {
    for (final element in document.querySelectorAll('*')) {
      for (final name in element.attributes.keys.toList()) {
        final lower = name.toString().toLowerCase();
        final value = element.attributes[name] ?? '';
        if (lower.startsWith('on') ||
            lower == 'srcdoc' ||
            lower == 'contenteditable') {
          element.attributes.remove(name);
        } else if ((lower == 'href' || lower == 'xlink:href') &&
            !_isAllowedHref(element, value)) {
          throw const FormatException('HTML contains an unsafe link.');
        } else if (const {
              'src',
              'srcset',
              'poster',
              'background',
              'action',
              'formaction',
            }.contains(lower) &&
            !_isAllowedResourceAttribute(element, lower, value)) {
          throw const FormatException('HTML contains an unsafe resource.');
        }
      }
    }
  }

  static bool _isInMath(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      if (current.localName == 'mjx-container' ||
          current.attributes['id'] == 'MJX-SVG-global-cache') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  static bool _isAllowedResourceAttribute(
    dom.Element element,
    String name,
    String value,
  ) {
    if (element.localName != 'img' || name != 'src') return false;
    return RegExp(
      r'^data:image/(png|jpe?g)(?:;[^,]*)?;base64,',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static bool _isAllowedHref(dom.Element element, String value) {
    if (value.startsWith('#')) return true;
    if (element.localName != 'a') return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        const {'http', 'https', 'mailto'}.contains(uri.scheme);
  }

  static bool _hasUnsafeCss(String css) {
    final lower = css.toLowerCase();
    return lower.contains('url(') ||
        lower.contains('@import') ||
        lower.contains('expression(') ||
        lower.contains('javascript:') ||
        lower.contains('behavior:') ||
        lower.contains('-moz-binding') ||
        RegExp(r'position\s*:\s*(fixed|sticky)').hasMatch(lower);
  }

  static Map<String, Object> _extractSafeMacros(String source) {
    final match = RegExp(r'\bmacros\s*:').firstMatch(source);
    if (match == null) return const {};
    final open = source.indexOf('{', match.end);
    if (open < 0) return const {};
    final close = _matchingDelimiter(source, open, '{', '}');
    if (close == null) return const {};

    final result = <String, Object>{};
    for (final entry in _splitTopLevel(source.substring(open + 1, close))) {
      if (result.length >= 64) break;
      final colon = _topLevelColon(entry);
      if (colon < 0) continue;
      final key = _parseKey(entry.substring(0, colon));
      if (key == null) continue;
      final value = _parseMacroValue(entry.substring(colon + 1));
      if (value != null) result[key] = value;
    }
    return result;
  }

  static String? _parseKey(String raw) {
    final value = raw.trim();
    final unquoted = _parseJsString(value) ?? value;
    return RegExp(r'^[A-Za-z][A-Za-z0-9]{0,31}$').hasMatch(unquoted)
        ? unquoted
        : null;
  }

  static Object? _parseMacroValue(String raw) {
    final value = raw.trim();
    final direct = _parseJsString(value);
    if (direct != null) return _sanitizeReplacement(direct);
    if (!value.startsWith('[') || !value.endsWith(']')) return null;
    final parts = _splitTopLevel(value.substring(1, value.length - 1));
    if (parts.isEmpty || parts.length > 2) return null;
    final replacement = _parseJsString(parts.first.trim());
    if (replacement == null) return null;
    final sanitized = _sanitizeReplacement(replacement);
    if (sanitized == null) return null;
    if (parts.length == 1) return <Object>[sanitized];
    final arguments = int.tryParse(parts[1].trim());
    if (arguments == null || arguments < 0 || arguments > 9) return null;
    return <Object>[sanitized, arguments];
  }

  static String? _sanitizeReplacement(String value) {
    if (value.length > 512 || value.contains('<') || value.contains('>')) {
      return null;
    }
    final classWrapper = RegExp(
      r'^\\class\{[A-Za-z][A-Za-z0-9_-]{0,31}\}\{(#[1-9])\}$',
    ).firstMatch(value);
    if (classWrapper != null) return classWrapper.group(1);
    if (RegExp(
      r'\\(?:class|href|url|style|cssId|htmlData|htmlStyle|require|includegraphics)\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return null;
    }
    return value;
  }

  static String? _parseJsString(String raw) {
    if (raw.length < 2) return null;
    final quote = raw.codeUnitAt(0);
    if ((quote != 0x22 && quote != 0x27) ||
        raw.codeUnitAt(raw.length - 1) != quote) {
      return null;
    }
    final out = StringBuffer();
    for (var index = 1; index < raw.length - 1; index++) {
      final code = raw.codeUnitAt(index);
      if (code != 0x5c) {
        out.writeCharCode(code);
        continue;
      }
      if (++index >= raw.length - 1) return null;
      final escaped = raw.codeUnitAt(index);
      switch (escaped) {
        case 0x6e:
          out.write('\n');
        case 0x72:
          out.write('\r');
        case 0x74:
          out.write('\t');
        default:
          out.writeCharCode(escaped);
      }
    }
    return out.toString();
  }

  static int? _matchingDelimiter(
    String source,
    int open,
    String opener,
    String closer,
  ) {
    var depth = 0;
    int? quote;
    var escaped = false;
    for (var index = open; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == quote) {
          quote = null;
        }
        continue;
      }
      if (code == 0x22 || code == 0x27) {
        quote = code;
      } else if (source[index] == opener) {
        depth++;
      } else if (source[index] == closer && --depth == 0) {
        return index;
      }
    }
    return null;
  }

  static List<String> _splitTopLevel(String source) {
    final parts = <String>[];
    var start = 0;
    var square = 0;
    var curly = 0;
    var round = 0;
    int? quote;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == quote) {
          quote = null;
        }
        continue;
      }
      if (code == 0x22 || code == 0x27) {
        quote = code;
        continue;
      }
      switch (source[index]) {
        case '[':
          square++;
        case ']':
          square--;
        case '{':
          curly++;
        case '}':
          curly--;
        case '(':
          round++;
        case ')':
          round--;
        case ',':
          if (square == 0 && curly == 0 && round == 0) {
            parts.add(source.substring(start, index).trim());
            start = index + 1;
          }
      }
    }
    final tail = source.substring(start).trim();
    if (tail.isNotEmpty) parts.add(tail);
    return parts;
  }

  static int _topLevelColon(String source) {
    var square = 0;
    var curly = 0;
    var round = 0;
    int? quote;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == quote) {
          quote = null;
        }
        continue;
      }
      if (code == 0x22 || code == 0x27) {
        quote = code;
        continue;
      }
      switch (source[index]) {
        case '[':
          square++;
        case ']':
          square--;
        case '{':
          curly++;
        case '}':
          curly--;
        case '(':
          round++;
        case ')':
          round--;
        case ':':
          if (square == 0 && curly == 0 && round == 0) return index;
      }
    }
    return -1;
  }

  static const _bootstrap = r'''
const not3MathTimeout = new Promise((_, reject) => {
  setTimeout(() => reject(new Error('Math rendering timed out')), 10000);
});
window.__not3MathReady = Promise.race([
  window.MathJax.startup.promise.then(() => window.MathJax.typesetPromise()),
  not3MathTimeout
])
  .then(() => {
    document.querySelectorAll('script[data-not3-math-runtime]')
      .forEach((element) => element.remove());
    const csp = document.querySelector(
      'meta[http-equiv="Content-Security-Policy"]'
    );
    if (csp) {
      csp.content = csp.content.replace(
        /script-src\s+[^;]+/,
        "script-src 'none'"
      );
    }
    return '<!doctype html>\n' + document.documentElement.outerHTML;
  })
  .catch((error) => {
    window.__not3MathError = String(error);
    return null;
  });
''';
}
