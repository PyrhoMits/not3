// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklus/models/stroke.dart';
import 'package:inklus/services/ocr_lexicon.dart';
import 'package:inklus/services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const inkChannel = MethodChannel('google_mlkit_digital_ink_recognizer');
  const textChannel = MethodChannel('google_mlkit_text_recognizer');

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> inkCalls;
  late List<MethodCall> textCalls;
  late bool modelDownloaded;
  late bool downloadSucceeds;
  late String recognizedText;
  late List<List<Map<String, dynamic>>> queuedResponses;

  final stroke = Stroke(
    id: 's1',
    points: const [StrokePoint(10, 20, 0.5), StrokePoint(30, 40, 0.5)],
    tool: ToolType.pen,
    colorValue: 0xFF000000,
    size: 2,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    OcrService.resetInkModelCacheForTest();
    OcrLexicon.resetCacheForTest();
    SharedPreferences.setMockInitialValues({});
    inkCalls = [];
    textCalls = [];
    modelDownloaded = false;
    downloadSucceeds = false;
    recognizedText = 'สวัสดี';
    queuedResponses = [];

    messenger.setMockMethodCallHandler(inkChannel, (call) async {
      inkCalls.add(call);
      switch (call.method) {
        case 'vision#manageInkModels':
          final args = call.arguments as Map<dynamic, dynamic>;
          if (args['task'] == 'check') return modelDownloaded;
          if (args['task'] == 'download') {
            if (!downloadSucceeds) return false;
            modelDownloaded = true;
            return 'success';
          }
          return null;
        case 'vision#startDigitalInkRecognizer':
          if (queuedResponses.isNotEmpty) {
            return queuedResponses.removeAt(0);
          }
          return <Map<String, dynamic>>[
            {'text': recognizedText, 'score': -1.0},
          ];
        case 'vision#closeDigitalInkRecognizer':
          return null;
      }
      return null;
    });

    messenger.setMockMethodCallHandler(textChannel, (call) async {
      textCalls.add(call);
      return <String, dynamic>{'text': '', 'blocks': <dynamic>[]};
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(inkChannel, null);
    messenger.setMockMethodCallHandler(textChannel, null);
  });

  Iterable<MethodCall> callsTo(String method) =>
      inkCalls.where((call) => call.method == method);

  test('Thai without a model fails instead of using Latin OCR', () async {
    await expectLater(
      () => OcrService.recognizeStrokes(
        [stroke],
        sheetSize: const ui.Size(100, 100),
        languageCode: 'th',
      ),
      throwsA(
        isA<OcrModelUnavailableError>().having(
          (e) => e.language.code,
          'language',
          'th',
        ),
      ),
    );

    // The model download was attempted over Wi-Fi.
    final download = callsTo('vision#manageInkModels')
        .map((call) => call.arguments as Map<dynamic, dynamic>)
        .singleWhere((args) => args['task'] == 'download');
    expect(download['model'], 'th');
    expect(download['wifi'], isTrue);

    // Bitmap OCR, which would use the Latin script, was never called.
    expect(callsTo('vision#startDigitalInkRecognizer'), isEmpty);
    expect(textCalls, isEmpty);
  });

  test('uses the Thai digital-ink model and returns its text', () async {
    downloadSucceeds = true;

    final result = await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'th',
    );

    expect(result.text, 'สวัสดี');
    expect(result.isEmpty, isFalse);
    expect(result.blocks, hasLength(1));
    // Bounds are estimated from the points plus stroke thickness.
    expect(result.blocks.single.x, 8);
    expect(result.blocks.single.y, 18);
    expect(result.blocks.single.width, 24);
    expect(result.blocks.single.height, 24);

    final start = callsTo('vision#startDigitalInkRecognizer').single;
    expect((start.arguments as Map<dynamic, dynamic>)['model'], 'th');
    expect(textCalls, isEmpty);
  });

  test(
    'does not hang when Android never replies while closing ML Kit',
    () async {
      modelDownloaded = true;
      final neverCompletes = Completer<void>();
      messenger.setMockMethodCallHandler(inkChannel, (call) async {
        inkCalls.add(call);
        switch (call.method) {
          case 'vision#manageInkModels':
            return true;
          case 'vision#startDigitalInkRecognizer':
            return <Map<String, dynamic>>[
              {'text': 'done', 'score': -1.0},
            ];
          case 'vision#closeDigitalInkRecognizer':
            await neverCompletes.future;
            return null;
        }
        return null;
      });

      final result = await OcrService.recognizeStrokes(
        [stroke],
        sheetSize: const ui.Size(100, 100),
        languageCode: 'en',
      ).timeout(const Duration(milliseconds: 250));

      expect(result.text, 'done');
      expect(callsTo('vision#closeDigitalInkRecognizer'), hasLength(1));
    },
  );

  test('passes the selected BCP-47 code to the digital-ink model', () async {
    modelDownloaded = true;

    await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'ja',
    );

    final start = callsTo('vision#startDigitalInkRecognizer').single;
    expect((start.arguments as Map<dynamic, dynamic>)['model'], 'ja');
  });

  test('an unknown code defaults to English', () async {
    modelDownloaded = true;

    await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'xx',
    );

    final start = callsTo('vision#startDigitalInkRecognizer').single;
    expect((start.arguments as Map<dynamic, dynamic>)['model'], 'en');
  });

  test('does not check the model when no strokes exist', () async {
    final result = await OcrService.recognizeStrokes(
      const [],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'th',
    );

    expect(result.isEmpty, isTrue);
    expect(inkCalls, isEmpty);
    expect(textCalls, isEmpty);
  });

  test('downloadedModelCodes includes only available models', () async {
    messenger.setMockMethodCallHandler(inkChannel, (call) async {
      inkCalls.add(call);
      if (call.method != 'vision#manageInkModels') return null;
      final args = call.arguments as Map<dynamic, dynamic>;
      if (args['task'] != 'check') return null;
      return args['model'] == 'en';
    });

    expect(await OcrService.downloadedModelCodes(), {'en'});
  });

  test('uses all candidates and selects the lowest score', () async {
    modelDownloaded = true;
    queuedResponses.add([
      {'text': 'wrong', 'score': 0.5},
      {'text': 'best', 'score': -2.0},
      {'text': 'middle', 'score': 0.0},
    ]);

    final result = await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'en',
    );

    expect(result.text, 'best');
    expect(result.candidates.map((candidate) => candidate.text), [
      'best',
      'middle',
      'wrong',
    ]);
  });

  test('recognizes one line per call and passes preContext', () async {
    modelDownloaded = true;
    queuedResponses.addAll([
      [
        {'text': 'first line', 'score': -1.0},
      ],
      [
        {'text': 'second line', 'score': -1.0},
      ],
    ]);

    Stroke line(double top) => Stroke(
      id: 'line-$top',
      points: [
        StrokePoint(10, top, 0.5, 0),
        StrokePoint(40, top, 0.5, 10),
        StrokePoint(40, top + 20, 0.5, 20),
      ],
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 1,
    );

    final result = await OcrService.recognizeStrokes(
      [line(10), line(100)],
      sheetSize: const ui.Size(200, 200),
      languageCode: 'en',
    );

    expect(result.text, 'first line\nsecond line');
    expect(result.blocks, hasLength(2));
    expect(result.lines, hasLength(2));
    expect(result.lines.first.strokes, hasLength(1));
    expect(result.lines.last.strokes, hasLength(1));

    final starts = callsTo('vision#startDigitalInkRecognizer').toList();
    expect(starts, hasLength(2));
    final firstContext =
        (starts[0].arguments as Map<dynamic, dynamic>)['context']
            as Map<dynamic, dynamic>;
    final secondContext =
        (starts[1].arguments as Map<dynamic, dynamic>)['context']
            as Map<dynamic, dynamic>;
    expect(firstContext['preContext'], isNull);
    expect(secondContext['preContext'], 'first line');
  });

  test('normalizes a compact selection in both dimensions', () async {
    modelDownloaded = true;
    final highOnPage = Stroke(
      id: 'high-on-page',
      points: const [
        StrokePoint(100, 800, 0.5, 0),
        StrokePoint(140, 840, 0.5, 20),
      ],
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 2,
    );

    await OcrService.recognizeStrokes(
      [highOnPage],
      sheetSize: const ui.Size(1200, 1700),
      languageCode: 'th',
      segmentLines: false,
    );

    final args =
        callsTo('vision#startDigitalInkRecognizer').single.arguments
            as Map<dynamic, dynamic>;
    final context = args['context'] as Map<dynamic, dynamic>;
    final area = context['writingArea'] as Map<dynamic, dynamic>;
    expect(area['width'] as double, lessThan(200));
    expect(area['height'] as double, lessThan(100));

    final ink = args['ink'] as Map<dynamic, dynamic>;
    final sentStroke = (ink['strokes'] as List).single as Map<dynamic, dynamic>;
    final sentPoints = sentStroke['points'] as List;
    expect(
      sentPoints.map((point) => (point as Map<dynamic, dynamic>)['y']),
      everyElement(inInclusiveRange(0, area['height'] as double)),
    );
    expect(
      sentPoints.map((point) => (point as Map<dynamic, dynamic>)['x']),
      everyElement(inInclusiveRange(0, area['width'] as double)),
    );
  });

  test('sends real point timing and synthesizes legacy timing', () async {
    modelDownloaded = true;
    final timed = Stroke(
      id: 'timed',
      points: const [
        StrokePoint(0, 0, 0.5, 0),
        StrokePoint(1, 0, 0.5, 16),
        StrokePoint(2, 0, 0.5, 33),
      ],
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 1,
    );
    final legacy = Stroke(
      id: 'legacy',
      points: const [StrokePoint(0, 10, 0.5), StrokePoint(1, 10, 0.5)],
      tool: ToolType.pen,
      colorValue: 0xFF000000,
      size: 1,
    );

    await OcrService.recognizeStrokes(
      [timed, legacy],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'en',
      segmentLines: false,
    );

    final args =
        callsTo('vision#startDigitalInkRecognizer').single.arguments
            as Map<dynamic, dynamic>;
    final strokes = ((args['ink'] as Map<dynamic, dynamic>)['strokes'] as List)
        .cast<Map<dynamic, dynamic>>();
    expect(strokes, hasLength(2));
    int timeOf(Map<dynamic, dynamic> stroke, int index) =>
        ((stroke['points'] as List)[index] as Map<dynamic, dynamic>)['t']
            as int;
    expect([for (var i = 0; i < 3; i++) timeOf(strokes[0], i)], [0, 16, 33]);
    // The legacy stroke starts 50 ms after the last real timestamp.
    expect([for (var i = 0; i < 2; i++) timeOf(strokes[1], i)], [83, 84]);
  });

  test('applies learned corrections before returning text', () async {
    modelDownloaded = true;
    SharedPreferences.setMockInitialValues({
      'ocr_corrections_v1': jsonEncode({
        'en': {'wrong': 'right'},
      }),
    });
    queuedResponses.add([
      {'text': 'wrong', 'score': -1.0},
    ]);

    final result = await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'en',
    );

    expect(result.text, 'right');
    expect(result.candidates.single.text, 'right');
  });
}
