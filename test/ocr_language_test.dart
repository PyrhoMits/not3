// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:inklus/services/ocr_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('supportedOcrLanguages', () {
    test('solo ofrece inglés, japonés y tailandés', () {
      expect(
        supportedOcrLanguages.map((l) => l.code).toList(),
        ['en', 'ja', 'th'],
      );
    });

    test('mapea cada idioma a su script de fallback', () {
      expect(ocrLanguageByCode('en')!.script, TextRecognitionScript.latin);
      expect(ocrLanguageByCode('ja')!.script, TextRecognitionScript.japanese);
      expect(ocrLanguageByCode('th')!.script, isNull);
      expect(ocrLanguageByCode('th')!.hasBitmapFallback, isFalse);
    });

    test('devuelve null para códigos no soportados', () {
      expect(ocrLanguageByCode('es'), isNull);
      expect(ocrLanguageByCode('zh-Hani'), isNull);
      expect(ocrLanguageByCode(null), isNull);
    });
  });

  group('defaultOcrLanguageForLocale', () {
    test('usa tailandés y japonés cuando el sistema los usa', () {
      expect(defaultOcrLanguageForLocale(const Locale('th')).code, 'th');
      expect(defaultOcrLanguageForLocale(const Locale('th', 'TH')).code, 'th');
      expect(defaultOcrLanguageForLocale(const Locale('ja')).code, 'ja');
      expect(defaultOcrLanguageForLocale(const Locale('ja', 'JP')).code, 'ja');
    });

    test('cae en inglés para el resto', () {
      expect(defaultOcrLanguageForLocale(const Locale('en', 'US')).code, 'en');
      expect(defaultOcrLanguageForLocale(const Locale('es')).code, 'en');
      expect(defaultOcrLanguageForLocale(const Locale('fr')).code, 'en');
      expect(defaultOcrLanguageForLocale(null).code, 'en');
    });
  });

  group('OcrLanguageStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('guarda y recupera el último idioma', () async {
      await OcrLanguageStore.save(ocrLanguageByCode('ja')!);
      expect((await OcrLanguageStore.load()).code, 'ja');
    });

    test('ignora un código guardado que ya no se soporta', () async {
      SharedPreferences.setMockInitialValues({'ocr_ink_language': 'es'});
      final loaded = await OcrLanguageStore.load();
      expect(loaded.code, isNot('es'));
      expect(
        supportedOcrLanguages.map((l) => l.code),
        contains(loaded.code),
      );
    });
  });
}
