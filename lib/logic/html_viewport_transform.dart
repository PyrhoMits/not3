// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

/// Maps a WebView visual viewport to Not3's center-origin page coordinates.
///
/// [visibleCssWidth] comes from `window.visualViewport.width`, so the mapping
/// remains correct at both fit-to-width and browser pinch-zoom scales.
class HtmlViewportTransform {
  const HtmlViewportTransform({
    required this.documentSize,
    required this.viewportSize,
    required this.visibleCssWidth,
    required this.pageOffset,
  });

  final Size documentSize;
  final Size viewportSize;
  final double visibleCssWidth;
  final Offset pageOffset;

  double get scale {
    final width = visibleCssWidth.isFinite && visibleCssWidth > 0
        ? visibleCssWidth
        : documentSize.width;
    return viewportSize.width / width;
  }

  Offset get translate => Offset(
    (documentSize.width / 2 - pageOffset.dx) * scale,
    (documentSize.height / 2 - pageOffset.dy) * scale,
  );

  Offset viewportToWorld(Offset point) => (point - translate) / scale;

  double get maxPageLeft => (documentSize.width - viewportSize.width / scale)
      .clamp(0.0, double.infinity);

  double get maxPageTop => (documentSize.height - viewportSize.height / scale)
      .clamp(0.0, double.infinity);
}
