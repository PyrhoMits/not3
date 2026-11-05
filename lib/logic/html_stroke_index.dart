// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui';

import '../models/stroke.dart';

/// A lightweight vertical spatial index for continuous HTML annotations.
///
/// HTML notes can be millions of logical pixels tall. Grouping immutable
/// strokes by vertical chunk keeps viewport painting proportional to visible
/// ink instead of the total number of strokes in the document.
class HtmlStrokeIndex {
  HtmlStrokeIndex(Iterable<Stroke> strokes, {this.chunkExtent = 2048}) {
    assert(chunkExtent > 0);
    for (final stroke in strokes) {
      final bounds = stroke.paintBounds;
      final first = _chunkFor(bounds.top);
      final last = _chunkFor(bounds.bottom);
      for (var chunk = first; chunk <= last; chunk++) {
        (_chunks[chunk] ??= <Stroke>[]).add(stroke);
      }
    }
  }

  final double chunkExtent;
  final Map<int, List<Stroke>> _chunks = {};

  int _chunkFor(double y) => (y / chunkExtent).floor();

  Iterable<Stroke> visible(Rect viewport) sync* {
    if (viewport.isEmpty) return;
    final seen = <Stroke>{};
    final first = _chunkFor(viewport.top);
    final last = _chunkFor(viewport.bottom);
    for (var chunk = first; chunk <= last; chunk++) {
      for (final stroke in _chunks[chunk] ?? const <Stroke>[]) {
        if (seen.add(stroke) && stroke.paintBounds.overlaps(viewport)) {
          yield stroke;
        }
      }
    }
  }
}
