// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/services/app_paths.dart';
import 'package:not3/services/html_import_service.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/note_list_screen.dart';
import 'package:not3/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHtmlImporter extends HtmlImportService {
  const _FakeHtmlImporter();

  @override
  bool get isSupported => true;

  @override
  Future<HtmlPickedFile?> pick() async =>
      const HtmlPickedFile(path: '/unused', displayName: 'Article.html');

  @override
  Future<HtmlPreparedDocument> prepare(HtmlPickedFile picked) async =>
      const HtmlPreparedDocument(
        html: '<!doctype html><html><body><p>Imported</p></body></html>',
        suggestedTitle: 'Article',
        sourceBytes: HtmlImportService.warningBytes + 1,
        removedActiveContent: false,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('not3_html_ui_');
    AppPaths.rootOverride = temp;
    storage = StorageService(baseDir: temp);
  });

  tearDown(() {
    AppPaths.rootOverride = null;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('Import HTML is visible and confirms a large file', (
    tester,
  ) async {
    final notebook = (await tester.runAsync(
      () => storage.createNotebook(title: 'Articles', createInitialNote: false),
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
          htmlImporter: const _FakeHtmlImporter(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.widgetWithText(OutlinedButton, 'Import HTML'),
      findsNWidgets(2),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Import HTML').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Import large HTML file?'), findsOneWidget);
    expect(find.textContaining('3.0 MiB may open more slowly'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final loaded = await tester.runAsync(
      () => storage.loadNotebook(notebook.id),
    );
    expect(loaded!.notes, isEmpty);
  });
}
