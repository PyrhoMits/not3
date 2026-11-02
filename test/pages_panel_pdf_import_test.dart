// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/services/image_service.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/editor/pages_panel.dart';
import 'package:not3/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows New page and Import PDF and invokes the callback once', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('not3_pages_panel_');
    final canvas = CanvasController(StorageService(baseDir: temp))
      ..setHapticEnabled(false);
    var imports = 0;
    addTearDown(() {
      canvas.dispose();
      temp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: PagesPanel(
              canvas: canvas,
              imageService: ImageService(),
              onClose: () {},
              onImportPdf: () => imports++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'New page'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Import PDF'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Import PDF'));
    expect(imports, 1);
    expect(tester.takeException(), isNull);
  });
}
