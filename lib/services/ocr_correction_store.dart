// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of user OCR corrections.
///
/// When the user edits recognized text, the `(wrong → right)` pair is stored
/// per language in `SharedPreferences`. Future recognition applies these
/// substitutions before ranking candidates, allowing the system to learn
/// locally without sending data off the device.
class OcrCorrectionStore {
  const OcrCorrectionStore._();

  static const String _prefKey = 'ocr_corrections_v1';

  /// Prevents the preferences file from growing without bound.
  static const int maxEntriesPerLanguage = 400;

  /// Loads corrections for [languageCode].
  static Future<Map<String, String>> load(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decodeAll(prefs.getString(_prefKey));
      final language = all[languageCode];
      if (language is! Map) return const {};
      return {
        for (final entry in language.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (e) {
      debugPrint('OcrCorrectionStore.load: $e');
      return const {};
    }
  }

  /// Stores the differences between [recognized] and [corrected].
  static Future<void> record({
    required String languageCode,
    required String recognized,
    required String corrected,
  }) async {
    if (recognized == corrected) return;
    final mappings = extractMappings(recognized, corrected);
    if (mappings.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decodeAll(prefs.getString(_prefKey));
      final current = all[languageCode];
      final language = <String, String>{
        if (current is Map)
          for (final entry in current.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      };
      for (final entry in mappings.entries) {
        // Reinsert at the end so recent corrections survive map trimming.
        language.remove(entry.key);
        language[entry.key] = entry.value;
      }
      while (language.length > maxEntriesPerLanguage) {
        language.remove(language.keys.first);
      }
      all[languageCode] = language;
      await prefs.setString(_prefKey, jsonEncode(all));
    } catch (e) {
      debugPrint('OcrCorrectionStore.record: $e');
    }
  }

  /// Applies known corrections to [text].
  static String apply(String text, Map<String, String> corrections) {
    if (text.isEmpty || corrections.isEmpty) return text;
    // Apply longer substitutions first so a specific correction wins over a
    // correction that is only its substring.
    final wrongValues = corrections.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    var result = text;
    for (final wrong in wrongValues) {
      final right = corrections[wrong];
      if (wrong.isEmpty || right == null || right.isEmpty) continue;
      result = result.replaceAll(wrong, right);
    }
    return result;
  }

  /// Extracts wrong→right pairs from an edit.
  ///
  /// Lines are compared independently, trimming their common prefix and
  /// suffix. A one-word edit therefore does not store the entire sentence.
  /// Substitutions longer than [maxMappingLength] are discarded to avoid
  /// learning full rewrites.
  @visibleForTesting
  static Map<String, String> extractMappings(
    String before,
    String after, {
    int maxMappingLength = 80,
  }) {
    final mappings = <String, String>{};
    if (before == after) return mappings;

    final beforeLines = before.split('\n');
    final afterLines = after.split('\n');
    if (beforeLines.length == afterLines.length) {
      for (var i = 0; i < beforeLines.length; i++) {
        _diffLine(beforeLines[i], afterLines[i], mappings, maxMappingLength);
      }
    } else {
      _diffLine(before, after, mappings, maxMappingLength);
    }
    return mappings;
  }

  static void _diffLine(
    String before,
    String after,
    Map<String, String> out,
    int maxMappingLength,
  ) {
    if (before == after) return;

    var prefix = 0;
    final maxPrefix = before.length < after.length
        ? before.length
        : after.length;
    while (prefix < maxPrefix &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < before.length - prefix &&
        suffix < after.length - prefix &&
        before.codeUnitAt(before.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }

    var start = prefix;
    var endBefore = before.length - suffix;
    var endAfter = after.length - suffix;

    // For a pure insertion, include the previous character as an anchor so an
    // empty-string substitution is never learned.
    if (start == endBefore && start == endAfter) return;
    if (start == endBefore && start > 0) start--;
    if (start == endAfter && start > 0) {
      start--;
      endBefore = (endBefore + 1).clamp(0, before.length);
    }

    final wrong = before.substring(start, endBefore).trim();
    final right = after.substring(start, endAfter).trim();
    if (wrong.isEmpty || right.isEmpty || wrong == right) return;
    if (wrong.length > maxMappingLength || right.length > maxMappingLength) {
      return;
    }
    out[wrong] = right;
  }

  static Map<String, dynamic> _decodeAll(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Deletes saved corrections for tests and reset actions.
  @visibleForTesting
  static Future<void> clearForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
