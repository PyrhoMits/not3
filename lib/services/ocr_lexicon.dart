// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ocr_candidate.dart';

/// Optional lexicon used to rerank digital-ink model candidates.
///
/// ML Kit returns several possible readings with a score where lower is
/// better, but that score does not know whether the result is a real word.
/// For Thai, which does not use spaces between words, the algorithm finds the
/// segmentation that covers the most characters with known words.
///
/// Each language lexicon is loaded once. Languages without a registered
/// lexicon, such as English and Japanese, retain the model's ordering.
class OcrLexicon {
  OcrLexicon._(this.words, this.maxWordLength);

  /// Known words, normalized to lowercase.
  final Set<String> words;

  /// Length of the longest word, used to bound matching work.
  final int maxWordLength;

  static const Map<String, String> _assets = {
    'th': 'assets/ocr/thai_words.txt',
  };

  static final Map<String, OcrLexicon?> _cache = {};
  static final Map<String, Future<OcrLexicon?>> _loading = {};

  /// Prevents a large lexicon from loading twice concurrently.
  static Future<OcrLexicon?> load(String languageCode) {
    if (!_assets.containsKey(languageCode)) {
      return Future<OcrLexicon?>.value();
    }
    if (_cache.containsKey(languageCode)) {
      return Future.value(_cache[languageCode]);
    }
    return _loading.putIfAbsent(
      languageCode,
      () => _load(languageCode).then((lexicon) {
        _cache[languageCode] = lexicon;
        _loading.remove(languageCode);
        return lexicon;
      }),
    );
  }

  static Future<OcrLexicon?> _load(String languageCode) async {
    final asset = _assets[languageCode];
    if (asset == null) return null;
    try {
      final raw = await rootBundle.loadString(asset);
      final words = <String>{};
      var maxWordLength = 0;
      for (final line in raw.split('\n')) {
        if (line.trimLeft().startsWith('#')) continue;
        final word = _lettersOnly(line);
        // Single characters create false coverage for almost any text.
        if (word.length < 2) continue;
        words.add(word);
        if (word.length > maxWordLength) maxWordLength = word.length;
      }
      if (words.isEmpty) return null;
      return OcrLexicon._(words, maxWordLength);
    } catch (e) {
      // A missing language asset is not an error; reranking is simply skipped.
      // The Thai asset is bundled with the application.
      debugPrint('OcrLexicon.load($languageCode): $e');
      return null;
    }
  }

  /// Clears the cache between tests.
  @visibleForTesting
  static void resetCacheForTest() {
    _cache.clear();
    _loading.clear();
  }

  /// Creates a small test lexicon without loading assets.
  @visibleForTesting
  factory OcrLexicon.fromWordsForTest(Iterable<String> words) {
    final set = {
      for (final w in words)
        if (_lettersOnly(w).length >= 2) _lettersOnly(w),
    };
    final max = set.fold<int>(0, (m, w) => math.max(m, w.length));
    return OcrLexicon._(set, max);
  }

  /// Selects the candidate with the greatest lexicon coverage. The model score
  /// (lower is better) breaks ties between equal-coverage candidates.
  static OcrCandidate pickBest(
    List<OcrCandidate> candidates, {
    OcrLexicon? lexicon,
  }) {
    if (candidates.isEmpty) {
      throw ArgumentError.value(candidates, 'candidates', 'must not be empty');
    }
    if (candidates.length == 1 || lexicon == null) {
      return _lowestScore(candidates);
    }
    return lexicon.rank(candidates).first;
  }

  /// Returns every candidate ordered from best to worst.
  ///
  /// A reading that forms more real words wins, while the model score breaks
  /// ties. This avoids mixing two uncalibrated scales and retains alternatives
  /// for the UI.
  List<OcrCandidate> rank(List<OcrCandidate> candidates) {
    if (candidates.length <= 1) return [...candidates];
    final ranked = [...candidates];
    ranked.sort((a, b) {
      final byCoverage = coverage(b.text).compareTo(coverage(a.text));
      if (byCoverage != 0) return byCoverage;
      final scoreA = a.score.isFinite ? a.score : double.infinity;
      final scoreB = b.score.isFinite ? b.score : double.infinity;
      return scoreA.compareTo(scoreB);
    });
    return ranked;
  }

  static OcrCandidate _lowestScore(List<OcrCandidate> candidates) {
    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      final score = candidate.score.isFinite
          ? candidate.score
          : double.infinity;
      final bestScore = best.score.isFinite ? best.score : double.infinity;
      if (score < bestScore) best = candidate;
    }
    return best;
  }

  /// Fraction of text characters that belong to known words.
  ///
  /// Space-delimited text is scored by token. Thai text is scored with dynamic
  /// programming to find its best segmentation.
  double coverage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;

    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .map(_lettersOnly)
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return 0;

    var matched = 0;
    var total = 0;
    for (final token in tokens) {
      matched += _tokenMatchedCharacters(token);
      total += token.length;
    }
    return total == 0 ? 0 : matched / total;
  }

  int _tokenMatchedCharacters(String token) {
    if (words.contains(token)) return token.length;

    // Do not match single characters: nearly all appear in dictionaries and
    // would make meaningless readings look perfect.
    if (token.length < 2) return 0;

    final best = List<int>.filled(token.length + 1, 0);
    for (var i = token.length - 1; i >= 0; i--) {
      // Unknown characters may be skipped while matching continues.
      best[i] = best[i + 1];
      final max = math.min(maxWordLength, token.length - i);
      for (var length = 2; length <= max; length++) {
        if (words.contains(token.substring(i, i + length))) {
          best[i] = math.max(best[i], length + best[i + length]);
        }
      }
    }
    return best.first;
  }

  static String _lettersOnly(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true),
    '',
  );
}
