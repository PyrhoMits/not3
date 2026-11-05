// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/stroke.dart';

/// Icono y nombre visible de cada herramienta. **Única fuente**: la barra,
/// los popovers y las etiquetas de accesibilidad leen de aquí.
abstract final class ToolVisuals {
  static IconData icon(ToolType tool) => switch (tool) {
    ToolType.pen => Icons.edit,
    ToolType.pencil => Icons.draw,
    ToolType.calligraphy => Icons.history_edu,
    ToolType.brush => Icons.brush,
    ToolType.marker => Icons.format_paint,
    ToolType.spray => Icons.grain,
    ToolType.highlighter => Icons.border_color,
    // Flutter's bundled Material font has no physical eraser glyph.
    // Non-widget consumers use the closest clear/delete fallback, while
    // [buildIcon] draws the dedicated eraser used by the editor toolbar.
    ToolType.eraser => Icons.backspace_outlined,
    ToolType.select => Icons.pan_tool_alt,
    ToolType.lasso => Icons.gesture,
    ToolType.bucket => Icons.format_color_fill,
    ToolType.text => Icons.text_fields,
  };

  /// Builds the visible tool glyph. The eraser uses a lightweight vector
  /// drawing because the bundled Material icon set otherwise shows a broom.
  static Widget buildIcon(ToolType tool, {double? size, Color? color}) =>
      _ToolGlyph(tool: tool, size: size, color: color);

  static String label(BuildContext context, ToolType tool) => switch (tool) {
    ToolType.pen => context.l10n.toolPen,
    ToolType.pencil => context.l10n.toolPencil,
    ToolType.calligraphy => context.l10n.toolCalligraphy,
    ToolType.brush => context.l10n.toolBrush,
    ToolType.marker => context.l10n.toolMarker,
    ToolType.spray => context.l10n.toolSpray,
    ToolType.highlighter => context.l10n.popHighlighter,
    ToolType.eraser => context.l10n.toolEraser,
    ToolType.select => context.l10n.toolSelect,
    ToolType.lasso => context.l10n.toolLasso,
    ToolType.bucket => context.l10n.toolFill,
    ToolType.text => context.l10n.toolText,
  };

  /// Herramientas de tinta que puede usar una pluma favorita.
  static const penTools = [
    ToolType.pen,
    ToolType.pencil,
    ToolType.calligraphy,
    ToolType.brush,
    ToolType.marker,
    ToolType.spray,
  ];
}

class _ToolGlyph extends StatelessWidget {
  const _ToolGlyph({required this.tool, this.size, this.color});

  final ToolType tool;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    if (tool != ToolType.eraser) {
      return Icon(
        ToolVisuals.icon(tool),
        size: resolvedSize,
        color: resolvedColor,
      );
    }
    return Center(
      child: SizedBox.square(
        dimension: resolvedSize,
        child: CustomPaint(painter: _EraserGlyphPainter(resolvedColor)),
      ),
    );
  }
}

/// A stylus emitting a short beam toward a presentation dot.
///
/// Kept as local vector geometry so the laser does not require an SVG package
/// or an additional icon font.
class LaserPointerGlyph extends StatelessWidget {
  const LaserPointerGlyph({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: resolvedSize,
      child: Padding(
        padding: EdgeInsets.all(resolvedSize * 0.1),
        child: CustomPaint(
          key: const Key('laser-pointer-glyph'),
          painter: _LaserPointerGlyphPainter(resolvedColor),
        ),
      ),
    );
  }
}

class _LaserPointerGlyphPainter extends CustomPainter {
  const _LaserPointerGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    final stylus = Path()
      ..moveTo(side * 0.12, side * 0.72)
      ..lineTo(side * 0.28, side * 0.88)
      ..lineTo(side * 0.63, side * 0.53)
      ..lineTo(side * 0.47, side * 0.37)
      ..close();
    canvas.drawPath(stylus, stroke);
    canvas.drawLine(
      Offset(side * 0.50, side * 0.62),
      Offset(side * 0.39, side * 0.73),
      stroke,
    );

    canvas.drawLine(
      Offset(side * 0.65, side * 0.35),
      Offset(side * 0.78, side * 0.22),
      stroke,
    );
    canvas.drawCircle(Offset(side * 0.87, side * 0.13), side * 0.09, fill);
  }

  @override
  bool shouldRepaint(_LaserPointerGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A tilted, divided block eraser. Drawing it here avoids adding another icon
/// font solely for one glyph and follows the surrounding [IconTheme].
class _EraserGlyphPainter extends CustomPainter {
  const _EraserGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..save()
      ..translate(size.width * 0.5, size.height * 0.5)
      ..rotate(-math.pi / 4);

    final body = Rect.fromCenter(
      center: Offset.zero,
      width: side * 0.7,
      height: side * 0.38,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(side * 0.07)),
      stroke,
    );
    canvas.drawLine(
      Offset(side * 0.08, body.top),
      Offset(side * 0.08, body.bottom),
      stroke,
    );
    canvas.restore();

    // A short erased mark helps distinguish the glyph from a bandage.
    canvas.drawLine(
      Offset(side * 0.18, side * 0.84),
      Offset(side * 0.58, side * 0.84),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_EraserGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
