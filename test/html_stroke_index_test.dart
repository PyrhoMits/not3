// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/html_stroke_index.dart';
import 'package:not3/models/stroke.dart';

void main() {
  Stroke stroke(String id, double top, double bottom) => Stroke(
    id: id,
    points: [StrokePoint(0, top, 1), StrokePoint(10, bottom, 1)],
    tool: ToolType.pen,
    colorValue: 0xff000000,
    size: 1,
  );

  test('returns only strokes intersecting the visible vertical chunks', () {
    final first = stroke('first', -10, 10);
    final distant = stroke('distant', 5000, 5010);
    final index = HtmlStrokeIndex([first, distant], chunkExtent: 1000);

    expect(index.visible(const Rect.fromLTRB(-100, -100, 100, 100)), [first]);
  });

  test('returns a tall stroke once when it spans several chunks', () {
    final tall = stroke('tall', -2500, 2500);
    final index = HtmlStrokeIndex([tall], chunkExtent: 1000);

    expect(index.visible(const Rect.fromLTRB(-100, -100, 100, 100)), [tall]);
  });
}
