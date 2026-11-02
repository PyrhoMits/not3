// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/services/pdf_import_coordinator.dart';
import 'package:not3/services/pdf_import_service.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/note_list_screen.dart';
import 'package:not3/ui/notebook_library.dart';
import 'package:not3/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('not3_pdf_library_');
    storage = StorageService(baseDir: temp);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  Future<void> pumpAsyncWork(WidgetTester tester) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpLibrary(
    WidgetTester tester,
    PdfImportCoordinator importer,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotebookLibraryScreen(
          key: UniqueKey(),
          storage: storage,
          pdfImporter: importer,
        ),
      ),
    );
    await pumpAsyncWork(tester);
  }

  PdfImportCoordinator importer({
    Future<PdfPickedFile?> Function()? picker,
    Stream<PdfPageImage> Function(String)? renderer,
  }) => PdfImportCoordinator(
    supported: true,
    picker:
        picker ??
        () async => const PdfPickedFile(
          path: '/source/Lecture notes.PDF',
          displayName: 'Lecture notes.PDF',
        ),
    renderer:
        renderer ??
        (_) => Stream.fromIterable(const [
          PdfPageImage('/imports/page-1.png', 100, 200),
          PdfPageImage('/imports/page-2.png', 200, 100),
        ]),
  );

  Finder importButtons() => find.widgetWithText(OutlinedButton, 'Import PDF');

  testWidgets('Import PDF is visible in empty and non-empty libraries', (
    tester,
  ) async {
    await pumpLibrary(tester, importer());
    expect(importButtons(), findsNWidgets(2));

    await tester.runAsync(() => storage.createNotebook(title: 'Existing'));
    await pumpLibrary(tester, importer());
    expect(importButtons(), findsOneWidget);
  });

  testWidgets('cancellation creates no notebook', (tester) async {
    await pumpLibrary(tester, importer(picker: () async => null));

    await tester.tap(importButtons().first);
    await pumpAsyncWork(tester);

    expect(await tester.runAsync(storage.loadIndex), isEmpty);
    expect(find.byType(NotebookLibraryScreen), findsOneWidget);
  });

  testWidgets('successful import creates and opens the named notebook', (
    tester,
  ) async {
    await pumpLibrary(tester, importer());

    await tester.tap(importButtons().first);
    await pumpAsyncWork(tester);

    final index = (await tester.runAsync(storage.loadIndex))!;
    expect(index, hasLength(1));
    expect(index.single.title, 'Lecture notes');
    final notebook = await tester.runAsync(
      () => storage.loadNotebook(index.single.id),
    );
    expect(notebook!.notes.single.pages, hasLength(2));
    expect(notebook.notes.single.pages.map((page) => page.template.imagePath), [
      '/imports/page-1.png',
      '/imports/page-2.png',
    ]);
    await pumpAsyncWork(tester);
    expect(find.byType(NoteListScreen), findsOneWidget);
  });

  testWidgets('render failure creates nothing and displays an error', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      importer(renderer: (_) => Stream.error(StateError('damaged document'))),
    );

    await tester.tap(importButtons().first);
    await pumpAsyncWork(tester);

    expect(await tester.runAsync(storage.loadIndex), isEmpty);
    expect(find.textContaining('PDF import error'), findsOneWidget);
  });
}
