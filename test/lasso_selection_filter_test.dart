// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/canvas_controller.dart';
import 'package:not3/logic/lasso_selection_filter.dart';
import 'package:not3/models/image_item.dart';
import 'package:not3/models/stroke.dart';
import 'package:not3/models/text_item.dart';
import 'package:not3/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late CanvasController canvas;

  Future<CanvasController> createController() async {
    final controller = CanvasController(StorageService(baseDir: temp))
      ..setHapticEnabled(false)
      ..setShapeDetection(false);
    await controller.inputPreferencesLoaded;
    return controller;
  }

  void draw(ToolType tool, double y) {
    canvas.beginStroke(Offset(0, y), 0.5, tool: tool);
    canvas.addStrokePoint(Offset(100, y), 0.5);
    canvas.endStroke();
  }

  void addMixedContent() {
    draw(ToolType.pen, 0);
    draw(ToolType.highlighter, 40);
    canvas.addImage(
      ImageItem(
        id: 'image',
        localPath: '/tmp/lasso-filter.png',
        x: 50,
        y: 80,
        width: 30,
        height: 30,
      ),
    );
    canvas.page.textItems.add(
      TextItem(id: 'text', x: 50, y: 120, width: 80, text: 'Not3'),
    );
  }

  void lassoAll() {
    canvas.beginLasso(const Offset(-30, -30));
    for (final point in const [
      Offset(150, -30),
      Offset(150, 160),
      Offset(-30, 160),
    ]) {
      canvas.addLassoPoint(point);
    }
    canvas.endLasso();
  }

  void keepOnly(Set<LassoContentType> enabled) {
    for (final type in LassoContentType.values) {
      if (!enabled.contains(type)) {
        expect(canvas.setLassoContentEnabled(type, false), isTrue);
      }
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('not3_lasso_filter_');
    canvas = await createController();
    addMixedContent();
  });

  tearDown(() {
    canvas.dispose();
    temp.deleteSync(recursive: true);
  });

  test('all filters enabled preserves mixed selection', () {
    expect(canvas.lassoSelectionFilter, const LassoSelectionFilter.all());

    lassoAll();

    expect(canvas.selectionCount, 4);
    expect(canvas.selectedStrokes.map((stroke) => stroke.tool), {
      ToolType.pen,
      ToolType.highlighter,
    });
    expect(canvas.selectedImages.single.id, 'image');
    expect(canvas.selectedTexts.single.id, 'text');
  });

  test('handwriting-only excludes highlighter, text, and images', () {
    keepOnly({LassoContentType.handwriting});

    lassoAll();

    expect(canvas.selectionCount, 1);
    expect(canvas.selectedStrokes.single.tool, ToolType.pen);
    expect(canvas.selectedImages, isEmpty);
    expect(canvas.selectedTexts, isEmpty);
  });

  test('highlighter-only excludes handwriting underneath it', () {
    keepOnly({LassoContentType.highlighter});

    lassoAll();

    expect(canvas.selectionCount, 1);
    expect(canvas.selectedStrokes.single.tool, ToolType.highlighter);
  });

  test('text-only and image-only select their matching item', () {
    keepOnly({LassoContentType.text});
    lassoAll();
    expect(canvas.selectionCount, 1);
    expect(canvas.selectedTexts.single.id, 'text');

    canvas.clearLassoSelection();
    expect(
      canvas.setLassoContentEnabled(LassoContentType.images, true),
      isTrue,
    );
    expect(canvas.setLassoContentEnabled(LassoContentType.text, false), isTrue);
    lassoAll();
    expect(canvas.selectionCount, 1);
    expect(canvas.selectedImages.single.id, 'image');
  });

  test('combined filters select their union', () {
    keepOnly({LassoContentType.handwriting, LassoContentType.images});

    lassoAll();

    expect(canvas.selectionCount, 2);
    expect(canvas.selectedStrokes.single.tool, ToolType.pen);
    expect(canvas.selectedImages.single.id, 'image');
  });

  test('hidden and locked layers remain excluded', () {
    canvas.toggleLayerLocked(0);
    lassoAll();
    expect(canvas.selectionCount, 0);

    canvas.toggleLayerLocked(0);
    canvas.toggleLayerVisibility(0);
    lassoAll();
    expect(canvas.selectionCount, 0);
  });

  test('at least one content type must stay enabled', () {
    keepOnly({LassoContentType.images});

    expect(
      canvas.setLassoContentEnabled(LassoContentType.images, false),
      isFalse,
    );
    expect(canvas.lassoSelectionFilter.images, isTrue);
    expect(canvas.lassoSelectionFilter.enabledCount, 1);
  });

  test(
    'filter persists and invalid preferences fall back to all enabled',
    () async {
      keepOnly({LassoContentType.highlighter, LassoContentType.text});
      await Future<void>.delayed(Duration.zero);
      canvas.dispose();
      canvas = await createController();
      expect(
        canvas.lassoSelectionFilter,
        const LassoSelectionFilter(
          handwriting: false,
          highlighter: true,
          text: true,
          images: false,
        ),
      );

      canvas.dispose();
      SharedPreferences.setMockInitialValues({
        'lasso_selection_filter_v1': '{invalid',
      });
      canvas = await createController();
      expect(canvas.lassoSelectionFilter, const LassoSelectionFilter.all());
    },
  );

  test('delete and undo operate only on filtered selection', () {
    keepOnly({LassoContentType.handwriting});
    lassoAll();
    final selectedBounds = canvas.selectionBoundsAll;
    expect(selectedBounds, isNot(Rect.zero));

    canvas.copySelectedStrokes();
    canvas.deleteSelectedStrokes();
    expect(canvas.page.strokes.single.tool, ToolType.highlighter);
    expect(canvas.page.images.single.id, 'image');
    expect(canvas.page.textItems.single.id, 'text');

    canvas.undo();
    expect(canvas.page.strokes.length, 2);
    expect(canvas.page.images.single.id, 'image');
    expect(canvas.page.textItems.single.id, 'text');
  });
}
