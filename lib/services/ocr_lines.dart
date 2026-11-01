// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui';

import '../models/stroke.dart';

/// Groups strokes into lines before sending them to the digital-ink model.
///
/// The ML Kit model is designed for one line or a short phrase, not an entire
/// page. Sending everything together propagates errors between lines and
/// overflows its context window.
///
/// The heuristic is purely geometric and has no dependencies:
/// 1. Each stroke is assigned to the line with the greatest vertical overlap.
///    Diacritics and accents just above a line also match because their center
///    is compared with an expanded band.
/// 2. Very large horizontal gaps within a line split columns or separate
///    drawings into independent groups.
/// 3. Lines are returned from top to bottom, then left to right when they have
///    the same height, while preserving stroke order inside each line.
///
/// Strokes without points are discarded.
List<List<Stroke>> segmentStrokesIntoLines(List<Stroke> strokes) {
  final items = <_LineItem>[];
  for (var i = 0; i < strokes.length; i++) {
    final stroke = strokes[i];
    if (stroke.points.isEmpty) continue;
    items.add(_LineItem(stroke, i, stroke.pointBounds));
  }
  if (items.isEmpty) return const [];
  if (items.length == 1) {
    return [
      [items.single.stroke],
    ];
  }

  // Approximate reading order: top to bottom, then left to right.
  items.sort((a, b) {
    final byTop = a.bounds.top.compareTo(b.bounds.top);
    return byTop != 0 ? byTop : a.bounds.left.compareTo(b.bounds.left);
  });

  final rows = <_Row>[];
  for (final item in items) {
    _Row? bestRow;
    var bestScore = 0.0;
    for (final row in rows) {
      final score = _verticalAffinity(item.bounds, row.bounds);
      if (score > bestScore) {
        bestScore = score;
        bestRow = row;
      }
    }
    if (bestRow != null && bestScore >= 0.25) {
      bestRow.add(item);
    } else {
      rows.add(_Row(item));
    }
  }

  final groups = <_LineGroup>[];
  for (final row in rows) {
    groups.addAll(_splitLargeHorizontalGaps(row));
  }

  groups.sort((a, b) {
    final byTop = a.bounds.top.compareTo(b.bounds.top);
    return byTop != 0 ? byTop : a.bounds.left.compareTo(b.bounds.left);
  });

  return [
    for (final group in groups)
      [
        // Writing order matters to the temporal model. Do not reorder by X;
        // only discard empty strokes.
        for (final item
            in (group.items..sort((a, b) => a.index.compareTo(b.index))))
          item.stroke,
      ],
  ];
}

/// Measures how well [a] fits line [b]. Zero is no match; positive values fit.
double _verticalAffinity(Rect a, Rect b) {
  final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  final minHeight = math.min(a.height, b.height);
  if (overlap > 0 && minHeight > 0) {
    final ratio = overlap / minHeight;
    if (ratio >= 0.2) return ratio.clamp(0.0, 1.0);
  }

  // Thai and Japanese diacritics can sit outside strict overlap while still
  // remaining very close to the line center.
  final allowed = math.max(a.height, b.height) * 0.35 + 2;
  if ((a.center.dy - b.center.dy).abs() <= allowed) return 0.3;
  return 0;
}

List<_LineGroup> _splitLargeHorizontalGaps(_Row row) {
  final sorted = [...row.items]
    ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
  final heights =
      sorted
          .map((item) => item.bounds.height)
          .where((height) => height > 0)
          .toList()
        ..sort();
  final medianHeight = heights.isEmpty ? 0.0 : heights[heights.length ~/ 2];
  final maxGap = math.max(medianHeight * 4, 24.0);

  final groups = <_LineGroup>[];
  var current = <_LineItem>[];
  Rect? currentBounds;

  void flush() {
    if (current.isEmpty || currentBounds == null) return;
    groups.add(_LineGroup(current, currentBounds!));
    current = [];
    currentBounds = null;
  }

  for (final item in sorted) {
    final bounds = currentBounds;
    if (bounds != null && item.bounds.left - bounds.right > maxGap) {
      flush();
    }
    current.add(item);
    final updated = currentBounds;
    currentBounds = updated == null
        ? item.bounds
        : updated.expandToInclude(item.bounds);
  }
  flush();
  return groups;
}

class _LineItem {
  const _LineItem(this.stroke, this.index, this.bounds);

  final Stroke stroke;
  final int index;
  final Rect bounds;
}

class _Row {
  _Row(_LineItem item) : items = [item], bounds = item.bounds;

  final List<_LineItem> items;
  Rect bounds;

  void add(_LineItem item) {
    items.add(item);
    bounds = bounds.expandToInclude(item.bounds);
  }
}

class _LineGroup {
  const _LineGroup(this.items, this.bounds);

  final List<_LineItem> items;
  final Rect bounds;
}
