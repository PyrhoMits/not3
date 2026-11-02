// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/app_localizations.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/services/image_service.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/canvas/drawing_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late CanvasController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('not3_zoom_board_');
    controller = CanvasController(StorageService(baseDir: tmp))
      ..setHapticEnabled(false)
      ..setShapeDetection(false);
  });

  tearDown(() {
    controller.dispose();
    tmp.deleteSync(recursive: true);
  });

  Future<void> pumpCanvas(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DrawingCanvas(
              controller: controller,
              imageService: ImageService(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('opens a fixed zoom-writing board', (tester) async {
    await pumpCanvas(tester);

    controller.toggleMagnifier();
    await tester.pump();

    expect(find.byKey(const ValueKey('zoom-writing-board')), findsOneWidget);
    expect(find.text('Zoom writing'), findsOneWidget);
  });

  testWidgets('stylus input in the board creates a document stroke', (
    tester,
  ) async {
    await pumpCanvas(tester);
    controller.toggleMagnifier();
    await tester.pump();

    final surface = find.byKey(const ValueKey('zoom-writing-surface'));
    final center = tester.getCenter(surface);
    final gesture = await tester.startGesture(
      center - const Offset(30, 0),
      kind: PointerDeviceKind.stylus,
    );
    await gesture.moveBy(const Offset(60, 0));
    await gesture.up();
    await tester.pump();

    expect(controller.page.strokes, hasLength(1));
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('dragging the page moves the board target without drawing', (
    tester,
  ) async {
    await pumpCanvas(tester);
    controller.toggleMagnifier();
    await tester.pump();

    final before = controller.magnifierPosition;
    final gesture = await tester.startGesture(
      const Offset(120, 120),
      kind: PointerDeviceKind.stylus,
    );
    await gesture.moveBy(const Offset(80, 20));
    await gesture.up();
    await tester.pump();

    expect(controller.magnifierPosition, isNot(before));
    expect(controller.page.strokes, isEmpty);
  });
}
