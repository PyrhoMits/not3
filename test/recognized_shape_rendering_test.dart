// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/shape_detector.dart';
import 'package:not3/models/stroke.dart';
import 'package:not3/ui/canvas/world_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('committed rectangle paints one joined closure corner', () async {
    const anchors = [
      Offset(30, 30),
      Offset(170, 30),
      Offset(170, 130),
      Offset(30, 130),
    ];
    final stroke = Stroke(
      id: 'rectangle',
      points: ShapeDetector.pointsFromAnchors(ShapeType.rectangle, anchors),
      tool: ToolType.pen,
      colorValue: 0xFF1565C0,
      size: 12,
      shapeType: ShapeType.rectangle.name,
      shapeAnchors: anchors,
    );
    final recorder = ui.PictureRecorder();
    paintStroke(Canvas(recorder), stroke);
    final image = await recorder.endRecording().toImage(200, 160);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);

    int alphaAt(int x, int y) =>
        bytes!.getUint8(((y * image.width) + x) * 4 + 3);

    // The first and last centerline samples meet at (30, 30). These pixels
    // cover the shared corner and both outgoing edges. A freehand start/end
    // seam leaves this corner clipped diagonally after the shape is released.
    expect(alphaAt(30, 30), greaterThan(220));
    expect(alphaAt(36, 30), greaterThan(220));
    expect(alphaAt(30, 36), greaterThan(220));
    expect(alphaAt(34, 34), greaterThan(220));
  });
}
