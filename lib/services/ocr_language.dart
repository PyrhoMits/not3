// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A language available for handwriting OCR.
///
/// [code] is the BCP-47 code expected by ML Kit Digital Ink. [script] is used
/// by the bitmap fallback (`google_mlkit_text_recognition`); it is `null` when
/// ML Kit does not provide that script, such as for Thai.
class OcrLanguage {
  const OcrLanguage({
    required this.code,
    required this.label,
    required this.script,
  });

  final String code;
  final String label;
  final TextRecognitionScript? script;

  bool get hasBitmapFallback => script != null;
}

/// Languages supported by the app's OCR feature.
///
/// Only English, Japanese, and Thai are offered.
const List<OcrLanguage> supportedOcrLanguages = [
  OcrLanguage(
    code: 'en',
    label: 'English',
    script: TextRecognitionScript.latin,
  ),
  OcrLanguage(
    code: 'ja',
    label: '日本語 (Japanese)',
    script: TextRecognitionScript.japanese,
  ),
  OcrLanguage(
    code: 'th',
    label: 'ไทย (Thai)',
    // ML Kit Text Recognition does not support Thai, so the digital-ink model
    // is the only recognition path for this language.
    script: null,
  ),
];

/// Returns the language matching [code], or `null` when it is unsupported.
OcrLanguage? ocrLanguageByCode(String? code) {
  if (code == null) return null;
  for (final language in supportedOcrLanguages) {
    if (language.code == code) return language;
  }
  return null;
}

/// Selects the default OCR language from the system locale.
///
/// Thai and Japanese devices use their respective language; all other locales
/// default to English.
OcrLanguage defaultOcrLanguageForLocale(Locale? locale) {
  return switch (locale?.languageCode.toLowerCase()) {
    'th' => supportedOcrLanguages[2],
    'ja' => supportedOcrLanguages[1],
    _ => supportedOcrLanguages[0],
  };
}

/// Persists the most recently selected OCR language.
class OcrLanguageStore {
  const OcrLanguageStore._();

  static const String _prefKey = 'ocr_ink_language';

  /// Returns the saved language, or the system default if none is valid.
  static Future<OcrLanguage> load() async {
    final fallback = defaultOcrLanguageForLocale(
      PlatformDispatcher.instance.locale,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      return ocrLanguageByCode(prefs.getString(_prefKey)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> save(OcrLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (_) {
      // OCR remains usable for this session when persistence is unavailable.
    }
  }
}
