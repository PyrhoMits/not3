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
import 'package:not3/ui/theme/app_theme.dart';
import 'package:not3/ui/theme/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late CanvasController canvas;
  late PenPresetsController presets;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('not3_editor_toolbar_');
    canvas = CanvasController(StorageService(baseDir: temp))
      ..setHapticEnabled(false);
    presets = PenPresetsController(persist: false);
  });

  tearDown(() {
    canvas.dispose();
    presets.dispose();
    temp.deleteSync(recursive: true);
  });

  Widget app({
    required bool collapsed,
    required ValueChanged<bool> setCollapsed,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
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
            onTemplates: () {},
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

  Future<void> pumpToolbar(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var collapsed = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => app(
          collapsed: collapsed,
          setCollapsed: (value) => setState(() => collapsed = value),
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

  testWidgets('selected pen still opens its options popover', (tester) async {
    await pumpToolbar(tester, width: 1280);

    expect(find.byTooltip('Advanced stroke settings'), findsNothing);
    await tester.tap(find.byTooltip('Ballpoint pen 1'));
    await tester.pumpAndSettle();

    expect(find.text('Pen type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('laser is a direct tool and updates its selected state', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 1280);

    await tester.tap(find.byTooltip('Laser pointer'));
    await tester.pump();

    expect(canvas.laserMode, isTrue);
    expect(find.byTooltip('Turn off laser pointer'), findsOneWidget);
    expect(find.byTooltip('Insert sticker'), findsOneWidget);
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
}
