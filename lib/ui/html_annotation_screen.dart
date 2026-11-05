// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../logic/canvas_controller.dart';
import '../logic/html_stroke_index.dart';
import '../logic/html_viewport_transform.dart';
import '../logic/pen_presets.dart';
import '../logic/stylus_input.dart';
import '../l10n/l10n.dart';
import '../models/note.dart';
import '../models/stroke.dart';
import '../services/drive_sync_service.dart';
import '../services/huawei_stylus_shortcut_service.dart';
import '../services/html_math_baker.dart';
import '../services/storage_service.dart';
import 'canvas/drawing_canvas.dart' show ActiveLayerPainter;
import 'canvas/world_painter.dart' show paintStroke;
import 'editor/anchored_popover.dart';
import 'editor/tool_popovers.dart';
import 'editor/tool_visuals.dart';
import 'theme/inklus_colors.dart';

/// Android-only editor for one self-contained continuous HTML note.
class HtmlAnnotationScreen extends StatefulWidget {
  const HtmlAnnotationScreen({
    super.key,
    required this.note,
    required this.notebookId,
    required this.storage,
  });

  final Note note;
  final String notebookId;
  final StorageService storage;

  @override
  State<HtmlAnnotationScreen> createState() => _HtmlAnnotationScreenState();
}

class _HtmlAnnotationScreenState extends State<HtmlAnnotationScreen>
    with WidgetsBindingObserver {
  late final CanvasController _canvas;
  final PenPresetsController _presets = PenPresetsController();
  final DriveSyncService _syncService = DriveSyncService.instance;
  final HuaweiStylusShortcutService _stylusShortcuts =
      HuaweiStylusShortcutService.instance;
  StreamSubscription<HuaweiStylusShortcut>? _stylusShortcutSubscription;
  WebViewController? _web;
  String? _error;
  bool _ready = false;
  bool _readMode = false;
  bool _closing = false;
  bool _remoteSyncPending = false;
  Timer? _remoteSyncTimer;
  double _scrollX = 0;
  double _scrollY = 0;
  double _viewportWidth = 1;
  double _viewportHeight = 1;
  double _visibleCssWidth = 1191;
  int? _drawingPointer;
  int? _scrollPointer;
  bool _movingSelection = false;
  Offset? _selectionStart;
  List<Stroke> _selectionBefore = const [];
  Offset? _scrollAnchor;
  double _scrollStartX = 0;
  double _scrollStartY = 0;
  HtmlStrokeIndex? _strokeIndex;
  int _strokeIndexVersion = -1;
  Future<void> _mathBakeWrite = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _canvas = CanvasController(
      widget.storage,
      initial: widget.note,
      notebookId: widget.notebookId,
    );
    unawaited(
      _presets.load().then((_) {
        if (!mounted) return;
        _presets.activate(_presets.activeSlot, _canvas);
        _canvas.bottomBarContextNotifier.addListener(_syncPresets);
      }),
    );
    _stylusShortcutSubscription = _stylusShortcuts.events.listen((shortcut) {
      if (shortcut == HuaweiStylusShortcut.togglePenEraser) {
        _canvas.toggleHuaweiPenEraser();
      }
    });
    _canvas.onRemoteSync = (_) async {
      _remoteSyncPending = true;
      _remoteSyncTimer ??= Timer(const Duration(seconds: 20), _runRemoteSync);
    };
    unawaited(_stylusShortcuts.start());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      _stylusShortcuts.setAppActive(state == AppLifecycleState.resumed),
    );
    if (state != AppLifecycleState.resumed) unawaited(_canvas.flush());
  }

  Future<void> _load() async {
    if (!Platform.isAndroid) {
      setState(() => _error = context.l10n.htmlAndroidOnly);
      return;
    }
    try {
      final file = await widget.storage.htmlSourceFile(_canvas.page);
      var html = await file.readAsString();
      if (HtmlMathBaker.needsBake(html)) {
        final cache = await widget.storage.htmlMathCacheFile(_canvas.page);
        final cachedHtml = await cache.exists()
            ? await cache.readAsString()
            : '';
        if (HtmlMathBaker.isCurrentBake(cachedHtml)) {
          html = cachedHtml;
        } else {
          final mathJax = await rootBundle.loadString(HtmlMathBaker.assetPath);
          html = HtmlMathBaker.runtimeHtml(html, mathJax);
        }
      }
      if (!mounted) return;
      final web = WebViewController();
      if (web.platform is AndroidWebViewController) {
        await (web.platform as AndroidWebViewController).setUseWideViewPort(
          true,
        );
      }
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(Colors.white);
      await web.enableZoom(true);
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.isMainFrame &&
                uri != null &&
                const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
              unawaited(_confirmExternalLink(uri));
              return NavigationDecision.prevent;
            }
            return request.url.startsWith('about:') ||
                    request.url.startsWith('data:')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) => _installBridge(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _error = error.description);
            }
          },
        ),
      );
      await web.addJavaScriptChannel(
        'Not3Html',
        onMessageReceived: (message) => _handleBridge(message.message),
      );
      _web = web;
      await web.loadHtmlString(html);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _installBridge() async {
    final web = _web;
    if (web == null) return;
    await web.runJavaScript('''
(() => {
  if (window.__not3BridgeInstalled) return;
  window.__not3BridgeInstalled = true;
  let queued = false;
  const height = () => Math.max(
    document.documentElement.scrollHeight,
    document.body ? document.body.scrollHeight : 0
  );
  const report = (type) => Not3Html.postMessage(JSON.stringify({
    type: type,
    x: window.visualViewport ? window.visualViewport.pageLeft : (window.scrollX || 0),
    y: window.visualViewport ? window.visualViewport.pageTop : (window.scrollY || 0),
    viewportWidth: window.visualViewport ? window.visualViewport.width : window.innerWidth,
    height: height()
  }));
  const reportScroll = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => { queued = false; report('scroll'); });
  };
  addEventListener('scroll', reportScroll, {passive: true});
  if (window.visualViewport) {
    window.visualViewport.addEventListener('scroll', reportScroll, {passive: true});
    window.visualViewport.addEventListener('resize', reportScroll, {passive: true});
  }
  document.addEventListener('click', (event) => {
    const anchor = event.target && event.target.closest
      ? event.target.closest('a[href]') : null;
    if (!anchor) return;
    const href = anchor.getAttribute('href') || '';
    if (href.startsWith('#')) return;
    event.preventDefault();
    Not3Html.postMessage(JSON.stringify({type: 'link', href: href}));
  }, true);
  const installSectionCulling = () => {
    const originalHeight = height();
    const candidates = Array.from(document.querySelectorAll('section, article'))
      .filter((element) => {
        const parent = element.parentElement;
        return !parent || !parent.closest('section, article');
      });
    const applied = [];
    for (const element of candidates) {
      const measured = element.getBoundingClientRect().height;
      if (!Number.isFinite(measured) || measured < 1) continue;
      element.style.contentVisibility = 'auto';
      element.style.containIntrinsicSize =
        'auto ' + measured.toFixed(3) + 'px';
      applied.push(element);
    }
    const optimizedHeight = height();
    if (Math.abs(optimizedHeight - originalHeight) > 1) {
      for (const element of applied) {
        element.style.removeProperty('content-visibility');
        element.style.removeProperty('contain-intrinsic-size');
      }
    }
  };
  const fonts = document.fonts && document.fonts.ready
    ? document.fonts.ready.catch(() => {}) : Promise.resolve();
  const mathReady = window.__not3MathReady || Promise.resolve(null);
  mathReady.then((bakedHtml) => {
    if (typeof bakedHtml === 'string' && bakedHtml.length <= 12582912) {
      Not3Html.postMessage(JSON.stringify({type: 'mathBaked', html: bakedHtml}));
    }
    return fonts;
  }).then(() => requestAnimationFrame(() => {
    installSectionCulling();
    requestAnimationFrame(() => report('ready'));
  }));
  if (window.ResizeObserver) {
    window.__not3ResizeObserver = new ResizeObserver(() => {
      requestAnimationFrame(() => report('resize'));
    });
    window.__not3ResizeObserver.observe(document.documentElement);
  }
})();
''');
  }

  void _handleBridge(String raw) {
    if (!mounted) return;
    try {
      final message = jsonDecode(raw) as Map<String, dynamic>;
      switch (message['type']) {
        case 'mathBaked':
          final html = message['html'];
          if (html is String && html.isNotEmpty) {
            _mathBakeWrite = _persistBakedMath(html);
          }
        case 'link':
          final uri = Uri.tryParse(message['href'] as String? ?? '');
          if (uri != null &&
              const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
            unawaited(_confirmExternalLink(uri));
          }
        case 'ready':
          final measured = (message['height'] as num?)?.toDouble() ?? 0;
          if (_canvas.page.strokes.isEmpty && measured > 0) {
            _canvas.setHtmlContentHeight(measured);
          }
          _updateViewportFromMessage(message);
          setState(() => _ready = true);
          _updateCanvasView();
        case 'scroll':
          _updateViewportFromMessage(message);
          _updateCanvasView();
        case 'resize':
          final measured = (message['height'] as num?)?.toDouble() ?? 0;
          if (_canvas.page.strokes.isEmpty && measured > 0) {
            _canvas.setHtmlContentHeight(measured);
          }
          _updateViewportFromMessage(message);
          _updateCanvasView();
      }
    } catch (_) {
      // Ignore malformed messages from imported content.
    }
  }

  Future<void> _persistBakedMath(String html) async {
    try {
      final sanitized = await compute(HtmlMathBaker.sanitizeBaked, html);
      await widget.storage.replaceHtmlMathCache(_canvas.page, sanitized);
    } catch (error) {
      debugPrint('HtmlAnnotationScreen: math bake persistence failed: $error');
    }
  }

  void _updateViewportFromMessage(Map<String, dynamic> message) {
    _scrollX = (message['x'] as num?)?.toDouble() ?? _scrollX;
    _scrollY = (message['y'] as num?)?.toDouble() ?? _scrollY;
    _visibleCssWidth =
        (message['viewportWidth'] as num?)?.toDouble() ?? _visibleCssWidth;
  }

  HtmlViewportTransform get _transform => HtmlViewportTransform(
    documentSize: _canvas.sheetSize,
    viewportSize: Size(_viewportWidth, _viewportHeight),
    visibleCssWidth: _visibleCssWidth,
    pageOffset: Offset(_scrollX, _scrollY),
  );

  double get _scale => _transform.scale;

  void _updateCanvasView() {
    final html = _canvas.page.htmlContent;
    if (html == null) return;
    final transform = _transform;
    _canvas.setView(transform.scale, transform.translate);
  }

  Offset _worldPoint(Offset local) => _transform.viewportToWorld(local);

  void _onPointerDown(PointerDownEvent event) {
    if (!_ready) return;
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _drawingPointer = event.pointer;
      _canvas.onStylusDetected();
      final world = _worldPoint(event.localPosition);
      if (_canvas.tool == ToolType.select) {
        final hitArea = _canvas.selectionBoundsAll.inflate(24 / _scale);
        if (_canvas.hasLassoSelection && hitArea.contains(world)) {
          _movingSelection = true;
          _selectionStart = world;
          _selectionBefore = List<Stroke>.from(_canvas.selectedStrokes);
        } else {
          _canvas.clearLassoSelection();
        }
        return;
      }
      _canvas.beginStroke(
        world,
        event.pressure,
        tool: isPhysicalStylusEraser(event.kind, event.buttons)
            ? ToolType.eraser
            : _canvas.tool,
        timeStamp: event.timeStamp,
      );
      return;
    }
    if (event.kind == PointerDeviceKind.touch && _scrollPointer == null) {
      _scrollPointer = event.pointer;
      _scrollAnchor = event.localPosition;
      _scrollStartX = _scrollX;
      _scrollStartY = _scrollY;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == _drawingPointer) {
      if (_movingSelection && _selectionStart != null) {
        _canvas.moveSelectedStrokes(
          _worldPoint(event.localPosition) - _selectionStart!,
          before: _selectionBefore,
        );
        return;
      }
      _canvas.addStrokePoint(
        _worldPoint(event.localPosition),
        event.pressure,
        timeStamp: event.timeStamp,
      );
      return;
    }
    if (event.pointer == _scrollPointer && _scrollAnchor != null) {
      final delta = (event.localPosition - _scrollAnchor!) / _scale;
      final transform = _transform;
      final maxScrollX = transform.maxPageLeft;
      final maxScrollY = transform.maxPageTop;
      final nextX = (_scrollStartX - delta.dx).clamp(0.0, maxScrollX);
      final nextY = (_scrollStartY - delta.dy).clamp(0.0, maxScrollY);
      _scrollX = nextX;
      _scrollY = nextY;
      _updateCanvasView();
      final web = _web;
      if (web != null) {
        unawaited(web.runJavaScript('window.scrollTo($nextX, $nextY)'));
      }
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer == _drawingPointer) {
      _drawingPointer = null;
      if (_movingSelection) {
        _canvas.commitMoveStrokes(_selectionBefore);
        _resetSelectionMove();
      } else {
        _canvas.endStroke();
      }
    }
    if (event.pointer == _scrollPointer) {
      _scrollPointer = null;
      _scrollAnchor = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _drawingPointer) {
      _drawingPointer = null;
      if (_movingSelection) {
        _canvas.restoreStrokeSelection(_selectionBefore);
        _resetSelectionMove();
      } else {
        _canvas.cancelStroke();
      }
    }
    if (event.pointer == _scrollPointer) {
      _scrollPointer = null;
      _scrollAnchor = null;
    }
  }

  void _resetSelectionMove() {
    _movingSelection = false;
    _selectionStart = null;
    _selectionBefore = const [];
  }

  void _syncPresets() => _presets.syncFrom(_canvas);

  HtmlStrokeIndex get _currentStrokeIndex {
    final version = _canvas.renderContentNotifier.value;
    if (_strokeIndex == null || _strokeIndexVersion != version) {
      _strokeIndex = HtmlStrokeIndex(_canvas.page.strokes);
      _strokeIndexVersion = version;
    }
    return _strokeIndex!;
  }

  Future<void> _confirmExternalLink(Uri uri) async {
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.htmlOpenExternalTitle),
        content: Text(uri.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.htmlOpenExternalAction),
          ),
        ],
      ),
    );
    if (open == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _mathBakeWrite;
    await _canvas.flush();
    if (_remoteSyncPending) unawaited(_runRemoteSync());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _runRemoteSync() async {
    _remoteSyncTimer?.cancel();
    _remoteSyncTimer = null;
    if (!_remoteSyncPending) return;
    _remoteSyncPending = false;
    if (!_syncService.isSignedIn) return;
    try {
      final metas = await widget.storage.loadIndex();
      final meta = metas
          .where((candidate) => candidate.id == widget.notebookId)
          .firstOrNull;
      if (meta != null && !meta.isSyncEnabled) return;
      await _syncService.backupNote(
        _canvas.note,
        notebookId: widget.notebookId,
        notebookTitle: meta?.title,
      );
    } catch (error) {
      debugPrint('HtmlAnnotationScreen: automatic sync failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stylusShortcutSubscription?.cancel());
    unawaited(_stylusShortcuts.stop());
    _remoteSyncTimer?.cancel();
    _canvas.bottomBarContextNotifier.removeListener(_syncPresets);
    _presets.dispose();
    _canvas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _close,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.note.title),
          actions: [
            IconButton(
              tooltip: _readMode
                  ? context.l10n.htmlAnnotate
                  : context.l10n.htmlReadSelect,
              onPressed: () => setState(() => _readMode = !_readMode),
              icon: Icon(
                _readMode ? Icons.edit_outlined : Icons.pan_tool_outlined,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: _HtmlToolBar(
              canvas: _canvas,
              presets: _presets,
              readMode: _readMode,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    final web = _web;
    if (web == null) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        _viewportHeight = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _updateCanvasView(),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: web),
            RepaintBoundary(
              child: IgnorePointer(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _canvas.renderContentNotifier,
                    _canvas.viewportNotifier,
                  ]),
                  builder: (_, _) => CustomPaint(
                    painter: _HtmlCommittedInkPainter(
                      _canvas,
                      _currentStrokeIndex,
                    ),
                  ),
                ),
              ),
            ),
            if (!_readMode)
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _canvas.activeOverlayNotifier,
                        _canvas.viewportNotifier,
                      ]),
                      builder: (_, _) => CustomPaint(
                        painter: ActiveLayerPainter(controller: _canvas),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_ready)
              const IgnorePointer(
                child: ColoredBox(
                  color: Color(0x55FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!_readMode)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Center(child: _HtmlSelectionActions(canvas: _canvas)),
              ),
          ],
        );
      },
    );
  }
}

class _HtmlCommittedInkPainter extends CustomPainter {
  _HtmlCommittedInkPainter(this.canvas, this.index);

  final CanvasController canvas;
  final HtmlStrokeIndex index;

  @override
  void paint(Canvas target, Size size) {
    final scale = canvas.scale;
    final translate = canvas.translate;
    final visible = Rect.fromLTRB(
      -translate.dx / scale,
      -translate.dy / scale,
      (size.width - translate.dx) / scale,
      (size.height - translate.dy) / scale,
    );
    target
      ..save()
      ..translate(translate.dx, translate.dy)
      ..scale(scale)
      ..clipRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: canvas.sheetSize.width,
          height: canvas.sheetSize.height,
        ),
      );
    for (final stroke in index.visible(visible)) {
      final layer = stroke.layerIndex < canvas.page.layers.length
          ? canvas.page.layers[stroke.layerIndex]
          : null;
      if (layer != null && !layer.visible) continue;
      if (!stroke.paintBounds.overlaps(visible)) continue;
      if (layer != null && layer.opacity < 1) {
        target.saveLayer(
          stroke.paintBounds,
          Paint()..color = Colors.white.withValues(alpha: layer.opacity),
        );
        paintStroke(target, stroke);
        target.restore();
      } else {
        paintStroke(target, stroke);
      }
    }
    target.restore();
  }

  @override
  bool shouldRepaint(_HtmlCommittedInkPainter oldDelegate) => true;
}

class _HtmlToolBar extends StatelessWidget {
  const _HtmlToolBar({
    required this.canvas,
    required this.presets,
    required this.readMode,
  });

  static const _wideContentFactor = 0.95;
  static const _controlExtent = 48.0;

  final CanvasController canvas;
  final PenPresetsController presets;
  final bool readMode;

  @override
  Widget build(BuildContext context) => Material(
    color: context.inklus.toolbar,
    child: SizedBox(
      width: double.infinity,
      height: 52,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 600
              ? constraints.maxWidth * (1 - _wideContentFactor) / 2
              : 0.0;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                canvas,
                canvas.toolContextNotifier,
                canvas.bottomBarContextNotifier,
                canvas.renderContentNotifier,
                presets,
              ]),
              builder: (context, _) => LayoutBuilder(
                builder: (context, rowConstraints) => Row(
                  children: [
                    Expanded(child: _toolArea(context)),
                    _inlineControls(
                      context,
                      maxWidth: rowConstraints.maxWidth * 0.4,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _toolArea(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: context.l10n.tbUndo,
        onPressed: canvas.canUndo ? canvas.undo : null,
        icon: const Icon(Icons.undo),
      ),
      IconButton(
        tooltip: context.l10n.tbRedo,
        onPressed: canvas.canRedo ? canvas.redo : null,
        icon: const Icon(Icons.redo),
      ),
      const _HtmlToolbarDivider(),
      Expanded(
        child: SingleChildScrollView(
          key: const Key('html-tool-scroll'),
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _penTool(context),
              _highlighterTool(context),
              _optionTool(
                context,
                ToolType.eraser,
                (context) => EraserPopover(canvas: canvas),
              ),
              _optionTool(
                context,
                ToolType.lasso,
                (context) => LassoPopover(canvas: canvas),
              ),
              _plainTool(context, ToolType.select),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _inlineControls(BuildContext context, {required double maxWidth}) {
    final showsColors = canvas.isInkTool || canvas.tool == ToolType.highlighter;
    final showsSize = showsColors || canvas.tool == ToolType.eraser;
    if (!showsColors && !showsSize) return const SizedBox.shrink();
    final sizes = _quickSizes;
    final preferredWidth =
        _HtmlToolbarDivider.horizontalExtent +
        (showsColors ? presets.toolbarColors.length * _controlExtent : 0) +
        (showsColors && showsSize ? _HtmlToolbarDivider.horizontalExtent : 0) +
        (showsSize ? sizes.length * _controlExtent : 0);
    return SizedBox(
      width: preferredWidth.clamp(0.0, maxWidth),
      child: Row(
        children: [
          const _HtmlToolbarDivider(),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('html-inline-control-scroll'),
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showsColors)
                    for (
                      var index = 0;
                      index < presets.toolbarColors.length;
                      index++
                    )
                      _color(context, index),
                  if (showsColors && showsSize) const _HtmlToolbarDivider(),
                  if (showsSize)
                    for (final size in sizes)
                      _size(context, size, sizes: sizes),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<double> get _quickSizes {
    final (min, max) = canvas.sizeRange;
    final span = max - min;
    return [min + span * 0.12, min + span * 0.3, min + span * 0.6];
  }

  Widget _color(BuildContext context, int index) {
    final color = presets.toolbarColors[index];
    return Semantics(
      button: true,
      selected: index == presets.activeToolbarColorSlot,
      child: InkResponse(
        customBorder: const CircleBorder(),
        onTap: readMode
            ? null
            : () => presets.activateToolbarColor(index, canvas),
        child: SizedBox.square(
          dimension: _controlExtent,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: index == presets.activeToolbarColorSlot
                      ? context.colors.primary
                      : context.colors.outlineVariant,
                  width: index == presets.activeToolbarColorSlot ? 3 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _size(
    BuildContext context,
    double size, {
    required List<double> sizes,
  }) {
    var selectedSize = sizes.first;
    for (final candidate in sizes.skip(1)) {
      if ((canvas.toolSize - candidate).abs() <
          (canvas.toolSize - selectedSize).abs()) {
        selectedSize = candidate;
      }
    }
    final (min, max) = canvas.sizeRange;
    final fraction = max <= min ? 0.5 : (size - min) / (max - min);
    final diameter = 6 + 12 * fraction.clamp(0.0, 1.0);
    final selected = size == selectedSize;
    final color = canvas.tool == ToolType.eraser
        ? context.colors.outline
        : canvas.color;
    return Semantics(
      button: true,
      selected: selected,
      label: '${context.l10n.popSize}: ${size.toStringAsFixed(1)}',
      child: InkResponse(
        onTap: readMode
            ? null
            : () {
                canvas.setToolSize(size);
                presets.syncFrom(canvas);
              },
        child: SizedBox.square(
          dimension: _controlExtent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _penTool(BuildContext context) {
    final selected = canvas.isInkTool;
    final slot = presets.activeSlot == PenPresetsController.highlighterSlot
        ? 0
        : presets.activeSlot;
    final tool = selected ? canvas.tool : presets.presetAt(slot).tool;
    return Builder(
      builder: (anchor) => _toolButton(
        context,
        tool: tool,
        label: ToolVisuals.label(context, tool),
        selected: selected,
        glyphColor: selected ? canvas.color : presets.presetAt(slot).color,
        onTap: () {
          if (selected) {
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

  Widget _highlighterTool(BuildContext context) {
    final selected = canvas.tool == ToolType.highlighter;
    return Builder(
      builder: (anchor) => _toolButton(
        context,
        tool: ToolType.highlighter,
        label: ToolVisuals.label(context, ToolType.highlighter),
        selected: selected,
        glyphColor: selected ? canvas.color : presets.highlighter.color,
        onTap: () {
          if (selected) {
            showAnchoredPopover<void>(
              context: context,
              anchorContext: anchor,
              builder: (_) => PenPopover(canvas: canvas, presets: presets),
            );
          } else {
            presets.activate(PenPresetsController.highlighterSlot, canvas);
          }
        },
      ),
    );
  }

  Widget _optionTool(
    BuildContext context,
    ToolType tool,
    WidgetBuilder popover,
  ) {
    final selected = canvas.tool == tool;
    return Builder(
      builder: (anchor) => _toolButton(
        context,
        tool: tool,
        label: ToolVisuals.label(context, tool),
        selected: selected,
        onTap: () {
          if (selected) {
            showAnchoredPopover<void>(
              context: context,
              anchorContext: anchor,
              builder: popover,
            );
          } else {
            canvas.setTool(tool);
          }
        },
      ),
    );
  }

  Widget _plainTool(BuildContext context, ToolType tool) => _toolButton(
    context,
    tool: tool,
    label: ToolVisuals.label(context, tool),
    selected: canvas.tool == tool,
    onTap: () => canvas.setTool(tool),
  );

  Widget _toolButton(
    BuildContext context, {
    required ToolType tool,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? glyphColor,
  }) {
    final resolvedColor =
        glyphColor ??
        (selected
            ? context.colors.onPrimaryContainer
            : context.colors.onSurfaceVariant);
    return IconButton(
      tooltip: label,
      isSelected: selected,
      style: IconButton.styleFrom(
        backgroundColor: selected ? context.colors.primaryContainer : null,
      ),
      onPressed: readMode ? null : onTap,
      icon: ToolVisuals.buildIcon(tool, color: resolvedColor),
    );
  }
}

class _HtmlToolbarDivider extends StatelessWidget {
  const _HtmlToolbarDivider();

  static const horizontalExtent = 9.0;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: context.colors.outlineVariant,
  );
}

class _HtmlSelectionActions extends StatelessWidget {
  const _HtmlSelectionActions({required this.canvas});

  final CanvasController canvas;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: canvas,
    builder: (context, _) {
      if (!canvas.hasLassoSelection) return const SizedBox.shrink();
      return Material(
        elevation: 3,
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('${canvas.selectionCount}'),
            ),
            IconButton(
              tooltip: context.l10n.libDuplicate,
              onPressed: canvas.duplicateSelectedStrokes,
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              tooltip: context.l10n.libDelete,
              onPressed: canvas.deleteSelectedStrokes,
              icon: Icon(Icons.delete_outline, color: context.inklus.danger),
            ),
            IconButton(
              tooltip: context.l10n.selDeselect,
              onPressed: canvas.clearLassoSelection,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    },
  );
}
