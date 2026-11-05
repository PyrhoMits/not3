// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../logic/canvas_controller.dart';
import '../../logic/palm_rejection.dart';
import '../../logic/stylus_input.dart';
import '../../models/stroke.dart';
import '../theme/inklus_colors.dart';
import '../theme/tokens.dart';
import 'world_painter.dart';

/// Fixed zoom-writing surface inspired by the writing windows in note apps.
///
/// The rectangle on the main canvas chooses the world area. Pointer input in
/// this panel is transformed back into the same world coordinates, so strokes
/// remain ordinary document strokes rather than a separate overlay.
class ZoomWritingOverlay extends StatelessWidget {
  const ZoomWritingOverlay({
    super.key,
    required this.controller,
    required this.imageCache,
    required this.viewportSize,
    required this.nightMode,
  });

  final CanvasController controller;
  final Map<String, ui.Image> imageCache;
  final Size viewportSize;
  final bool nightMode;

  static double panelHeightFor(Size viewport) => math.min(
    Sizes.zoomBoardMaxHeight,
    math.max(Sizes.zoomBoardMinHeight, viewport.height * 0.36),
  );

  @override
  Widget build(BuildContext context) {
    final panelHeight = panelHeightFor(viewportSize);
    final panelWidth = math.max(0.0, viewportSize.width - Spacing.md * 2);
    final contentSize = Size(
      panelWidth,
      math.max(0.0, panelHeight - Sizes.zoomBoardHeader),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => CustomPaint(
              painter: _ZoomTargetPainter(
                controller: controller,
                boardContentSize: contentSize,
                color: context.colors.primary,
              ),
            ),
          ),
        ),
        Positioned(
          left: Spacing.md,
          right: Spacing.md,
          bottom: Spacing.md,
          height: panelHeight,
          child: _ZoomWritingBoard(
            controller: controller,
            imageCache: imageCache,
            nightMode: nightMode,
          ),
        ),
      ],
    );
  }
}

class _ZoomWritingBoard extends StatefulWidget {
  const _ZoomWritingBoard({
    required this.controller,
    required this.imageCache,
    required this.nightMode,
  });

  final CanvasController controller;
  final Map<String, ui.Image> imageCache;
  final bool nightMode;

  @override
  State<_ZoomWritingBoard> createState() => _ZoomWritingBoardState();
}

class _ZoomWritingBoardState extends State<_ZoomWritingBoard> {
  final PalmRejection _palm = PalmRejection();
  final Set<int> _rejectedPointers = {};
  int? _drawingPointer;
  Size _contentSize = Size.zero;

  static const ColorFilter _nightModeFilter = ColorFilter.matrix(<double>[
    0.574,
    -1.43,
    -0.144,
    0,
    255,
    -0.426,
    -0.43,
    -0.144,
    0,
    255,
    -0.426,
    -1.43,
    0.856,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('zoom-writing-board'),
      color: context.colors.surface,
      elevation: Elevations.bar,
      shadowColor: context.inklus.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: Sizes.zoomBoardHeader,
            child: Padding(
              padding: const EdgeInsets.only(left: Spacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.zoom_in_map,
                    size: Sizes.toolIcon,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      context.l10n.tbMagnifier,
                      style: context.text.titleSmall,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => Text(
                      '${widget.controller.magnifierZoom.toStringAsFixed(1)}×',
                      style: context.text.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.zoomOut,
                    onPressed: () => widget.controller.setMagnifierZoom(
                      widget.controller.magnifierZoom / 1.25,
                    ),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: context.l10n.zoomIn,
                    onPressed: () => widget.controller.setMagnifierZoom(
                      widget.controller.magnifierZoom * 1.25,
                    ),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    onPressed: widget.controller.toggleMagnifier,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.colors.outlineVariant),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _contentSize = constraints.biggest;
                Widget canvas = RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _ZoomBoardPainter(
                        controller: widget.controller,
                        imageCache: widget.imageCache,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ),
                );
                if (widget.nightMode) {
                  canvas = ColorFiltered(
                    colorFilter: _nightModeFilter,
                    child: canvas,
                  );
                }
                return Listener(
                  key: const ValueKey('zoom-writing-surface'),
                  behavior: HitTestBehavior.opaque,
                  onPointerHover: _onPointerHover,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: canvas,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (PalmRejection.isStylusKind(event.kind)) _palm.stylusHoverEvent();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_drawingPointer != null) return;
    final kind = event.kind;
    final stylus = PalmRejection.isStylusKind(kind);
    final mouse = kind == PointerDeviceKind.mouse;
    final touch = kind == PointerDeviceKind.touch;
    if (!stylus && !mouse && !touch) return;

    if (stylus) {
      _palm.stylusDownEvent(event.pointer);
      widget.controller.onStylusDetected();
    } else if (touch) {
      if (_palm.rejectTouch(radiusMajor: event.radiusMajor) ||
          !widget.controller.fingerDrawingEnabled) {
        _rejectedPointers.add(event.pointer);
        return;
      }
    }

    final physicalEraser = isPhysicalStylusEraser(kind, event.buttons);
    final tool = physicalEraser ? ToolType.eraser : widget.controller.tool;
    if (!_supportsWriting(tool)) return;

    _drawingPointer = event.pointer;
    widget.controller.beginStroke(
      _toWorld(event.localPosition),
      event.pressure,
      tool: tool,
      timeStamp: event.timeStamp,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _drawingPointer) return;
    widget.controller.addStrokePoint(
      _toWorld(event.localPosition),
      event.pressure,
      timeStamp: event.timeStamp,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (PalmRejection.isStylusKind(event.kind)) {
      _palm.stylusUpEvent(event.pointer);
    }
    _rejectedPointers.remove(event.pointer);
    if (event.pointer != _drawingPointer) return;
    _drawingPointer = null;
    widget.controller.endStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (PalmRejection.isStylusKind(event.kind)) {
      _palm.stylusUpEvent(event.pointer);
    }
    _rejectedPointers.remove(event.pointer);
    if (event.pointer != _drawingPointer) return;
    _drawingPointer = null;
    widget.controller.cancelStroke();
  }

  bool _supportsWriting(ToolType tool) => switch (tool) {
    ToolType.select ||
    ToolType.lasso ||
    ToolType.bucket ||
    ToolType.text => false,
    _ => true,
  };

  Offset _toWorld(Offset local) {
    final scale = widget.controller.scale * widget.controller.magnifierZoom;
    if (scale <= 0 || _contentSize.isEmpty) {
      return widget.controller.magnifierPosition;
    }
    return widget.controller.magnifierPosition +
        (local - _contentSize.center(Offset.zero)) / scale;
  }
}

class _ZoomBoardPainter extends CustomPainter {
  const _ZoomBoardPainter({
    required this.controller,
    required this.imageCache,
    required this.isDark,
  });

  final CanvasController controller;
  final Map<String, ui.Image> imageCache;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = controller.scale * controller.magnifierZoom;
    if (scale <= 0) return;
    final center = size.center(Offset.zero);
    final focus = controller.magnifierPosition;
    final translate = center - focus * scale;
    final visible = Rect.fromLTRB(
      -translate.dx / scale,
      -translate.dy / scale,
      (size.width - translate.dx) / scale,
      (size.height - translate.dy) / scale,
    );

    canvas.save();
    canvas.translate(translate.dx, translate.dy);
    canvas.scale(scale);
    paintWorld(
      canvas,
      visibleWorldRect: visible,
      page: controller.page,
      sheetSize: controller.sheetSize,
      imageCache: imageCache,
      viewScale: scale,
      isDark: isDark,
    );
    final active = controller.activeStroke;
    if (active != null) paintActiveStroke(canvas, active, viewScale: scale);
    canvas.restore();

    final guide = Paint()
      ..color = kAccentColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - Spacing.sm, center.dy),
      Offset(center.dx + Spacing.sm, center.dy),
      guide,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - Spacing.sm),
      Offset(center.dx, center.dy + Spacing.sm),
      guide,
    );
  }

  @override
  bool shouldRepaint(_ZoomBoardPainter oldDelegate) => true;
}

class _ZoomTargetPainter extends CustomPainter {
  const _ZoomTargetPainter({
    required this.controller,
    required this.boardContentSize,
    required this.color,
  });

  final CanvasController controller;
  final Size boardContentSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (boardContentSize.isEmpty || controller.magnifierZoom <= 0) return;
    final center =
        controller.magnifierPosition * controller.scale + controller.translate;
    final rect = Rect.fromCenter(
      center: center,
      width: boardContentSize.width / controller.magnifierZoom,
      height: boardContentSize.height / controller.magnifierZoom,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(Radii.sm),
    );
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, Spacing.xs, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ZoomTargetPainter oldDelegate) => true;
}
