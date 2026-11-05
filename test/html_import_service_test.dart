// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not3/services/html_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  const service = HtmlImportService();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('not3_html_import_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<HtmlPreparedDocument> prepare(
    String source, {
    String name = 'article.html',
  }) async {
    final file = File('${temp.path}/source')..writeAsStringSync(source);
    return service.prepare(HtmlPickedFile(path: file.path, displayName: name));
  }

  Matcher failure(HtmlImportFailureKind kind) =>
      isA<HtmlImportException>().having((error) => error.kind, 'kind', kind);

  test('sanitizes active content and injects an offline policy', () async {
    final result = await prepare('''
<!doctype html><html><head><title>Safe</title>
<link rel="preconnect" href="https://fonts.example.com">
<link rel="stylesheet" href="https://fonts.example.com/font.css">
</head><body>
<script>alert(1)</script><p onclick="alert(2)">Text</p>
<a href="https://example.com" target="_blank">Link</a>
</body></html>
''', name: 'Article.HtMl');

    expect(result.suggestedTitle, 'Article');
    expect(result.removedActiveContent, isTrue);
    expect(result.html, isNot(contains('<script')));
    expect(result.html, isNot(contains('<link')));
    expect(result.html, isNot(contains('fonts.example.com')));
    expect(result.html, isNot(contains('onclick')));
    expect(result.html, contains('Content-Security-Policy'));
    expect(result.html, contains('width=1191'));
    expect(result.html, contains('https://example.com'));
    expect(result.html, isNot(contains('target="_blank"')));
  });

  test('reserves embedded image geometry and enables lazy decoding', () async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    final result = await prepare(
      '<html><body><img loading="lazy" src="data:image/png;base64,$png"></body></html>',
    );

    expect(result.html, contains('loading="lazy"'));
    expect(result.html, contains('decoding="async"'));
    expect(result.html, contains('width="1"'));
    expect(result.html, contains('height="1"'));
  });

  test('rejects relative and remote embedded resources', () async {
    await expectLater(
      prepare('<img src="images/picture.png">'),
      throwsA(failure(HtmlImportFailureKind.unsupportedResource)),
    );
    await expectLater(
      prepare('<style>body{background:url(https://example.com/a.png)}</style>'),
      throwsA(failure(HtmlImportFailureKind.unsupportedResource)),
    );
  });

  test('validates embedded images referenced from CSS', () async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    final result = await prepare(
      '<style>body{background:url(data:image/png;base64,$png)}</style>',
    );
    expect(result.html, contains('data:image/png;base64'));
  });

  test(
    'rejects unsupported file names, empty files, and invalid UTF-8',
    () async {
      await expectLater(
        prepare('<p>Text</p>', name: 'article.txt'),
        throwsA(failure(HtmlImportFailureKind.unsupportedFileType)),
      );
      await expectLater(
        prepare(''),
        throwsA(failure(HtmlImportFailureKind.empty)),
      );
      final invalid = File('${temp.path}/invalid')
        ..writeAsBytesSync([0xff, 0xfe]);
      await expectLater(
        service.prepare(
          HtmlPickedFile(path: invalid.path, displayName: 'invalid.htm'),
        ),
        throwsA(failure(HtmlImportFailureKind.invalidEncoding)),
      );
    },
  );

  test('rejects a file above 5 MiB from metadata before parsing', () async {
    final file = File('${temp.path}/large.html');
    final handle = file.openSync(mode: FileMode.write);
    handle.truncateSync(HtmlImportService.maximumBytes + 1);
    handle.closeSync();

    await expectLater(
      service.prepare(
        HtmlPickedFile(path: file.path, displayName: 'large.html'),
      ),
      throwsA(failure(HtmlImportFailureKind.tooLarge)),
    );
  });

  test('rejects pathological markup before building a DOM', () async {
    final source = List.filled(
      HtmlImportService.maximumMarkupMarkers + 1,
      '<',
    ).join();
    await expectLater(
      prepare(source),
      throwsA(failure(HtmlImportFailureKind.tooComplex)),
    );
  });

  test('uses strict warning and hard-limit boundaries', () {
    expect(
      const HtmlPreparedDocument(
        html: '',
        suggestedTitle: '',
        sourceBytes: HtmlImportService.warningBytes,
        removedActiveContent: false,
      ).requiresLargeFileConfirmation,
      isFalse,
    );
    expect(
      const HtmlPreparedDocument(
        html: '',
        suggestedTitle: '',
        sourceBytes: HtmlImportService.warningBytes + 1,
        removedActiveContent: false,
      ).requiresLargeFileConfirmation,
      isTrue,
    );
  });
}
