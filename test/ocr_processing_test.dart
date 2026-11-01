// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklus/models/stroke.dart';
import 'package:inklus/services/ocr_correction_store.dart';
import 'package:inklus/services/ocr_lexicon.dart';
import 'package:inklus/services/ocr_lines.dart';
import 'package:inklus/services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Stroke stroke(String id, Rect bounds, {int index = 0}) {
    return Stroke(
      id: id,
      points: [
        StrokePoint(bounds.left, bounds.top, 0.5, index * 10),
        StrokePoint(bounds.right, bounds.center.dy, 0.5, index * 10 + 5),
        StrokePoint(bounds.right, bounds.bottom, 0.5, index * 10 + 9),
      ],
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 1,
    );
  }

  group('StrokePoint', () {
    test('time is serialized and restored', () {
      const point = StrokePoint(1, 2, 0.3, 16);
      expect(point.toJson()['t'], 16);
      expect(StrokePoint.fromJson(point.toJson()).t, 16);
    });

    test('legacy strokes without time still load', () {
      final json = <String, dynamic>{'x': 1.0, 'y': 2.0, 'p': 0.4};
      expect(StrokePoint.fromJson(json).t, isNull);
      expect(const StrokePoint(1, 2, 0.5).toJson().containsKey('t'), isFalse);
    });

    test('translating a stroke preserves its timing', () {
      final s = stroke('s', const Rect.fromLTWH(0, 0, 10, 10), index: 2);
      final moved = s.translated(const Offset(5, 5));
      expect(moved.points.map((p) => p.t), s.points.map((p) => p.t));
    });
  });

  group('segmentStrokesIntoLines', () {
    test('separates lines and returns them from top to bottom', () {
      final first = stroke('a', const Rect.fromLTWH(0, 0, 10, 10));
      final firstMore = stroke('b', const Rect.fromLTWH(20, 0, 10, 10));
      final second = stroke('c', const Rect.fromLTWH(0, 100, 10, 10));

      final lines = segmentStrokesIntoLines([first, second, firstMore]);

      expect(lines, hasLength(2));
      expect(lines.first.map((s) => s.id), ['a', 'b']);
      expect(lines.last.map((s) => s.id), ['c']);
    });

    test('separates columns divided by a very large horizontal gap', () {
      final left = stroke('left', const Rect.fromLTWH(0, 0, 10, 10));
      final right = stroke('right', const Rect.fromLTWH(500, 0, 10, 10));

      final lines = segmentStrokesIntoLines([left, right]);

      expect(lines, hasLength(2));
      expect(lines.first.single.id, 'left');
      expect(lines.last.single.id, 'right');
    });

    test(
      'discards empty strokes and exposes the same helper in OcrService',
      () {
        final empty = Stroke(
          id: 'empty',
          points: const [],
          tool: ToolType.pen,
          colorValue: 0xFF000000,
          size: 1,
        );
        final valid = stroke('valid', const Rect.fromLTWH(0, 0, 10, 10));
        expect(segmentStrokesIntoLines([empty, valid]), hasLength(1));
        expect(OcrService.segmentIntoLines([empty, valid]), hasLength(1));
      },
    );
  });

  group('OcrLexicon', () {
    setUp(OcrLexicon.resetCacheForTest);

    test('loads the bundled Thai dictionary', () async {
      final lexicon = await OcrLexicon.load('th');
      expect(lexicon, isNotNull);
      expect(lexicon!.coverage('สวัสดี'), 1);
      expect(await OcrLexicon.load('en'), isNull);
    });

    test('scores Thai word coverage', () {
      final lexicon = OcrLexicon.fromWordsForTest(['สวัสดี', 'ครับ']);
      expect(lexicon.coverage('สวัสดี'), 1);
      expect(lexicon.coverage('สวัสดีครับ'), 1);
      expect(lexicon.coverage('xyz'), 0);
    });

    test('prefers the reading that forms real words', () {
      final lexicon = OcrLexicon.fromWordsForTest(['สวัสดี', 'ครับ']);
      final ranked = lexicon.rank([
        const OcrCandidate(text: 'สวัสดีx', score: -10),
        const OcrCandidate(text: 'สวัสดี', score: 0),
      ]);

      expect(ranked.first.text, 'สวัสดี');
      expect(
        OcrLexicon.pickBest([
          const OcrCandidate(text: 'สวัสดีx', score: -10),
          const OcrCandidate(text: 'สวัสดี', score: 0),
        ], lexicon: lexicon).text,
        'สวัสดี',
      );
    });

    test('finds the best segmentation instead of only the longest word', () {
      final lexicon = OcrLexicon.fromWordsForTest(['abc', 'ab', 'cde']);
      expect(lexicon.coverage('abcde'), 1);
    });
  });

  group('OcrCorrectionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('extracts and applies a word change', () {
      final mappings = OcrCorrectionStore.extractMappings(
        'I have a cat',
        'I have a dog',
      );
      expect(mappings, containsPair('cat', 'dog'));
      expect(
        OcrCorrectionStore.apply('I have a cat', mappings),
        'I have a dog',
      );
    });

    test('learns and restores corrections per language', () async {
      await OcrCorrectionStore.record(
        languageCode: 'en',
        recognized: 'I have a cat',
        corrected: 'I have a dog',
      );
      expect(await OcrCorrectionStore.load('en'), containsPair('cat', 'dog'));
    });

    test('does not learn very large rewrites', () {
      final long = List.filled(100, 'a').join();
      expect(
        OcrCorrectionStore.extractMappings(long, List.filled(100, 'b').join()),
        isEmpty,
      );
    });
  });
}
