// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklus/models/stroke.dart';
import 'package:inklus/services/ocr_service.dart';

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
    inkCalls = [];
    textCalls = [];
    modelDownloaded = false;
    downloadSucceeds = false;
    recognizedText = 'สวัสดี';

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

  test('thai sin modelo falla en vez de usar OCR latino', () async {
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

    // Se intentó descargar el modelo (con Wi-Fi)…
    final download = callsTo('vision#manageInkModels')
        .map((call) => call.arguments as Map<dynamic, dynamic>)
        .singleWhere((args) => args['task'] == 'download');
    expect(download['model'], 'th');
    expect(download['wifi'], isTrue);

    // …y nunca se llamó al OCR por bitmap (que usaría el script latino).
    expect(callsTo('vision#startDigitalInkRecognizer'), isEmpty);
    expect(textCalls, isEmpty);
  });

  test('usa el modelo de tinta tailandés y devuelve su texto', () async {
    downloadSucceeds = true;

    final result = await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'th',
    );

    expect(result.text, 'สวัสดี');
    expect(result.isEmpty, isFalse);
    expect(result.blocks, hasLength(1));
    // Bounding box estimado a partir de los puntos (± grosor del trazo).
    expect(result.blocks.single.x, 8);
    expect(result.blocks.single.y, 18);
    expect(result.blocks.single.width, 24);
    expect(result.blocks.single.height, 24);

    final start = callsTo('vision#startDigitalInkRecognizer').single;
    expect((start.arguments as Map<dynamic, dynamic>)['model'], 'th');
    expect(textCalls, isEmpty);
  });

  test('pasa el código BCP-47 elegido al modelo de tinta', () async {
    modelDownloaded = true;

    await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'ja',
    );

    final start = callsTo('vision#startDigitalInkRecognizer').single;
    expect((start.arguments as Map<dynamic, dynamic>)['model'], 'ja');
  });

  test('un código desconocido cae en inglés', () async {
    modelDownloaded = true;

    await OcrService.recognizeStrokes(
      [stroke],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'xx',
    );

    final start = callsTo('vision#startDigitalInkRecognizer').single;
    expect((start.arguments as Map<dynamic, dynamic>)['model'], 'en');
  });

  test('no consulta el modelo si no hay trazos', () async {
    final result = await OcrService.recognizeStrokes(
      const [],
      sheetSize: const ui.Size(100, 100),
      languageCode: 'th',
    );

    expect(result.isEmpty, isTrue);
    expect(inkCalls, isEmpty);
    expect(textCalls, isEmpty);
  });

  test('downloadedModelCodes solo incluye modelos presentes', () async {
    messenger.setMockMethodCallHandler(inkChannel, (call) async {
      inkCalls.add(call);
      if (call.method != 'vision#manageInkModels') return null;
      final args = call.arguments as Map<dynamic, dynamic>;
      if (args['task'] != 'check') return null;
      return args['model'] == 'en';
    });

    expect(await OcrService.downloadedModelCodes(), {'en'});
  });
}
