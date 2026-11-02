// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../logic/canvas_controller.dart';
import '../../logic/pen_presets.dart';
import '../../models/stroke.dart';
import '../theme/inklus_colors.dart';
import '../theme/tokens.dart';
import '../widgets/controller_selector.dart';
import 'anchored_popover.dart';
import 'tool_popovers.dart';
import 'tool_visuals.dart';
import '../../l10n/l10n.dart';
import '../widgets/notebook_covers.dart';

/// Two-row editor header inspired by dedicated handwriting apps.
///
/// ```
/// [←] Title · Page 2/5                         [Pages] [Layers] [☁] [⋮] [⌃]
/// [↶] [↷] | [pens] [eraser] [lasso] [text] ... | [colors] [sizes]
/// ```
///
/// The document row remains stable. The second row can collapse and keeps
/// common ink color/size controls visible. Tapping an active tool still opens
/// its complete anchored popover.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.canvas,
    required this.presets,
    required this.onBack,
    required this.onEditTitle,
    required this.onInsertImage,
    required this.onTemplates,
    required this.onInsertSticker,
    required this.pagesOpen,
    required this.onTogglePages,
    required this.layersOpen,
    required this.onToggleLayers,
    required this.toolsCollapsed,
    required this.onToggleTools,
    required this.trailing,
  });

  final CanvasController canvas;
  final PenPresetsController presets;
  final VoidCallback onBack;
  final VoidCallback onEditTitle;
  final VoidCallback onInsertImage;
  final VoidCallback onTemplates;
  final VoidCallback onInsertSticker;
  final bool pagesOpen;
  final VoidCallback onTogglePages;
  final bool layersOpen;
  final VoidCallback onToggleLayers;
  final bool toolsCollapsed;
  final VoidCallback onToggleTools;

  /// Acciones de la derecha (nube, menú ⋮) que construye la pantalla.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.inklus.toolbar,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.inklus.toolbarBorder),
          ),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            canvas.toolContextNotifier,
            canvas.bottomBarContextNotifier,
            presets,
          ]),
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: Sizes.editorDocumentBar,
                child: _ToolbarRowInset(
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: context.l10n.tbBackToLibrary,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onBack,
                      ),
                      Expanded(
                        child: _TitleButton(canvas: canvas, onTap: onEditTitle),
                      ),
                      _ToolbarButton(
                        icon: Icons.view_sidebar_outlined,
                        label: pagesOpen
                            ? context.l10n.tbHidePages
                            : context.l10n.tbPages,
                        selected: pagesOpen,
                        onTap: onTogglePages,
                      ),
                      _ToolbarButton(
                        icon: layersOpen ? Icons.layers : Icons.layers_outlined,
                        label: layersOpen
                            ? context.l10n.tbHideLayers
                            : context.l10n.tbLayers,
                        selected: layersOpen,
                        onTap: onToggleLayers,
                      ),
                      _ToolbarButton(
                        icon: ToolVisuals.icon(ToolType.select),
                        toolIcon: ToolType.select,
                        label: context.l10n.tbMoveSelect,
                        selected: canvas.tool == ToolType.select,
                        onTap: () => canvas.setTool(ToolType.select),
                      ),
                      ...trailing,
                      IconButton(
                        tooltip: toolsCollapsed
                            ? context.l10n.tbShowTools
                            : context.l10n.tbHideTools,
                        icon: AnimatedRotation(
                          turns: toolsCollapsed ? 0.5 : 0,
                          duration: Motion.fast,
                          child: const Icon(Icons.keyboard_arrow_up),
                        ),
                        onPressed: onToggleTools,
                      ),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: Motion.normal,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: toolsCollapsed
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: context.inklus.toolbarBorder,
                            ),
                            SizedBox(
                              height: Sizes.editorToolBar,
                              child: _ToolbarRowInset(
                                child: LayoutBuilder(
                                  builder: (context, rowConstraints) {
                                    final compactControls =
                                        rowConstraints.maxWidth <
                                        Breakpoints.compact;
                                    return Row(
                                      children: [
                                        _UndoRedo(canvas: canvas),
                                        const _Divider(),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: Spacing.xs,
                                            ),
                                            child: LayoutBuilder(
                                              builder: (context, constraints) =>
                                                  SingleChildScrollView(
                                                    key: const Key(
                                                      'editor-tool-scroll',
                                                    ),
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                            minWidth:
                                                                constraints
                                                                    .maxWidth,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: _allTools(
                                                          context,
                                                          compact:
                                                              compactControls,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        _InlineToolControls(
                                          key: const Key(
                                            'editor-inline-controls',
                                          ),
                                          canvas: canvas,
                                          presets: presets,
                                          maxColorSlots: compactControls
                                              ? 1
                                              : 5,
                                          maxSizeSlots: compactControls ? 1 : 3,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _allTools(BuildContext context, {required bool compact}) {
    final tool = canvas.tool;
    final slots = compact
        ? [presets.activeSlot]
        : [
            for (var i = 0; i < PenPresetsController.slotCount; i++) i,
            PenPresetsController.highlighterSlot,
          ];
    return [
      for (final slot in slots) _penSlot(context, slot, tool),
      _toolWithOptions(
        context,
        ToolType.eraser,
        (c) => EraserPopover(canvas: canvas),
      ),
      _ToolbarButton(
        icon: ToolVisuals.icon(ToolType.lasso),
        toolIcon: ToolType.lasso,
        label: ToolVisuals.label(context, ToolType.lasso),
        selected: tool == ToolType.lasso,
        onTap: () => canvas.setTool(ToolType.lasso),
      ),
      _toolWithOptions(
        context,
        ToolType.text,
        (c) => ColorPopover(canvas: canvas, presets: presets),
      ),
      _ToolbarButton(
        icon: Icons.add_photo_alternate_outlined,
        label: context.l10n.tbInsertImage,
        onTap: onInsertImage,
      ),
      _ToolbarButton(
        icon: canvas.rulerEnabled && canvas.rulerType == RulerType.protractor
            ? Icons.architecture
            : Icons.straighten,
        label: !canvas.rulerEnabled
            ? context.l10n.tbRuler
            : canvas.rulerType == RulerType.straight
            ? context.l10n.tbRulerNext
            : context.l10n.tbProtractorNext,
        selected: canvas.rulerEnabled,
        onTap: canvas.cycleRuler,
      ),
      _ToolbarButton(
        icon: canvas.laserMode ? Icons.flashlight_off : Icons.flashlight_on,
        label: canvas.laserMode
            ? context.l10n.tbLaserOff
            : context.l10n.tbLaser,
        selected: canvas.laserMode,
        onTap: canvas.toggleLaser,
      ),
      _ToolbarButton(
        icon: Icons.emoji_emotions_outlined,
        label: context.l10n.tbInsertSticker,
        onTap: onInsertSticker,
      ),
      _MoreToolsButton(canvas: canvas, onTemplates: onTemplates),
    ];
  }

  /// Ranura de pluma favorita / resaltador.
  Widget _penSlot(BuildContext context, int slot, ToolType currentTool) {
    final preset = presets.presetAt(slot);
    final showing = presets.isShowing(slot, currentTool);
    return Builder(
      builder: (anchor) => _ToolbarButton(
        icon: ToolVisuals.icon(preset.tool),
        toolIcon: preset.tool,
        label: slot == PenPresetsController.highlighterSlot
            ? context.l10n.popHighlighter
            : context.l10n.tbPenSlot(
                ToolVisuals.label(context, preset.tool),
                slot + 1,
              ),
        selected: showing,
        glyphColor: preset.color,
        onTap: () {
          if (showing) {
            showAnchoredPopover<void>(
              context: context,
              anchorContext: anchor,
              builder: (_) => PenPopover(canvas: canvas, presets: presets),
            );
          } else {
            presets.activate(slot, canvas);
          }
        },
      ),
    );
  }

  /// Herramienta que, si ya está activa, abre su popover al tocarla.
  Widget _toolWithOptions(
    BuildContext context,
    ToolType type,
    WidgetBuilder popover,
  ) {
    final selected = canvas.tool == type;
    return Builder(
      builder: (anchor) => _ToolbarButton(
        icon: ToolVisuals.icon(type),
        toolIcon: type,
        label: ToolVisuals.label(context, type),
        selected: selected,
        onTap: () {
          if (selected) {
            showAnchoredPopover<void>(
              context: context,
              anchorContext: anchor,
              builder: popover,
            );
          } else {
            canvas.setTool(type);
          }
        },
      ),
    );
  }
}

/// "Más herramientas": rellenar, escritura ampliada y plantillas.
class _MoreToolsButton extends StatelessWidget {
  const _MoreToolsButton({required this.canvas, required this.onTemplates});

  final CanvasController canvas;
  final VoidCallback onTemplates;

  @override
  Widget build(BuildContext context) {
    final extraSelected =
        canvas.tool == ToolType.bucket || canvas.magnifierEnabled;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(ToolVisuals.icon(ToolType.bucket)),
          onPressed: () => canvas.setTool(ToolType.bucket),
          child: Text(context.l10n.tbFill),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            canvas.magnifierEnabled ? Icons.search_off : Icons.search,
          ),
          onPressed: canvas.toggleMagnifier,
          child: Text(
            canvas.magnifierEnabled
                ? context.l10n.tbHideMagnifier
                : context.l10n.tbMagnifier,
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.dashboard_customize_outlined),
          onPressed: onTemplates,
          child: Text(context.l10n.tbPageTemplate),
        ),
      ],
      builder: (context, menu, _) => _ToolbarButton(
        icon: Icons.more_horiz,
        label: context.l10n.tbMoreTools,
        selected: extraSelected,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// Context-sensitive controls pinned to the right edge. Tools without color
/// or size settings leave this area empty without affecting left alignment.
class _InlineToolControls extends StatelessWidget {
  const _InlineToolControls({
    super.key,
    required this.canvas,
    required this.presets,
    required this.maxColorSlots,
    required this.maxSizeSlots,
  });

  final CanvasController canvas;
  final PenPresetsController presets;
  final int maxColorSlots;
  final int maxSizeSlots;

  bool get _showsColors =>
      canvas.isInkTool ||
      canvas.tool == ToolType.highlighter ||
      canvas.tool == ToolType.text;

  bool get _showsSizes =>
      canvas.isInkTool ||
      canvas.tool == ToolType.highlighter ||
      canvas.tool == ToolType.eraser;

  List<double> get _quickSizes {
    final (min, max) = canvas.sizeRange;
    final span = max - min;
    return [min + span * 0.12, min + span * 0.3, min + span * 0.6];
  }

  void _pickSize(double size) {
    canvas.setToolSize(size);
    presets.syncFrom(canvas);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showsColors && !_showsSizes) return const SizedBox.shrink();
    final allSizes = _quickSizes;
    final sizes = maxSizeSlots == 1
        ? [canvas.toolSize]
        : allSizes.take(maxSizeSlots).toList(growable: false);
    var selectedSize = 0;
    for (var i = 1; i < sizes.length; i++) {
      if ((canvas.toolSize - sizes[i]).abs() <
          (canvas.toolSize - sizes[selectedSize]).abs()) {
        selectedSize = i;
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Divider(),
        if (_showsColors)
          for (
            var i = 0;
            i < presets.toolbarColors.length && i < maxColorSlots;
            i++
          )
            _QuickColorButton(
              color: presets.toolbarColors[i],
              selected: i == presets.activeToolbarColorSlot,
              onTap: () => presets.activateToolbarColor(i, canvas),
            ),
        if (_showsColors && _showsSizes) const _Divider(),
        if (_showsSizes)
          for (var i = 0; i < sizes.length; i++)
            _QuickSizeButton(
              value: sizes[i],
              range: canvas.sizeRange,
              color: canvas.tool == ToolType.eraser
                  ? context.colors.outline
                  : canvas.color,
              selected: i == selectedSize,
              onTap: () => _pickSize(sizes[i]),
            ),
      ],
    );
  }
}

/// Centers toolbar content at 95% width on larger displays. Compact phones
/// keep every available pixel so document actions retain their touch targets.
class _ToolbarRowInset extends StatelessWidget {
  const _ToolbarRowInset({required this.child});

  static const _wideContentFactor = 0.95;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth >= Breakpoints.compact
          ? constraints.maxWidth * (1 - _wideContentFactor) / 2
          : 0.0;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        child: child,
      );
    },
  );
}

class _QuickColorButton extends StatelessWidget {
  const _QuickColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.colorSemantics(hex),
      excludeSemantics: true,
      child: Tooltip(
        message: context.l10n.colorSemantics(hex),
        child: InkResponse(
          onTap: onTap,
          radius: Sizes.minTouch / 2,
          child: SizedBox.square(
            dimension: Sizes.minTouch,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? context.colors.primary
                        : context.colors.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSizeButton extends StatelessWidget {
  const _QuickSizeButton({
    required this.value,
    required this.range,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final double value;
  final (double, double) range;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final span = range.$2 - range.$1;
    final fraction = span <= 0 ? 0.5 : (value - range.$1) / span;
    final diameter = 6 + 12 * fraction.clamp(0.0, 1.0);
    final label = '${context.l10n.popSize}: ${value.toStringAsFixed(1)}';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: Sizes.minTouch / 2,
          child: SizedBox.square(
            dimension: Sizes.minTouch,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? context.colors.primaryContainer
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({required this.canvas, required this.onTap});

  final CanvasController canvas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: Radii.smAll,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      child: ControllerSelector<CanvasController, (String, int, int)>(
        listenable: canvas,
        selector: (c) => (c.note.title, c.pageIndex, c.pageCount),
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayTitle(context.l10n, state.$1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall,
            ),
            Text(
              context.l10n.tbPageOf(state.$2 + 1, state.$3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _UndoRedo extends StatelessWidget {
  const _UndoRedo({required this.canvas});

  final CanvasController canvas;

  @override
  Widget build(BuildContext context) =>
      ControllerSelector<CanvasController, (bool, bool)>(
        listenable: canvas,
        selector: (c) => (c.canUndo, c.canRedo),
        builder: (context, state) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.l10n.tbUndo,
              icon: const Icon(Icons.undo),
              onPressed: state.$1 ? canvas.undo : null,
            ),
            IconButton(
              tooltip: context.l10n.tbRedo,
              icon: const Icon(Icons.redo),
              onPressed: state.$2 ? canvas.redo : null,
            ),
          ],
        ),
      );
}

/// Toolbar button with a tonal background while selected. Pen presets tint
/// their glyph directly with the assigned ink/highlighter color.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.glyphColor,
    this.toolIcon,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? glyphColor;
  final ToolType? toolIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Padding(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.mdAll,
            child: SizedBox.square(
              dimension: Sizes.minTouch,
              child: Center(
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: Radii.mdAll,
                  ),
                  child: toolIcon != null
                      ? ToolVisuals.buildIcon(
                          toolIcon!,
                          size: Sizes.toolIcon,
                          color: glyphColor ?? fg,
                        )
                      : Icon(
                          icon,
                          size: Sizes.toolIcon,
                          color: glyphColor ?? fg,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
    color: context.colors.outlineVariant,
  );
}
