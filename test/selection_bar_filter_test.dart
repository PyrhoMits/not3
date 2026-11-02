// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/logic/lasso_selection_filter.dart';
import 'package:not3/logic/pen_presets.dart';
import 'package:not3/models/image_item.dart';
import 'package:not3/models/text_item.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/editor/selection_bar.dart';
import 'package:not3/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('image-only and text-only selections hide stroke actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('not3_selection_bar_');
    final canvas = CanvasController(StorageService(baseDir: temp))
      ..setHapticEnabled(false);
    final presets = PenPresetsController(persist: false);
    addTearDown(() {
      canvas.dispose();
      presets.dispose();
      temp.deleteSync(recursive: true);
    });
    await canvas.inputPreferencesLoaded;
    canvas.page.images.add(
      ImageItem(
        id: 'image',
        localPath: '/tmp/selection.png',
        x: 40,
        y: 40,
        width: 30,
        height: 30,
      ),
    );
    canvas.page.textItems.add(
      TextItem(id: 'text', x: 40, y: 80, width: 60, text: 'Not3'),
    );

    void lassoAll() {
      canvas.beginLasso(const Offset(-20, -20));
      for (final point in const [
        Offset(120, -20),
        Offset(120, 120),
        Offset(-20, 120),
      ]) {
        canvas.addLassoPoint(point);
      }
      canvas.endLasso();
    }

    void keepOnly(LassoContentType target) {
      for (final type in LassoContentType.values) {
        canvas.setLassoContentEnabled(type, type == target);
      }
    }

    Future<void> pumpBar() => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            child: SelectionBar(
              canvas: canvas,
              presets: presets,
              onMessage: (_) {},
            ),
          ),
        ),
      ),
    );

    void expectOnlyCommonActions() {
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byIcon(Icons.line_weight), findsNothing);
      expect(find.byIcon(Icons.title), findsNothing);
    }

    keepOnly(LassoContentType.images);
    lassoAll();
    await pumpBar();
    await tester.pumpAndSettle();
    expect(canvas.selectedImages, hasLength(1));
    expectOnlyCommonActions();

    canvas.clearLassoSelection();
    keepOnly(LassoContentType.text);
    lassoAll();
    await tester.pump();
    expect(canvas.selectedTexts, hasLength(1));
    expectOnlyCommonActions();
  });
}
