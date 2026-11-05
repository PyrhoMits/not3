// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/logic/shape_detector.dart';
import 'package:not3/models/stroke.dart';
import 'package:not3/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late CanvasController canvas;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('not3_shape_edit_');
    canvas = CanvasController(StorageService(baseDir: temp))
      ..setHapticEnabled(false)
      ..setShapeDetection(false);
  });

  tearDown(() {
    canvas.dispose();
    temp.deleteSync(recursive: true);
  });

  Stroke addShape(ShapeType type, List<Offset> anchors) {
    final stroke = Stroke(
      id: 'shape-${type.name}',
      points: ShapeDetector.pointsFromAnchors(type, anchors),
      tool: ToolType.pen,
      colorValue: 0xFF111111,
      size: 3,
      shapeType: type.name,
      shapeAnchors: anchors,
    );
    canvas.page.strokes.add(stroke);
    canvas.activateShapeEditing(stroke);
    return stroke;
  }

  test('shape anchors survive JSON and translation', () {
    const anchors = [
      Offset(10, 10),
      Offset(110, 10),
      Offset(110, 80),
      Offset(10, 80),
    ];
    final stroke = Stroke(
      id: 'shape',
      points: ShapeDetector.pointsFromAnchors(ShapeType.rectangle, anchors),
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 4,
      shapeType: ShapeType.rectangle.name,
      shapeAnchors: anchors,
    );

    final restored = Stroke.fromJson(stroke.toJson());
    expect(restored.shapeAnchors, anchors);
    expect(restored.translated(const Offset(5, 7)).shapeAnchors, [
      for (final anchor in anchors) anchor + const Offset(5, 7),
    ]);
  });

  test('legacy recognized shapes derive editable anchors lazily', () {
    const anchors = [
      Offset(0, 0),
      Offset(100, 0),
      Offset(100, 60),
      Offset(0, 60),
    ];
    final legacy = Stroke(
      id: 'legacy',
      points: ShapeDetector.pointsFromAnchors(ShapeType.rectangle, anchors),
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 3,
      shapeType: ShapeType.rectangle.name,
    );
    canvas.page.strokes.add(legacy);
    canvas.activateShapeEditing(legacy);

    expect(canvas.activeShapeAnchors, anchors);
    expect(legacy.shapeAnchors, isNull);
  });

  test('dragging one polygon vertex regenerates geometry and angles', () {
    const anchors = [
      Offset(0, 0),
      Offset(120, 0),
      Offset(120, 80),
      Offset(0, 80),
    ];
    final before = addShape(ShapeType.rectangle, anchors);

    expect(canvas.beginShapeEditGesture(anchors.first), isTrue);
    expect(canvas.shapeEditOperation, ShapeEditOperation.anchor);
    canvas.updateShapeEditGesture(const Offset(-20, 20));

    final edited = canvas.activeShapeEditStroke!;
    expect(edited.shapeAnchors!.first, const Offset(-20, 20));
    expect(edited.points, isNot(equals(before.points)));
    final angles = ShapeDetector.polygonAngles(edited.shapeAnchors!);
    expect(angles, hasLength(4));
    expect(
      angles.map((angle) => (angle * 180 / pi).round()).toSet().length,
      greaterThan(1),
    );
  });

  test('nearby polygon vertices preserve rectangle topology', () {
    const anchors = [
      Offset(0, 0),
      Offset(120, 0),
      Offset(120, 80),
      Offset(0, 80),
    ];
    addShape(ShapeType.rectangle, anchors);

    expect(canvas.beginShapeEditGesture(anchors.first), isTrue);
    canvas.updateShapeEditGesture(const Offset(116, 3));
    canvas.endShapeEditGesture();

    final edited = canvas.activeShapeEditStroke!;
    expect(edited.shapeType, ShapeType.rectangle.name);
    expect(edited.shapeAnchors, const [
      Offset(116, 3),
      Offset(120, 0),
      Offset(120, 80),
      Offset(0, 80),
    ]);
    expect(canvas.shapeEditingHandles!.anchors, hasLength(4));

    canvas.undo();
    expect(canvas.page.strokes.single.shapeType, ShapeType.rectangle.name);
    expect(canvas.page.strokes.single.shapeAnchors, anchors);
    canvas.redo();
    expect(canvas.page.strokes.single.shapeType, ShapeType.rectangle.name);
    expect(canvas.page.strokes.single.shapeAnchors, hasLength(4));
  });

  test('rotation reports signed delta and move preserves internal angles', () {
    const anchors = [Offset(0, 0), Offset(100, 0), Offset(50, 80)];
    addShape(ShapeType.triangle, anchors);
    final initialAngles = ShapeDetector.polygonAngles(anchors);
    final handle = canvas.shapeEditingHandles!.rotate;
    final center = canvas.activeShapeEditStroke!.pointBounds.center;
    expect(
      handle.dy,
      greaterThan(canvas.activeShapeEditStroke!.pointBounds.bottom),
    );
    final radius = (handle - center).distance;

    expect(canvas.beginShapeEditGesture(handle), isTrue);
    canvas.updateShapeEditGesture(center + Offset(radius, 0));
    expect(canvas.shapeRotationDelta, closeTo(-pi / 2, 0.05));
    canvas.endShapeEditGesture();

    final rotated = canvas.activeShapeEditStroke!;
    final rotatedAngles = ShapeDetector.polygonAngles(rotated.shapeAnchors!);
    for (var i = 0; i < initialAngles.length; i++) {
      expect(rotatedAngles[i], closeTo(initialAngles[i], 1e-8));
    }

    final moveStart = rotated.pointBounds.center;
    expect(canvas.beginShapeEditGesture(moveStart), isTrue);
    canvas.updateShapeEditGesture(moveStart + const Offset(30, 40));
    canvas.endShapeEditGesture();
    final movedAngles = ShapeDetector.polygonAngles(
      canvas.activeShapeEditStroke!.shapeAnchors!,
    );
    for (var i = 0; i < rotatedAngles.length; i++) {
      expect(movedAngles[i], closeTo(rotatedAngles[i], 1e-8));
    }
  });

  test('shape edit is one undo step and cancellation restores the stroke', () {
    const anchors = [Offset(0, 0), Offset(100, 0)];
    final original = addShape(ShapeType.line, anchors);

    expect(canvas.beginShapeEditGesture(anchors.last), isTrue);
    canvas.updateShapeEditGesture(const Offset(140, 20));
    canvas.endShapeEditGesture();
    expect(
      canvas.page.strokes.single.shapeAnchors!.last,
      const Offset(140, 20),
    );

    canvas.undo();
    expect(canvas.page.strokes.single.shapeAnchors, anchors);
    canvas.redo();
    expect(
      canvas.page.strokes.single.shapeAnchors!.last,
      const Offset(140, 20),
    );

    canvas.activateShapeEditing(canvas.page.strokes.single);
    expect(
      canvas.beginShapeEditGesture(
        canvas.page.strokes.single.shapeAnchors!.last,
      ),
      isTrue,
    );
    canvas.updateShapeEditGesture(const Offset(200, 50));
    canvas.cancelShapeEditGesture();
    expect(
      canvas.page.strokes.single.shapeAnchors!.last,
      const Offset(140, 20),
    );
    expect(canvas.page.strokes.single.id, original.id);
  });

  test('ellipse axis handle resizes one axis and keeps the opposite fixed', () {
    const anchors = [
      Offset(100, 50),
      Offset(50, 100),
      Offset(0, 50),
      Offset(50, 0),
    ];
    addShape(ShapeType.circle, anchors);

    expect(canvas.beginShapeEditGesture(anchors.first), isTrue);
    canvas.updateShapeEditGesture(const Offset(140, 50));
    final edited = canvas.activeShapeEditStroke!;

    expect(edited.shapeAnchors![0], const Offset(140, 50));
    expect(edited.shapeAnchors![2], const Offset(0, 50));
    expect(edited.shapeAnchors![1], const Offset(70, 100));
    expect(edited.shapeAnchors![3], const Offset(70, 0));
  });

  test('lasso transforms preserve and transform semantic anchors', () {
    const anchors = [
      Offset(10, 10),
      Offset(110, 10),
      Offset(110, 70),
      Offset(10, 70),
    ];
    addShape(ShapeType.rectangle, anchors);
    canvas.clearShapeEditing();
    canvas.beginLasso(const Offset(-20, -20));
    for (final point in const [
      Offset(150, -20),
      Offset(150, 100),
      Offset(-20, 100),
    ]) {
      canvas.addLassoPoint(point);
    }
    canvas.endLasso();

    canvas.transformSelectedStrokes(
      scaleFactor: 2,
      rotationAngle: pi / 2,
      pivotPoint: Offset.zero,
    );
    final transformed = canvas.page.strokes.single.shapeAnchors!;
    final expected = [
      for (final anchor in anchors) Offset(-anchor.dy * 2, anchor.dx * 2),
    ];
    for (var i = 0; i < expected.length; i++) {
      expect(transformed[i].dx, closeTo(expected[i].dx, 1e-8));
      expect(transformed[i].dy, closeTo(expected[i].dy, 1e-8));
    }
  });

  test('newly recognized shape is editable and outside tap dismisses it', () {
    canvas.setShapeDetection(true);
    canvas.beginStroke(Offset.zero, 0.5, tool: ToolType.pen);
    for (var x = 10.0; x <= 200; x += 10) {
      canvas.addStrokePoint(Offset(x, 0), 0.5);
    }
    canvas.endStroke();

    expect(canvas.activeShapeEditStroke, same(canvas.page.strokes.single));
    expect(canvas.activeShapeAnchors, hasLength(2));
    expect(canvas.beginShapeEditGesture(const Offset(500, 500)), isFalse);
    expect(canvas.activeShapeEditStroke, isNull);
  });

  test('shape handle hit area remains fixed in screen space', () {
    const anchors = [Offset(0, 0), Offset(100, 0)];
    addShape(ShapeType.line, anchors);

    for (final zoom in [1.0, 4.0]) {
      canvas.setView(zoom, Offset.zero);
      final handles = canvas.shapeEditingHandles!;
      expect(handles.radius * zoom, closeTo(9, 1e-8));
      expect(
        canvas.beginShapeEditGesture(anchors.first + Offset(20 / zoom, 0)),
        isTrue,
      );
      expect(canvas.shapeEditOperation, ShapeEditOperation.anchor);
      canvas.cancelShapeEditGesture();
    }
  });
}
