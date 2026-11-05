// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/services/app_paths.dart';
import 'package:not3/services/pdf_import_coordinator.dart';
import 'package:not3/services/pdf_import_service.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/home_screen.dart';
import 'package:not3/ui/note_list_screen.dart';
import 'package:not3/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('not3_notebook_notes_');
    AppPaths.rootOverride = temp;
    storage = StorageService(baseDir: temp);
  });

  tearDown(() {
    AppPaths.rootOverride = null;
    temp.deleteSync(recursive: true);
  });

  Future<void> pumpAsyncWork(WidgetTester tester) async {
    for (var attempt = 0; attempt < 25; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpNotebook(
    WidgetTester tester,
    String notebookId, {
    PdfImportCoordinator importer = const PdfImportCoordinator(
      supported: false,
    ),
  }) async {
    final notebook = (await tester.runAsync(
      () => storage.loadNotebook(notebookId),
    ))!;
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NoteListScreen(
          notebook: notebook,
          storage: storage,
          pdfImporter: importer,
        ),
      ),
    );
    await pumpAsyncWork(tester);
  }

  testWidgets('bulk selection moves notes to another notebook', (tester) async {
    final source = (await tester.runAsync(
      () => storage.createNotebook(title: 'Source'),
    ))!;
    await tester.runAsync(
      () => storage.renameNote(source.id, source.notes.single.id, 'Alpha'),
    );
    await tester.runAsync(() => storage.createNote(source.id, title: 'Beta'));
    final destination = (await tester.runAsync(
      () => storage.createNotebook(title: 'Destination'),
    ))!;
    await pumpNotebook(tester, source.id);

    await tester.longPress(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(find.text('2 notes selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Move to notebook'));
    await pumpAsyncWork(tester);
    await tester.tap(find.text('Destination'));
    await pumpAsyncWork(tester);

    final reloadedSource = (await tester.runAsync(
      () => storage.loadNotebook(source.id),
    ))!;
    final reloadedDestination = (await tester.runAsync(
      () => storage.loadNotebook(destination.id),
    ))!;
    expect(reloadedSource.notes, isEmpty);
    expect(
      reloadedDestination.notes.map((n) => n.title),
      containsAllInOrder(['Alpha', 'Beta']),
    );
  });

  testWidgets('notebook PDF import creates and opens a named note', (
    tester,
  ) async {
    final notebook = (await tester.runAsync(
      () => storage.createNotebook(title: 'Classes', createInitialNote: false),
    ))!;
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final page = File('${temp.path}/lecture.png')..writeAsBytesSync(png);
    final importer = PdfImportCoordinator(
      supported: true,
      picker: () async => const PdfPickedFile(
        path: '/source/Lecture.pdf',
        displayName: 'Lecture.pdf',
      ),
      renderer: (_) => Stream.value(PdfPageImage(page.path, 100, 200)),
    );
    await pumpNotebook(tester, notebook.id, importer: importer);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Import PDF').first);
    await pumpAsyncWork(tester);

    var loaded = (await tester.runAsync(
      () => storage.loadNotebook(notebook.id),
    ))!;
    for (var attempt = 0; loaded.notes.isEmpty && attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 25));
      final refreshed = await tester.runAsync(
        () => storage.loadNotebook(notebook.id),
      );
      if (refreshed != null) loaded = refreshed;
    }
    await pumpAsyncWork(tester);
    expect(loaded.notes.single.title, 'Lecture');
    expect(loaded.notes.single.pages.single.template.imagePath, page.path);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
  });
}
