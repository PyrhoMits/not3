// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/models/stroke.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/canvas/drawing_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  CanvasController controller() =>
      CanvasController(StorageService(baseDir: temp))..setHapticEnabled(false);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('not3_laser_pointer_');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'uses laser defaults and invalid preferences fall back safely',
    () async {
      SharedPreferences.setMockInitialValues({
        'laser_pointer_mode': 'flashlight',
        'laser_pointer_color': -1,
        'laser_pointer_thickness': 100.0,
        'laser_pointer_duration_ms': 10,
      });
      final canvas = controller();
      await canvas.inputPreferencesLoaded;

      expect(canvas.laserPointerMode, LaserPointerMode.lines);
      expect(canvas.laserColor, CanvasController.defaultLaserColor);
      expect(canvas.laserThickness, CanvasController.defaultLaserThickness);
      expect(canvas.laserDuration, CanvasController.defaultLaserDuration);
      expect(canvas.laserMode, isFalse, reason: 'activity is never persisted');
      canvas.dispose();
    },
  );

  test('laser settings persist independently of ink settings', () async {
    final first = controller();
    await first.inputPreferencesLoaded;
    final inkColor = first.color;
    first.setLaserPointerMode(LaserPointerMode.dot);
    first.setLaserColor(const Color(0xFF1565C0));
    first.setLaserThickness(12);
    first.setLaserDuration(const Duration(milliseconds: 2000));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    first.dispose();

    final second = controller();
    await second.inputPreferencesLoaded;
    expect(second.laserPointerMode, LaserPointerMode.dot);
    expect(second.laserColor, const Color(0xFF1565C0));
    expect(second.laserThickness, 12);
    expect(second.laserDuration, const Duration(milliseconds: 2000));
    expect(second.color, inkColor);
    expect(second.laserMode, isFalse);
    second.dispose();
  });

  test('laser is ephemeral and selecting another tool disables it', () async {
    final canvas = controller();
    await canvas.inputPreferencesLoaded;
    canvas.setLaserEnabled(true);

    canvas.beginStroke(Offset.zero, 0.5, tool: ToolType.pen);
    canvas.addStrokePoint(const Offset(10, 10), 0.5);
    canvas.addStrokePoint(const Offset(20, 20), 0.5);
    canvas.endStroke();
    expect(canvas.laserTrail.length, 3);
    expect(canvas.page.strokes, isEmpty);
    expect(canvas.canUndo, isFalse);

    canvas.setLaserPointerMode(LaserPointerMode.dot);
    expect(canvas.laserTrail, hasLength(1));
    canvas.beginStroke(const Offset(30, 30), 0.5, tool: ToolType.pen);
    canvas.addStrokePoint(const Offset(40, 40), 0.5);
    canvas.endStroke();
    expect(canvas.laserTrail, hasLength(1));
    expect(canvas.laserTrail.single, const Offset(40, 40));
    expect(canvas.page.strokes, isEmpty);
    expect(canvas.canUndo, isFalse);

    canvas.setLaserPointerMode(LaserPointerMode.lines);
    canvas.setTool(ToolType.lasso);
    expect(canvas.laserMode, isFalse);
    expect(canvas.laserTrail, isEmpty);
    expect(canvas.page.strokes, isEmpty);
    canvas.dispose();
  });

  test(
    'complete gesture expires at once and disabling stops its timer',
    () async {
      final canvas = controller();
      await canvas.inputPreferencesLoaded;
      canvas
        ..setLaserEnabled(true)
        ..setLaserDuration(CanvasController.minLaserDuration)
        ..beginStroke(Offset.zero, 0.5, tool: ToolType.pen)
        ..addStrokePoint(const Offset(10, 10), 0.5)
        ..addStrokePoint(const Offset(20, 20), 0.5)
        ..endStroke();
      expect(canvas.laserExpiryTimerActive, isTrue);
      expect(canvas.laserTrail, hasLength(3));

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(canvas.laserTrail, hasLength(3));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(canvas.laserTrail, isEmpty);
      expect(canvas.laserExpiryTimerActive, isFalse);

      canvas.setLaserPointerMode(LaserPointerMode.dot);
      canvas.beginStroke(const Offset(10, 10), 0.5, tool: ToolType.pen);
      canvas.endStroke();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(canvas.laserTrail, isEmpty);
      expect(canvas.laserExpiryTimerActive, isFalse);

      canvas.beginStroke(const Offset(20, 20), 0.5, tool: ToolType.pen);
      canvas.endStroke();
      expect(canvas.laserExpiryTimerActive, isTrue);
      canvas.setLaserEnabled(false);
      expect(canvas.laserTrail, isEmpty);
      expect(canvas.laserExpiryTimerActive, isFalse);
      canvas.dispose();
    },
  );

  test('starting a new line replaces the previous complete gesture', () async {
    final canvas = controller();
    await canvas.inputPreferencesLoaded;
    canvas
      ..setLaserEnabled(true)
      ..setLaserDuration(CanvasController.maxLaserDuration)
      ..beginStroke(Offset.zero, 0.5, tool: ToolType.pen)
      ..addStrokePoint(const Offset(10, 10), 0.5)
      ..endStroke();
    expect(canvas.laserTrail, hasLength(2));
    expect(canvas.laserExpiryTimerActive, isTrue);

    canvas.beginStroke(const Offset(30, 30), 0.5, tool: ToolType.pen);
    expect(canvas.laserTrail, hasLength(1));
    expect(canvas.laserTrail.single, const Offset(30, 30));
    expect(canvas.laserExpiryTimerActive, isFalse);
    canvas
      ..addStrokePoint(const Offset(40, 40), 0.5)
      ..endStroke();
    expect(canvas.laserTrail, hasLength(2));
    expect(canvas.laserExpiryTimerActive, isTrue);
    canvas.dispose();
  });

  testWidgets('selected color and thickness stay in screen space across zoom', (
    tester,
  ) async {
    final canvas = controller();
    await canvas.inputPreferencesLoaded;
    canvas
      ..setLaserEnabled(true)
      ..setLaserColor(const Color(0xFF1565C0))
      ..setLaserThickness(10)
      ..beginStroke(const Offset(20, 40), 0.5, tool: ToolType.pen)
      ..addStrokePoint(const Offset(100, 40), 0.5)
      ..endStroke();

    Future<({int coreHeight, Color center})> sample(double scale) async {
      canvas.setView(scale, Offset.zero);
      final recorder = ui.PictureRecorder();
      final drawing = Canvas(recorder);
      const size = Size(240, 120);
      ActiveLayerPainter(controller: canvas).paint(drawing, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture.dispose();
      final x = (60 * scale).round();
      final centerY = (40 * scale).round();
      final centerOffset = (centerY * size.width.toInt() + x) * 4;
      final center = Color.fromARGB(
        bytes!.getUint8(centerOffset + 3),
        bytes.getUint8(centerOffset),
        bytes.getUint8(centerOffset + 1),
        bytes.getUint8(centerOffset + 2),
      );
      var first = size.height.toInt();
      var last = -1;
      for (var y = 0; y < size.height; y++) {
        final offset = (y.toInt() * size.width.toInt() + x) * 4;
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        final blue = bytes.getUint8(offset + 2);
        final alpha = bytes.getUint8(offset + 3);
        if (alpha > 150 && blue > red && blue > green) {
          first = first < y ? first : y.toInt();
          last = last > y ? last : y.toInt();
        }
      }
      return (coreHeight: last < first ? 0 : last - first + 1, center: center);
    }

    final atOne = (await tester.runAsync(() => sample(1)))!;
    final atTwo = (await tester.runAsync(() => sample(2)))!;
    expect(atOne.coreHeight, inInclusiveRange(9, 11));
    expect(atTwo.coreHeight, inInclusiveRange(9, 11));
    expect(atOne.center.b, greaterThan(atOne.center.r));
    expect(atOne.center.b, greaterThan(atOne.center.g));

    canvas.setLaserColor(CanvasController.defaultLaserColor);
    final redLaser = (await tester.runAsync(() => sample(1)))!;
    expect(
      (redLaser.center.r - redLaser.center.g).abs(),
      lessThanOrEqualTo(0.05),
    );
    expect(
      (redLaser.center.r - redLaser.center.b).abs(),
      lessThanOrEqualTo(0.05),
    );
    canvas.dispose();
  });
}
