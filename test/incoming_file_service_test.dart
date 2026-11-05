// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/services/incoming_file_service.dart';

void main() {
  test('decodes structured PDF handoff', () {
    final file = IncomingFile.fromChannel({
      'path': '/cache/not3_123.pdf',
      'displayName': 'Thai notes.pdf',
      'kind': 'pdf',
      'temporary': true,
    });

    expect(file, isNotNull);
    expect(file!.path, '/cache/not3_123.pdf');
    expect(file.displayName, 'Thai notes.pdf');
    expect(file.kind, IncomingFileKind.pdf);
    expect(file.temporary, isTrue);
  });

  test('routes HTML, archive, and unsupported payloads', () {
    expect(
      IncomingFile.fromChannel({
        'path': '/cache/a.html',
        'displayName': 'Article.html',
        'kind': 'html',
      })!.kind,
      IncomingFileKind.html,
    );
    expect(
      IncomingFile.fromChannel({
        'path': '/cache/a.bin',
        'displayName': 'Backup.inklus',
        'kind': 'archive',
      })!.kind,
      IncomingFileKind.archive,
    );
    expect(
      IncomingFile.fromChannel({
        'path': '/cache/a.bin',
        'displayName': 'photo.jpg',
        'kind': 'unsupported',
      })!.kind,
      IncomingFileKind.unsupported,
    );
  });

  test(
    'supports legacy path payloads without treating unknown files as PDF',
    () {
      expect(
        IncomingFile.fromChannel('/cache/shared.pdf')!.kind,
        IncomingFileKind.pdf,
      );
      expect(
        IncomingFile.fromChannel('/cache/incoming.inklus')!.kind,
        IncomingFileKind.archive,
      );
      expect(
        IncomingFile.fromChannel('/cache/article.htm')!.kind,
        IncomingFileKind.html,
      );
      expect(
        IncomingFile.fromChannel('/cache/shared.bin')!.kind,
        IncomingFileKind.unsupported,
      );
    },
  );
}
