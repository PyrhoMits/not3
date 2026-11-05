// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not3/models/page.dart';
import 'package:not3/services/storage_service.dart';

void main() {
  late Directory temp;
  late StorageService storage;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('not3_html_storage_');
    storage = StorageService(baseDir: temp);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'creates, reopens, moves, and duplicates an app-owned HTML note',
    () async {
      final first = await storage.createNotebook(
        title: 'First',
        createInitialNote: false,
      );
      final second = await storage.createNotebook(
        title: 'Second',
        createInitialNote: false,
      );
      final note = await storage.createHtmlNote(
        first.id,
        title: 'Article',
        sanitizedHtml: '<!doctype html><p>Offline</p>',
      );

      final loaded = await storage.loadNote(note.id);
      expect(loaded, isNotNull);
      expect(loaded!.pages, hasLength(1));
      expect(loaded.pages.single.isHtml, isTrue);
      final source = await storage.htmlSourceFile(loaded.pages.single);
      expect(source.readAsStringSync(), contains('Offline'));

      await storage.moveNotes(first.id, second.id, {note.id});
      expect((await storage.loadNotebook(first.id))!.notes, isEmpty);
      expect((await storage.loadNotebook(second.id))!.notes.single.id, note.id);
      expect(source.existsSync(), isTrue);

      final copy = await storage.duplicateNote(second.id, note.id);
      final copySource = await storage.htmlSourceFile(copy.pages.single);
      expect(copy.pages.single.htmlContent!.sourcePath, isNot(source.path));
      expect(copySource.path, isNot(source.path));
      expect(copySource.readAsStringSync(), source.readAsStringSync());
    },
  );

  test('trash keeps HTML restorable and purge removes its source', () async {
    final notebook = await storage.createNotebook(
      title: 'Articles',
      createInitialNote: false,
    );
    final note = await storage.createHtmlNote(
      notebook.id,
      title: 'Article',
      sanitizedHtml: '<p>Keep me</p>',
    );
    final source = await storage.htmlSourceFile(note.pages.single);

    await storage.deleteNote(notebook.id, note.id);
    expect(source.existsSync(), isTrue);
    await storage.restoreFromTrash(note.id);
    expect((await storage.loadNote(note.id))!.pages.single.isHtml, isTrue);
    expect(source.existsSync(), isTrue);

    await storage.deleteNote(notebook.id, note.id);
    await storage.purgeFromTrash(note.id);
    expect(source.existsSync(), isFalse);
  });

  test('full backup restores the owned HTML source', () async {
    final notebook = await storage.createNotebook(
      title: 'Articles',
      createInitialNote: false,
    );
    final note = await storage.createHtmlNote(
      notebook.id,
      title: 'Article',
      sanitizedHtml: '<p>Backed up</p>',
    );
    final backup = await storage.exportFullBackup();
    final restoredRoot = Directory.systemTemp.createTempSync(
      'not3_html_restore_',
    );
    try {
      final restoredStorage = StorageService(baseDir: restoredRoot);
      await restoredStorage.importFullBackup(backup);
      final restored = await restoredStorage.loadNote(note.id);
      final source = await restoredStorage.htmlSourceFile(
        restored!.pages.single,
      );
      expect(source.readAsStringSync(), contains('Backed up'));
    } finally {
      restoredRoot.deleteSync(recursive: true);
    }
  });

  test('failed duplication does not leave an HTML directory behind', () async {
    final notebook = await storage.createNotebook(
      title: 'Articles',
      createInitialNote: false,
    );
    final note = await storage.createHtmlNote(
      notebook.id,
      title: 'Article',
      sanitizedHtml: '<p>Source</p>',
    );

    await expectLater(
      storage.duplicateNote('missing-notebook', note.id),
      throwsStateError,
    );
    final htmlRoot = Directory('${temp.path}/html');
    final directories = htmlRoot
        .listSync()
        .whereType<Directory>()
        .map((entry) => entry.path.split('/').last)
        .toList();
    expect(directories, [note.id]);
  });

  test('rejects HTML source paths outside app-owned storage', () async {
    await expectLater(
      storage.htmlSourceFile(Page.html(sourcePath: '../outside.html')),
      throwsStateError,
    );
    await expectLater(
      storage.htmlSourceFile(Page.html(sourcePath: '/tmp/outside.html')),
      throwsStateError,
    );
    await expectLater(
      storage.htmlSourceFile(
        Page.html(sourcePath: '${temp.path}/../outside.html'),
      ),
      throwsStateError,
    );

    final outside = File(
      '${temp.parent.path}/not3-html-outside-${temp.path.split('/').last}.txt',
    )..writeAsStringSync('outside');
    final link = Link('${temp.path}/html-link')..createSync(outside.path);
    try {
      await expectLater(
        storage.htmlSourceFile(Page.html(sourcePath: 'html-link')),
        throwsStateError,
      );
    } finally {
      if (link.existsSync()) link.deleteSync();
      if (outside.existsSync()) outside.deleteSync();
    }
  });
}
