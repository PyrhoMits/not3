// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:not3/services/html_import_service.dart';
import 'package:not3/services/html_math_baker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  const importer = HtmlImportService();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('not3_html_math_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<HtmlPreparedDocument> prepare(String source) async {
    final file = File('${temp.path}/math.html')..writeAsStringSync(source);
    return importer.prepare(
      HtmlPickedFile(path: file.path, displayName: 'math.html'),
    );
  }

  test('bundles the pinned offline MathJax distribution', () async {
    final source = await rootBundle.loadString(HtmlMathBaker.assetPath);
    expect(source.length, greaterThan(2000000));
    expect(source, contains('MathJax'));
  });

  test(
    'preserves safe macros without retaining or running source scripts',
    () async {
      final prepared = await prepare(r'''
<!doctype html><html><head><script>
window.MathJax = {tex: {macros: {
  sig: ['\\class{sig}{#1}', 1],
  ab: '\\bar\\alpha',
  net: ['\\mathrm{Net}_{#1}', 1],
  unsafe: ['\\href{https://example.com}{#1}', 1],
  breakOut: ['</script><script>alert(1)</script>', 1]
}}};
</script></head><body><p>\(\sig{x} + \ab\)</p></body></html>
''');

      expect(prepared.html, isNot(contains('<script')));
      expect(prepared.html, contains('not3-math-source'));
      expect(HtmlMathBaker.needsBake(prepared.html), isTrue);

      final runtime = HtmlMathBaker.runtimeHtml(prepared.html, '/* MathJax */');
      final document = html_parser.parse(runtime);
      final configScript = document.querySelector(
        'script[data-not3-math-runtime="config"]',
      );
      expect(configScript, isNotNull);
      final source = configScript!.text;
      final config =
          jsonDecode(
                source.substring('window.MathJax = '.length, source.length - 1),
              )
              as Map<String, dynamic>;
      final tex = config['tex'] as Map<String, dynamic>;
      final macros = tex['macros'] as Map<String, dynamic>;
      expect(macros['sig'], ['#1', 1]);
      expect(macros['ab'], r'\bar\alpha');
      expect(macros['net'], [r'\mathrm{Net}_{#1}', 1]);
      expect(macros, isNot(contains('unsafe')));
      expect(macros, isNot(contains('breakOut')));
      expect(
        document
            .querySelector('meta[http-equiv="Content-Security-Policy"]')!
            .attributes['content'],
        contains("script-src 'nonce-not3-math-runtime-v1'"),
      );
      expect(
        document
            .querySelectorAll('script')
            .every(
              (script) => script.attributes['nonce'] == 'not3-math-runtime-v1',
            ),
        isTrue,
      );
      expect(tex['packages'], {
        '[-]': ['html', 'require', 'autoload'],
      });
    },
  );

  test('strips restored active content before enabling MathJax', () {
    final runtime = HtmlMathBaker.runtimeHtml('''
<html><head><meta http-equiv="refresh" content="0; url=https://evil.example">
<script nonce="not3-math-runtime-v1">alert(1)</script></head>
<body onload="alert(2)"><p>\\(x\\)</p></body></html>
''', '/* MathJax */');
    final document = html_parser.parse(runtime);

    expect(document.querySelectorAll('script'), hasLength(3));
    expect(runtime, isNot(contains('alert(1)')));
    expect(document.body!.attributes, isNot(contains('onload')));
    expect(document.querySelectorAll('meta[http-equiv]'), hasLength(1));
  });

  test('keeps inert SVG but removes runtime and active SVG content', () {
    final sanitized = HtmlMathBaker.sanitizeBaked('''
<!doctype html><html><head>
<meta http-equiv="Content-Security-Policy" content="script-src 'unsafe-inline'">
<script data-not3-math-runtime="library">alert(1)</script>
</head><body onload="alert(2)">
<mjx-container style="position: fixed; color: red">
  <svg><defs><path id="glyph" d="M0 0"></path></defs>
    <use href="#glyph" onclick="alert(3)"></use>
    <animate attributeName="x"></animate>
  </svg>
</mjx-container>
</body></html>
''');

    final document = html_parser.parse(sanitized);
    expect(document.querySelector('script'), isNull);
    expect(document.querySelector('animate'), isNull);
    expect(document.querySelector('svg use'), isNotNull);
    expect(document.body!.attributes, isNot(contains('onload')));
    expect(
      document.querySelector('svg use')!.attributes,
      isNot(contains('onclick')),
    );
    expect(
      document.querySelector('mjx-container')!.attributes,
      isNot(contains('style')),
    );
    expect(
      document
          .querySelector('meta[http-equiv="Content-Security-Policy"]')!
          .attributes['content'],
      contains("script-src 'none'"),
    );
    expect(document.querySelector('meta[name="not3-math-baked"]'), isNotNull);
    expect(HtmlMathBaker.needsBake(sanitized), isFalse);
  });

  test('rejects external SVG references and generated resources', () {
    expect(
      () => HtmlMathBaker.sanitizeBaked(
        '<mjx-container><svg><use href="https://evil.example/x.svg#g" />'
        '</svg></mjx-container>',
      ),
      throwsFormatException,
    );
    expect(
      () => HtmlMathBaker.sanitizeBaked(
        '<mjx-container><img src="https://evil.example/x.png"></mjx-container>',
      ),
      throwsFormatException,
    );
  });
}
