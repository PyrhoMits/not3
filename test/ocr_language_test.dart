// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:not3/services/ocr_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('supportedOcrLanguages', () {
    test('offers only English, Japanese, and Thai', () {
      expect(supportedOcrLanguages.map((l) => l.code).toList(), [
        'en',
        'ja',
        'th',
      ]);
    });

    test('maps each language to its fallback script', () {
      expect(ocrLanguageByCode('en')!.script, TextRecognitionScript.latin);
      expect(ocrLanguageByCode('ja')!.script, TextRecognitionScript.japanese);
      expect(ocrLanguageByCode('th')!.script, isNull);
      expect(ocrLanguageByCode('th')!.hasBitmapFallback, isFalse);
    });

    test('returns null for unsupported codes', () {
      expect(ocrLanguageByCode('es'), isNull);
      expect(ocrLanguageByCode('zh-Hani'), isNull);
      expect(ocrLanguageByCode(null), isNull);
    });
  });

  group('defaultOcrLanguageForLocale', () {
    test('uses Thai and Japanese for matching system locales', () {
      expect(defaultOcrLanguageForLocale(const Locale('th')).code, 'th');
      expect(defaultOcrLanguageForLocale(const Locale('th', 'TH')).code, 'th');
      expect(defaultOcrLanguageForLocale(const Locale('ja')).code, 'ja');
      expect(defaultOcrLanguageForLocale(const Locale('ja', 'JP')).code, 'ja');
    });

    test('defaults to English for all other locales', () {
      expect(defaultOcrLanguageForLocale(const Locale('en', 'US')).code, 'en');
      expect(defaultOcrLanguageForLocale(const Locale('es')).code, 'en');
      expect(defaultOcrLanguageForLocale(const Locale('fr')).code, 'en');
      expect(defaultOcrLanguageForLocale(null).code, 'en');
    });
  });

  group('OcrLanguageStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves and restores the most recent language', () async {
      await OcrLanguageStore.save(ocrLanguageByCode('ja')!);
      expect((await OcrLanguageStore.load()).code, 'ja');
    });

    test('ignores a saved code that is no longer supported', () async {
      SharedPreferences.setMockInitialValues({'ocr_ink_language': 'es'});
      final loaded = await OcrLanguageStore.load();
      expect(loaded.code, isNot('es'));
      expect(supportedOcrLanguages.map((l) => l.code), contains(loaded.code));
    });
  });
}
