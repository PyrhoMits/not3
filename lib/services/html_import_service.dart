// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

enum HtmlImportFailureKind {
  unsupportedPlatform,
  unsupportedFileType,
  missingFile,
  empty,
  tooLarge,
  tooComplex,
  invalidEncoding,
  unsupportedResource,
  oversizedImage,
  invalidImage,
}

class HtmlImportException implements Exception {
  const HtmlImportException(this.kind, [this.details]);

  final HtmlImportFailureKind kind;
  final String? details;

  @override
  String toString() =>
      'HtmlImportException($kind${details == null ? '' : ': $details'})';
}

class HtmlPickedFile {
  const HtmlPickedFile({required this.path, required this.displayName});

  final String path;
  final String displayName;
}

class HtmlPreparedDocument {
  const HtmlPreparedDocument({
    required this.html,
    required this.suggestedTitle,
    required this.sourceBytes,
    required this.removedActiveContent,
  });

  final String html;
  final String suggestedTitle;
  final int sourceBytes;
  final bool removedActiveContent;

  bool get requiresLargeFileConfirmation =>
      sourceBytes > HtmlImportService.warningBytes;
}

/// Validates and normalizes one standalone, self-contained HTML document.
class HtmlImportService {
  const HtmlImportService();

  static const warningBytes = 3 * 1024 * 1024;
  static const maximumBytes = 5 * 1024 * 1024;
  static const maximumMarkupMarkers = 50000;
  static const maximumImagePixels = 32 * 1000 * 1000;
  static const maximumTotalImagePixels = 64 * 1000 * 1000;
  static const maximumImageAxis = 8192;

  bool get isSupported => Platform.isAndroid;

  Future<HtmlPickedFile?> pick() async {
    if (!isSupported) {
      throw const HtmlImportException(
        HtmlImportFailureKind.unsupportedPlatform,
      );
    }
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
    );
    final path = picked?.path;
    if (picked == null || path == null || path.isEmpty) return null;
    return HtmlPickedFile(path: path, displayName: picked.name);
  }

  Future<HtmlPreparedDocument> prepare(HtmlPickedFile picked) async {
    if (!RegExp(
      r'\.html?$',
      caseSensitive: false,
    ).hasMatch(picked.displayName)) {
      throw const HtmlImportException(
        HtmlImportFailureKind.unsupportedFileType,
      );
    }
    final file = File(picked.path);
    if (!await file.exists()) {
      throw const HtmlImportException(HtmlImportFailureKind.missingFile);
    }
    final length = await file.length();
    if (length == 0) {
      throw const HtmlImportException(HtmlImportFailureKind.empty);
    }
    if (length > maximumBytes) {
      throw HtmlImportException(HtmlImportFailureKind.tooLarge, '$length');
    }

    final Uint8List bytes = await _readBounded(file);
    var markupMarkers = 0;
    for (final byte in bytes) {
      if (byte == 0x3c && ++markupMarkers > maximumMarkupMarkers) {
        throw const HtmlImportException(HtmlImportFailureKind.tooComplex);
      }
    }
    late String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const HtmlImportException(HtmlImportFailureKind.invalidEncoding);
    }
    if (source.startsWith('\ufeff')) source = source.substring(1);

    final normalized = await _sanitize(source);
    return HtmlPreparedDocument(
      html: normalized.$1,
      suggestedTitle: _titleFromName(picked.displayName),
      sourceBytes: length,
      removedActiveContent: normalized.$2,
    );
  }

  Future<(String, bool)> _sanitize(String source) async {
    final document = html_parser.parse(source);
    final imageBudget = _ImageBudget();
    final forbidden = <String>{
      'link',
      'script',
      'iframe',
      'frame',
      'frameset',
      'object',
      'embed',
      'form',
      'input',
      'button',
      'textarea',
      'select',
      'option',
      'video',
      'audio',
      'source',
      'track',
      'canvas',
      'svg',
      'math',
      'base',
    };
    var removedActiveContent = false;
    for (final meta in document.querySelectorAll('meta[http-equiv]').toList()) {
      meta.remove();
      removedActiveContent = true;
    }
    for (final element
        in document.querySelectorAll(forbidden.join(',')).toList()) {
      element.remove();
      removedActiveContent = true;
    }

    for (final element in document.querySelectorAll('*')) {
      for (final name in element.attributes.keys.toList()) {
        final lower = name.toString().toLowerCase();
        if (lower.startsWith('on') ||
            lower == 'srcdoc' ||
            lower == 'contenteditable') {
          element.attributes.remove(name);
          removedActiveContent = true;
        }
      }

      final style = element.attributes['style'];
      if (style != null) await _validateCss(style, imageBudget);

      if (element.localName == 'a') {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty && !_isAllowedLink(href)) {
          throw HtmlImportException(
            HtmlImportFailureKind.unsupportedResource,
            href,
          );
        }
        element.attributes
          ..remove('target')
          ..remove('download')
          ..remove('ping')
          ..remove('referrerpolicy');
      } else {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) {
          throw HtmlImportException(
            HtmlImportFailureKind.unsupportedResource,
            href,
          );
        }
      }

      for (final attribute in const ['src', 'srcset', 'poster', 'background']) {
        final value = element.attributes[attribute];
        if (value == null || value.isEmpty) continue;
        if (element.localName == 'img' &&
            attribute == 'src' &&
            value.startsWith('data:image/')) {
          final dimensions = await _validateDataImage(value, imageBudget);
          _prepareLazyImage(element, dimensions);
          continue;
        }
        throw HtmlImportException(
          HtmlImportFailureKind.unsupportedResource,
          value,
        );
      }
    }
    for (final style in document.querySelectorAll('style')) {
      await _validateCss(style.text, imageBudget);
    }

    final html = document.documentElement ?? dom.Element.tag('html');
    final head = document.head ?? dom.Element.tag('head');
    if (head.parent == null) html.nodes.insert(0, head);
    head
        .querySelectorAll(
          'meta[http-equiv="Content-Security-Policy"], meta[name="viewport"]',
        )
        .forEach((e) => e.remove());
    head.nodes.insert(
      0,
      dom.Element.tag('meta')
        ..attributes['http-equiv'] = 'Content-Security-Policy'
        ..attributes['content'] =
            "default-src 'none'; img-src data:; font-src data:; "
            "style-src 'unsafe-inline'; script-src 'none'; connect-src 'none'; "
            "media-src 'none'; frame-src 'none'; object-src 'none'; "
            "base-uri 'none'; form-action 'none'",
    );
    head.nodes.insert(
      1,
      dom.Element.tag('meta')
        ..attributes['name'] = 'viewport'
        ..attributes['content'] =
            'width=1191, user-scalable=yes, maximum-scale=4',
    );
    head.append(
      dom.Element.tag('style')
        ..text = '''
html, body { margin: 0; padding: 0; width: 1191px; min-height: 100%; overflow-x: hidden; }
body { box-sizing: border-box; overflow-wrap: anywhere; }
*, *::before, *::after { box-sizing: border-box; animation: none !important; transition: none !important; }
''',
    );
    return ('<!doctype html>\n${html.outerHtml}', removedActiveContent);
  }

  static bool _isAllowedLink(String value) {
    if (value.startsWith('#')) return true;
    final uri = Uri.tryParse(value);
    return uri != null &&
        const {'http', 'https', 'mailto'}.contains(uri.scheme);
  }

  static Future<void> _validateCss(String css, _ImageBudget budget) async {
    final lower = css.toLowerCase();
    if (lower.contains('@import') ||
        RegExp(r'position\s*:\s*(fixed|sticky)').hasMatch(lower)) {
      throw const HtmlImportException(
        HtmlImportFailureKind.unsupportedResource,
        'Unsupported CSS layout or import',
      );
    }
    for (final match in RegExp(
      r'''url\(\s*['"]?([^\)'"]+)''',
    ).allMatches(css)) {
      final value = match.group(1)?.trim() ?? '';
      if (value.toLowerCase().startsWith('data:image/')) {
        await _validateDataImage(value, budget);
      } else if (!RegExp(
        r'^data:font/(woff2?|ttf|otf)(?:;[^,]*)?,',
        caseSensitive: false,
      ).hasMatch(value)) {
        throw HtmlImportException(
          HtmlImportFailureKind.unsupportedResource,
          value,
        );
      }
    }
  }

  static Future<_ImageDimensions> _validateDataImage(
    String uri,
    _ImageBudget budget,
  ) async {
    final comma = uri.indexOf(',');
    if (comma < 0) {
      throw const HtmlImportException(HtmlImportFailureKind.invalidImage);
    }
    final header = uri.substring(0, comma).toLowerCase();
    if (!RegExp(
      r'^data:image/(png|jpe?g)(?:;[^,]*)?;base64$',
    ).hasMatch(header)) {
      throw const HtmlImportException(
        HtmlImportFailureKind.unsupportedResource,
        'Unsupported image format',
      );
    }
    late Uint8List bytes;
    try {
      final payload = uri.substring(comma + 1);
      bytes = base64.decode(payload.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      throw const HtmlImportException(HtmlImportFailureKind.invalidImage);
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width > maximumImageAxis ||
          height > maximumImageAxis ||
          width * height > maximumImagePixels) {
        throw HtmlImportException(
          HtmlImportFailureKind.oversizedImage,
          '${width}x$height',
        );
      }
      budget.add(width * height);
      return _ImageDimensions(width, height);
    } on HtmlImportException {
      rethrow;
    } catch (_) {
      throw const HtmlImportException(HtmlImportFailureKind.invalidImage);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static void _prepareLazyImage(
    dom.Element element,
    _ImageDimensions dimensions,
  ) {
    element.attributes
      ..['loading'] = 'lazy'
      ..['decoding'] = 'async';

    final parsedWidth = int.tryParse(element.attributes['width'] ?? '');
    final parsedHeight = int.tryParse(element.attributes['height'] ?? '');
    final width = parsedWidth != null && parsedWidth > 0 ? parsedWidth : null;
    final height = parsedHeight != null && parsedHeight > 0
        ? parsedHeight
        : null;
    if (width == null && height == null) {
      element.attributes
        ..['width'] = '${dimensions.width}'
        ..['height'] = '${dimensions.height}';
    } else if (width != null && width > 0 && height == null) {
      element.attributes['height'] =
          '${(width * dimensions.height / dimensions.width).round().clamp(1, 1000000)}';
    } else if (height != null && height > 0 && width == null) {
      element.attributes['width'] =
          '${(height * dimensions.width / dimensions.height).round().clamp(1, 1000000)}';
    }
  }

  static String _titleFromName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final withoutExtension = base.replaceFirst(
      RegExp(r'\.html?$', caseSensitive: false),
      '',
    );
    return withoutExtension.trim().isEmpty
        ? 'HTML document'
        : withoutExtension.trim();
  }

  static Future<Uint8List> _readBounded(File file) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in file.openRead()) {
      total += chunk.length;
      if (total > maximumBytes) {
        throw HtmlImportException(HtmlImportFailureKind.tooLarge, '$total');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

class _ImageDimensions {
  const _ImageDimensions(this.width, this.height);

  final int width;
  final int height;
}

class _ImageBudget {
  int _pixels = 0;

  void add(int pixels) {
    _pixels += pixels;
    if (_pixels > HtmlImportService.maximumTotalImagePixels) {
      throw HtmlImportException(
        HtmlImportFailureKind.oversizedImage,
        'total=$_pixels',
      );
    }
  }
}
