// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/services/incoming_file_service.dart';
import 'package:not3/services/pdf_import_coordinator.dart';
import 'package:not3/services/pdf_import_service.dart';
import 'package:not3/services/app_paths.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/home_screen.dart';
import 'package:not3/ui/notebook_library.dart';
import 'package:not3/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeIncomingFileReceiver implements IncomingFileReceiver {
  _FakeIncomingFileReceiver(this.file);

  final IncomingFile file;
  bool stopped = false;

  @override
  Future<void> start(Future<void> Function(IncomingFile file) onFile) async {
    await Future<void>.delayed(Duration.zero);
    await onFile(file);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('not3_pdf_library_');
    AppPaths.rootOverride = temp;
    storage = StorageService(baseDir: temp);
  });

  tearDown(() {
    AppPaths.rootOverride = null;
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
    PdfImportCoordinator importer, {
    IncomingFileReceiver? incomingFileReceiver,
  }) async {
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
          incomingFileReceiver: incomingFileReceiver,
        ),
      ),
    );
    await pumpAsyncWork(tester);
  }

  Stream<PdfPageImage> renderedPages() async* {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final imports = Directory('${temp.path}/pdf_imports')..createSync();
    final first = File('${imports.path}/page-1.png')..writeAsBytesSync(png);
    final second = File('${imports.path}/page-2.png')..writeAsBytesSync(png);
    yield PdfPageImage(first.path, 100, 200);
    yield PdfPageImage(second.path, 200, 100);
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
    renderer: renderer ?? (_) => renderedPages(),
  );

  Finder importButtons() => find.widgetWithText(OutlinedButton, 'Import PDF');

  testWidgets('Import PDF is visible in empty and non-empty libraries', (
    tester,
  ) async {
    await pumpLibrary(tester, importer());
    expect(importButtons(), findsNWidgets(2));
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Smart views'), findsOneWidget);

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

    var index = await tester.runAsync(storage.loadIndex) ?? const [];
    for (var attempt = 0; index.isEmpty && attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 25));
      index = await tester.runAsync(storage.loadIndex) ?? const [];
    }
    expect(index, hasLength(1));
    expect(index.single.title, 'Lecture notes');
    final notebook = await tester.runAsync(
      () => storage.loadNotebook(index.single.id),
    );
    expect(notebook!.notes.single.pages, hasLength(2));
    expect(notebook.notes.single.title, 'Lecture notes');
    expect(notebook.notes.single.pages.map((page) => page.template.imagePath), [
      '${temp.path}/pdf_imports/page-1.png',
      '${temp.path}/pdf_imports/page-2.png',
    ]);
    await pumpAsyncWork(tester);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('external PDF imports directly and removes its cache copy', (
    tester,
  ) async {
    final source = File('${temp.path}/not3_123.pdf')
      ..writeAsBytesSync(const [37, 80, 68, 70]);
    String? renderedPath;
    final receiver = _FakeIncomingFileReceiver(
      IncomingFile(
        path: source.path,
        displayName: 'Shared lecture.pdf',
        kind: IncomingFileKind.pdf,
        temporary: true,
      ),
    );
    final directImporter = importer(
      picker: () async => throw StateError('picker must not open'),
      renderer: (path) {
        renderedPath = path;
        return renderedPages();
      },
    );

    await pumpLibrary(tester, directImporter, incomingFileReceiver: receiver);
    await pumpAsyncWork(tester);

    final index = await tester.runAsync(storage.loadIndex) ?? const [];
    expect(index, hasLength(1));
    expect(index.single.title, 'Shared lecture');
    expect(renderedPath, source.path);
    expect(source.existsSync(), isFalse);
    for (
      var attempt = 0;
      find.byType(HomeScreen, skipOffstage: false).evaluate().isEmpty &&
          attempt < 100;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
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
