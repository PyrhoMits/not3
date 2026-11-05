// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/logic/pen_presets.dart';
import 'package:not3/models/stroke.dart';
import 'package:not3/services/storage_service.dart';
import 'package:not3/ui/editor/editor_toolbar.dart';
import 'package:not3/ui/editor/tool_popovers.dart';
import 'package:not3/ui/editor/tool_visuals.dart';
import 'package:not3/ui/theme/app_theme.dart';
import 'package:not3/ui/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late CanvasController canvas;
  late PenPresetsController presets;
  late int templateOpenCount;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('not3_editor_toolbar_');
    canvas = CanvasController(StorageService(baseDir: temp))
      ..setHapticEnabled(false);
    presets = PenPresetsController(persist: false);
    templateOpenCount = 0;
  });

  tearDown(() {
    canvas.dispose();
    presets.dispose();
    temp.deleteSync(recursive: true);
  });

  Widget app({
    required bool collapsed,
    required ValueChanged<bool> setCollapsed,
    bool dark = false,
  }) {
    return MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: EditorToolbar(
            canvas: canvas,
            presets: presets,
            onBack: () {},
            onEditTitle: () {},
            onInsertImage: () {},
            onTemplates: () => templateOpenCount++,
            onInsertSticker: () {},
            pagesOpen: false,
            onTogglePages: () {},
            layersOpen: false,
            onToggleLayers: () {},
            toolsCollapsed: collapsed,
            onToggleTools: () => setCollapsed(!collapsed),
            trailing: const [
              IconButton(
                tooltip: 'Sync',
                onPressed: null,
                icon: Icon(Icons.cloud_outlined),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: null,
                icon: Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pumpToolbar(
    WidgetTester tester, {
    required double width,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var collapsed = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => app(
          collapsed: collapsed,
          setCollapsed: (value) => setState(() => collapsed = value),
          dark: dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses two rows without overflow at reference width', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 857);

    expect(find.byTooltip('Pages'), findsOneWidget);
    expect(find.byTooltip('Layers'), findsOneWidget);
    expect(find.byTooltip('Move / select images and strokes'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.byTooltip('Laser pointer'), findsOneWidget);
    expect(find.byTooltip('Insert sticker'), findsOneWidget);
    expect(find.byTooltip('Fill area'), findsOneWidget);
    expect(find.byTooltip('Zoom writing'), findsOneWidget);
    expect(find.byTooltip('Page template'), findsOneWidget);
    expect(find.byTooltip('More tools'), findsNothing);
    expect(find.byTooltip('Hide drawing tools'), findsOneWidget);
    expect(find.byTooltip('Advanced stroke settings'), findsNothing);
    expect(tester.takeException(), isNull);

    final size = tester.getSize(find.byType(EditorToolbar));
    expect(size.height, Sizes.editorDocumentBar + Sizes.editorToolBar + 1);

    final expectedInset = 857 * 0.025;
    expect(
      tester.getTopLeft(find.byTooltip('Back to library')).dx,
      closeTo(expectedInset, 0.1),
    );
    expect(
      tester.getTopLeft(find.byTooltip('Undo')).dx,
      closeTo(expectedInset, 0.1),
    );
  });

  testWidgets('keeps essential document actions on a narrow phone', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 360);

    expect(find.byTooltip('Back to library'), findsOneWidget);
    expect(find.byTooltip('Pages'), findsOneWidget);
    expect(find.byTooltip('Layers'), findsOneWidget);
    expect(find.byTooltip('Page template'), findsOneWidget);
    expect(find.byTooltip('Move / select images and strokes'), findsOneWidget);
    expect(find.byTooltip('Sync'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Hide drawing tools'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byTooltip('Back to library')).dx,
      closeTo(0, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses only the drawing row', (tester) async {
    await pumpToolbar(tester, width: 857);

    await tester.tap(find.byTooltip('Hide drawing tools'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show drawing tools'), findsOneWidget);
    expect(find.byTooltip('Pages'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsNothing);
    expect(
      tester.getSize(find.byType(EditorToolbar)).height,
      Sizes.editorDocumentBar,
    );
  });

  testWidgets('quick controls update the active preset', (tester) async {
    await pumpToolbar(tester, width: 1280);
    final before = canvas.color;

    final colorButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label?.startsWith('Color ') == true,
    );
    expect(colorButtons, findsWidgets);

    final different = colorButtons
        .evaluate()
        .map((e) => e.widget)
        .whereType<Semantics>();
    expect(different.length, greaterThan(1));
    await tester.tap(colorButtons.at(1));
    await tester.pump();

    expect(canvas.color, isNot(before));
    expect(presets.presetAt(presets.activeSlot).color, canvas.color);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pen glyph follows its color and keeps selected background', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);
    final pen = find.byTooltip('Ballpoint pen 1');

    Icon penIcon() => tester.widget<Icon>(
      find.descendant(of: pen, matching: find.byIcon(Icons.edit)),
    );
    expect(penIcon().color, presets.presetAt(0).color);

    final selectedContainer = tester.widget<AnimatedContainer>(
      find.descendant(of: pen, matching: find.byType(AnimatedContainer)),
    );
    final decoration = selectedContainer.decoration! as BoxDecoration;
    final scheme = Theme.of(tester.element(pen)).colorScheme;
    expect(decoration.color, scheme.primaryContainer);

    final colorButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label?.startsWith('Color ') == true,
    );
    await tester.tap(colorButtons.at(2));
    await tester.pump();

    expect(penIcon().color, canvas.color);
    expect(canvas.color, presets.presetAt(0).color);
  });

  testWidgets('highlighter uses the dedicated highlighter icon', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);

    final highlighter = find.byTooltip('Highlighter');
    expect(
      find.descendant(
        of: highlighter,
        matching: find.byIcon(Icons.border_color),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: highlighter,
              matching: find.byIcon(Icons.border_color),
            ),
          )
          .color,
      presets.highlighter.color,
    );
  });

  testWidgets('eraser glyph matches the standard tool icon size', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);

    final eraserPaint = find.descendant(
      of: find.byTooltip('Eraser'),
      matching: find.byType(CustomPaint),
    );
    expect(eraserPaint, findsOneWidget);
    expect(tester.getSize(eraserPaint), const Size.square(Sizes.toolIcon));
  });

  testWidgets('eraser options no longer offer automatic tool reversion', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);

    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    expect(canvas.tool, ToolType.eraser);

    await tester.tap(find.byTooltip('Eraser'));
    await tester.pumpAndSettle();

    expect(
      find.text('Return to the previous tool after erasing'),
      findsNothing,
    );
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Stroke'), findsOneWidget);
    expect(find.text('Highlighter'), findsOneWidget);
  });

  testWidgets('selected pen still opens its options popover', (tester) async {
    await pumpToolbar(tester, width: 1280);

    expect(find.byTooltip('Advanced stroke settings'), findsNothing);
    await tester.tap(find.byTooltip('Ballpoint pen 1'));
    await tester.pumpAndSettle();

    expect(find.text('Pen type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('laser activates directly and a second tap opens settings', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);

    await tester.tap(find.byTooltip('Laser pointer'));
    await tester.pump();

    expect(canvas.laserMode, isTrue);
    expect(find.byTooltip('Laser pointer on'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip('Laser pointer on'),
        matching: find.byType(LaserPointerGlyph),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.flashlight_on), findsNothing);
    expect(find.byIcon(Icons.flashlight_off), findsNothing);

    await tester.tap(find.byTooltip('Laser pointer on'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('laser-enabled')), findsNothing);
    expect(find.text('Display mode'), findsOneWidget);
    expect(find.text('Lines'), findsOneWidget);
    expect(find.text('Dot'), findsOneWidget);
    expect(find.byKey(const Key('laser-thickness')), findsOneWidget);
    expect(find.byKey(const Key('laser-duration')), findsOneWidget);

    await tester.tap(find.text('Dot'));
    await tester.pump();
    expect(canvas.laserPointerMode, LaserPointerMode.dot);

    await tester.tapAt(const Offset(1200, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    expect(canvas.laserMode, isFalse);
    expect(canvas.tool, ToolType.eraser);
    expect(find.byTooltip('Insert sticker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('laser settings update independently in a compact dark popover', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 360, dark: true);
    await tester.ensureVisible(find.byTooltip('Laser pointer'));
    await tester.tap(find.byTooltip('Laser pointer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Laser pointer on'));
    await tester.pumpAndSettle();

    final inkColor = canvas.color;
    final swatches = find.descendant(
      of: find.byType(LaserPopover),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label?.startsWith('Color ') == true,
      ),
    );
    expect(swatches, findsNWidgets(6));
    await tester.tap(swatches.at(1));
    await tester.pump();
    expect(canvas.laserColor, isNot(CanvasController.defaultLaserColor));
    expect(canvas.color, inkColor);

    tester.widget<Slider>(find.byKey(const Key('laser-thickness'))).onChanged!(
      14,
    );
    tester.widget<Slider>(find.byKey(const Key('laser-duration'))).onChanged!(
      1500,
    );
    await tester.pump();
    expect(canvas.laserThickness, 14);
    expect(canvas.laserDuration, const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('former overflow items are direct toolbar tools', (tester) async {
    await pumpToolbar(tester, width: 1280);

    expect(find.byTooltip('More tools'), findsNothing);
    await tester.tap(find.byTooltip('Fill area'));
    await tester.pump();
    expect(canvas.tool, ToolType.bucket);

    await tester.tap(find.byTooltip('Zoom writing'));
    await tester.pump();
    expect(canvas.magnifierEnabled, isTrue);
    expect(find.byTooltip('Close zoom writing'), findsOneWidget);
    expect(find.byTooltip('Page template'), findsOneWidget);
    await tester.tap(find.byTooltip('Page template'));
    expect(templateOpenCount, 1);
    final templateTop = tester.getTopLeft(find.byTooltip('Page template')).dy;
    final pagesTop = tester.getTopLeft(find.byTooltip('Pages')).dy;
    final laserTop = tester.getTopLeft(find.byTooltip('Laser pointer')).dy;
    expect(templateTop, pagesTop);
    expect(templateTop, lessThan(laserTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('move and select is a direct document-row tool', (tester) async {
    await pumpToolbar(tester, width: 857);

    await tester.tap(find.byTooltip('Move / select images and strokes'));
    await tester.pump();

    expect(canvas.tool, ToolType.select);
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Move / select images and strokes',
      ),
    );
    expect(semantics.properties.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps all tools left and controls fixed on the right', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 857);

    final colorButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label?.startsWith('Color ') == true,
    );
    final sizeButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label?.startsWith('Size: ') == true,
    );
    final colorBefore = tester.getRect(colorButtons.first);
    final sizeBefore = tester.getRect(sizeButtons.first);
    final penBefore = tester.getRect(find.byTooltip('Ballpoint pen 1'));
    final toolBefore = tester.getRect(find.byTooltip('Lasso'));
    expect(penBefore.left, lessThan(toolBefore.left));

    await tester.drag(
      find.byKey(const Key('editor-tool-scroll')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(colorButtons.first), colorBefore);
    expect(tester.getRect(sizeButtons.first), sizeBefore);
    expect(
      tester.getRect(find.byTooltip('Ballpoint pen 1')).left,
      lessThan(penBefore.left),
    );
    expect(
      tester.getRect(find.byTooltip('Lasso')).left,
      lessThan(toolBefore.left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reserves at least 60 percent for tools in portrait', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 800);

    final tools = tester.getRect(find.byKey(const Key('editor-tool-area')));
    final controls = tester.getRect(
      find.byKey(const Key('editor-inline-controls')),
    );
    final usableWidth = tools.width + controls.width;
    expect(tools.width / usableWidth, greaterThanOrEqualTo(0.6));

    final colorButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label?.startsWith('Color ') == true,
    );
    final sizeButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label?.startsWith('Size: ') == true,
    );
    expect(colorButtons, findsNWidgets(PenPresetsController.toolbarColorCount));
    expect(sizeButtons, findsNWidgets(3));
    expect(find.byTooltip('Lasso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls color and size controls independently in portrait', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 800);

    final controlScroll = find.byKey(const Key('editor-inline-control-scroll'));
    final toolArea = find.byKey(const Key('editor-tool-area'));
    final colorButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label?.startsWith('Color ') == true,
    );
    final sizeButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label?.startsWith('Size: ') == true,
    );
    final firstColorBefore = tester.getRect(colorButtons.first);
    final lastSizeBefore = tester.getRect(sizeButtons.last);
    final toolAreaBefore = tester.getRect(toolArea);
    final viewport = tester.getRect(controlScroll);
    expect(lastSizeBefore.right, greaterThan(viewport.right));

    await tester.drag(controlScroll, const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(colorButtons.first).left,
      lessThan(firstColorBefore.left),
    );
    expect(
      tester.getRect(sizeButtons.last).left,
      lessThan(lastSizeBefore.left),
    );
    expect(tester.getRect(toolArea), toolAreaBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-aligns the complete tool group when it fits', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 2048);

    final first = tester.getRect(find.byTooltip('Ballpoint pen 1'));
    final viewport = tester.getRect(
      find.byKey(const Key('editor-tool-scroll')),
    );

    expect(first.left, closeTo(viewport.left, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lasso hides ink controls without moving the left tool group', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);

    final inline = find.byKey(const Key('editor-inline-controls'));
    final firstToolBefore = tester.getRect(find.byTooltip('Ballpoint pen 1'));
    expect(tester.getSize(inline).width, greaterThan(0));
    await tester.tap(find.byTooltip('Lasso'));
    await tester.pump();

    expect(canvas.tool, ToolType.lasso);
    expect(tester.getSize(inline), Size.zero);
    expect(tester.getRect(find.byTooltip('Ballpoint pen 1')), firstToolBefore);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith('Color ') == true,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('second lasso tap opens accessible content filters', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 800);

    await tester.tap(find.byTooltip('Lasso'));
    await tester.pump();
    await tester.tap(find.byTooltip('Lasso'));
    await tester.pumpAndSettle();

    expect(find.text('Select content'), findsOneWidget);
    expect(find.byKey(const Key('lasso-filter-handwriting')), findsOneWidget);
    expect(find.byKey(const Key('lasso-filter-highlighter')), findsOneWidget);
    expect(find.byKey(const Key('lasso-filter-text')), findsOneWidget);
    expect(find.byKey(const Key('lasso-filter-images')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lasso-filter-images')));
    await tester.pump();
    expect(canvas.lassoSelectionFilter.images, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last lasso filter remains enabled on a narrow phone', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 360);

    await tester.ensureVisible(find.byTooltip('Lasso'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lasso'));
    await tester.pump();
    await tester.tap(find.byTooltip('Lasso'));
    await tester.pumpAndSettle();
    for (final key in const [
      Key('lasso-filter-highlighter'),
      Key('lasso-filter-text'),
      Key('lasso-filter-images'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }

    final handwriting = tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(const Key('lasso-filter-handwriting')),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(canvas.lassoSelectionFilter.enabledCount, 1);
    expect(canvas.lassoSelectionFilter.handwriting, isTrue);
    expect(handwriting.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
}
