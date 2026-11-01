// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idioma disponible para el OCR de escritura a mano.
///
/// [code] es el código BCP-47 que espera ML Kit Digital Ink. [script] es el
/// script que usa el fallback por bitmap (`google_mlkit_text_recognition`);
/// es `null` cuando ML Kit no ofrece ese script (p. ej. tailandés).
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

/// Idiomas soportados por el OCR de la app.
///
/// Solo se ofrecen los que el usuario pidió: inglés, japonés y tailandés.
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
    // ML Kit Text Recognition no soporta tailandés: el modelo de tinta es
    // la única vía para este idioma.
    script: null,
  ),
];

/// Devuelve el idioma con [code] o `null` si no está soportado.
OcrLanguage? ocrLanguageByCode(String? code) {
  if (code == null) return null;
  for (final language in supportedOcrLanguages) {
    if (language.code == code) return language;
  }
  return null;
}

/// Idioma por defecto según el idioma del sistema.
///
/// Si el dispositivo usa tailandés o japonés se elige ese idioma; para
/// cualquier otro (incluido español) se usa inglés.
OcrLanguage defaultOcrLanguageForLocale(Locale? locale) {
  return switch (locale?.languageCode.toLowerCase()) {
    'th' => supportedOcrLanguages[2],
    'ja' => supportedOcrLanguages[1],
    _ => supportedOcrLanguages[0],
  };
}

/// Persistencia del último idioma elegido para OCR.
class OcrLanguageStore {
  const OcrLanguageStore._();

  static const String _prefKey = 'ocr_ink_language';

  /// Último idioma guardado, o el del sistema si no hay uno válido.
  static Future<OcrLanguage> load() async {
    final fallback =
        defaultOcrLanguageForLocale(PlatformDispatcher.instance.locale);
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
      // Sin persistencia: el OCR sigue funcionando en esta sesión.
    }
  }
}
