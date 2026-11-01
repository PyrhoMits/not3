// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as ink;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../models/page.dart';
import '../models/stroke.dart';
import 'export_service.dart';
import 'image_service.dart';
import 'ocr_candidate.dart';
import 'ocr_correction_store.dart';
import 'ocr_language.dart';
import 'ocr_lexicon.dart';
import 'ocr_lines.dart';

export 'ocr_candidate.dart';

/// Text-recognition result for a page.
class OcrResult {
  /// Full recognized text, with lines joined by newline characters.
  final String text;

  /// Recognized text blocks with approximate image-coordinate bounds.
  final List<OcrBlock> blocks;

  /// All model candidates, best first. Multi-line results concatenate the
  /// candidates from each line.
  final List<OcrCandidate> candidates;

  /// Per-line results with their source strokes, allowing the UI to retry one
  /// line without recognizing the entire page again.
  final List<OcrLine> lines;

  const OcrResult({
    required this.text,
    required this.blocks,
    this.candidates = const [],
    this.lines = const [],
  });

  factory OcrResult.fromLines(List<OcrLine> lines) {
    final visible = lines.where((line) => line.text.trim().isNotEmpty).toList();
    return OcrResult(
      text: visible.map((line) => line.text).join('\n'),
      blocks: [for (final line in visible) line.block],
      candidates: [for (final line in visible) ...line.candidates],
      lines: List<OcrLine>.unmodifiable(visible),
    );
  }

  bool get isEmpty => text.isEmpty;
}

/// A recognized line with the data needed to retry it.
class OcrLine {
  final String text;
  final OcrBlock block;
  final List<Stroke> strokes;
  final List<OcrCandidate> candidates;

  const OcrLine({
    required this.text,
    required this.block,
    required this.strokes,
    this.candidates = const [],
  });

  bool get isEmpty => text.isEmpty;
}

/// A recognized text block with its approximate position.
class OcrBlock {
  final String text;
  final double x; // izquierda (px)
  final double y; // Top edge in pixels.
  final double width;
  final double height;

  const OcrBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// The selected language requires a digital-ink model and has no bitmap
/// fallback, or the model download failed.
class OcrModelUnavailableError implements Exception {
  const OcrModelUnavailableError(this.language);

  final OcrLanguage language;

  @override
  String toString() => 'OCR model unavailable for ${language.code}';
}

/// On-device OCR service for Android and iOS.
///
/// **Primary strategy**: `google_mlkit_digital_ink_recognition` processes
/// vector strokes directly, without rendering a bitmap. This improves
/// accuracy and allows recognition from individual strokes.
///
/// **Accuracy improvements** (see `docs/OCR_IMPROVEMENT.md`):
/// - real point timing (`StrokePoint.t`) instead of a synthetic sequence;
/// - line segmentation with one model call per line;
/// - `preContext` from the end of the previous line;
/// - all candidates ranked by score and lexicon coverage;
/// - locally learned user corrections.
///
/// **Fallback**: when strokes are unavailable or ink recognition fails,
/// `google_mlkit_text_recognition` processes a rendered bitmap. Thai has no
/// bitmap fallback because ML Kit does not support it.
class OcrService {
  const OcrService._();

  /// Maximum previous-line context passed to the model.
  static const int _preContextChars = 32;

  /// Plataformas soportadas (Android/iOS).
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // -------------------------------------------------------------------------
  // Digital-ink model download and cache
  // -------------------------------------------------------------------------

  /// Language models available on the device or downloaded this session.
  static final Set<String> _downloadedModels = {};

  /// Clears the downloaded-model cache between tests.
  @visibleForTesting
  static void resetInkModelCacheForTest() => _downloadedModels.clear();

  /// Checks whether the [languageCode] model is already downloaded.
  static Future<bool> isInkModelDownloaded(String languageCode) async {
    if (!isSupported) return false;
    if (_downloadedModels.contains(languageCode)) return true;
    try {
      final manager = ink.DigitalInkRecognizerModelManager();
      final downloaded = await manager.isModelDownloaded(languageCode);
      if (downloaded) _downloadedModels.add(languageCode);
      return downloaded;
    } catch (e) {
      debugPrint('OcrService.isInkModelDownloaded: $e');
      return false;
    }
  }

  /// Language codes for models already available on the device.
  static Future<Set<String>> downloadedModelCodes() async {
    if (!isSupported) return const <String>{};
    final result = <String>{};
    for (final language in supportedOcrLanguages) {
      if (await isInkModelDownloaded(language.code)) {
        result.add(language.code);
      }
    }
    return result;
  }

  /// Checks for the digital-ink model and downloads it when necessary.
  ///
  /// Call before `recognizeStrokes()` to ensure the model is available. A
  /// failed download returns false so the caller can use the bitmap fallback.
  static Future<bool> ensureInkModel(String languageCode) async {
    if (!isSupported) return false;
    if (_downloadedModels.contains(languageCode)) return true;
    try {
      final manager = ink.DigitalInkRecognizerModelManager();
      final downloaded = await manager.isModelDownloaded(languageCode);
      if (!downloaded) {
        final ok = await manager.downloadModel(languageCode);
        if (ok) _downloadedModels.add(languageCode);
        return ok;
      }
      _downloadedModels.add(languageCode);
      return true;
    } catch (e) {
      debugPrint('OcrService.ensureInkModel: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Primary method: vector digital-ink recognition
  // -------------------------------------------------------------------------

  /// Recognizes text directly from vector strokes.
  ///
  /// [strokes] contains page strokes in world coordinates. They are grouped
  /// into lines before calling the model because the model is designed for a
  /// line rather than a complete page.
  ///
  /// [preContext] is known text immediately before these strokes and is used
  /// for the first line. Later lines automatically receive the previous line.
  ///
  /// When [segmentLines] is false, all [strokes] are recognized as one line,
  /// which is useful when the UI retries a specific line.
  ///
  /// Returns recognized text with positioned blocks.
  static Future<OcrResult> recognizeStrokes(
    List<Stroke> strokes, {
    required ui.Size sheetSize,
    required String languageCode,
    String? preContext,
    bool segmentLines = true,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('OCR is only available on Android and iOS.');
    }

    final usable = strokes.where((stroke) => stroke.points.isNotEmpty).toList();
    if (usable.isEmpty) return const OcrResult(text: '', blocks: []);

    final language =
        ocrLanguageByCode(languageCode) ?? supportedOcrLanguages.first;

    // Ensure the digital-ink model is downloaded.
    final modelReady = await ensureInkModel(language.code);
    if (!modelReady) {
      // Render a bitmap for text recognition as a fallback. ML Kit has no Thai
      // bitmap script, so Thai cannot be recognized without its ink model.
      final script = language.script;
      if (script == null) throw OcrModelUnavailableError(language);
      return _recognizeFallback(usable, sheetSize: sheetSize, script: script);
    }

    final lines = segmentLines
        ? segmentStrokesIntoLines(usable)
        : <List<Stroke>>[usable];
    if (lines.isEmpty) return const OcrResult(text: '', blocks: []);

    // Local post-processing: learned corrections and the Thai lexicon.
    final corrections = await OcrCorrectionStore.load(language.code);
    final lexicon = await OcrLexicon.load(language.code);

    // Reuse one recognizer for all lines because creation is expensive.
    final recognizer = ink.DigitalInkRecognizer(languageCode: language.code);
    final recognized = <OcrLine>[];
    Object? lastError;

    try {
      var context = _cleanPreContext(preContext);
      for (final line in lines) {
        try {
          final result = await _recognizeLine(
            recognizer,
            line,
            sheetSize: sheetSize,
            corrections: corrections,
            lexicon: lexicon,
            preContext: context,
            compactWritingArea: !segmentLines,
          );
          if (result.isEmpty) continue;
          recognized.add(result);
          // Pass the end of this line as context for the next one.
          context = _cleanPreContext(result.text);
        } catch (e) {
          // An unreadable line must not discard the rest of the page.
          lastError = e;
          debugPrint('OcrService.recognizeStrokes (line): $e');
        }
      }
    } finally {
      // Version 0.16.1 closes the native Android recognizer but never replies
      // to this method-channel call. Dispatch cleanup without awaiting that
      // missing reply, otherwise successful OCR leaves the spinner open.
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(recognizer.close());
      } else {
        await recognizer.close();
      }
    }

    if (recognized.isEmpty) {
      if (lastError != null) throw lastError;
      return const OcrResult(text: '', blocks: []);
    }
    return OcrResult.fromLines(recognized);
  }

  /// Recognizes an entire page using vector ink.
  ///
  /// Convenience method that extracts strokes from a complete [Page].
  static Future<OcrResult> recognizePageInk(
    Page page, {
    required ui.Size sheetSize,
    required String languageCode,
    String? preContext,
  }) async {
    return recognizeStrokes(
      _inkStrokesOf(page),
      sheetSize: sheetSize,
      languageCode: languageCode,
      preContext: preContext,
    );
  }

  // -------------------------------------------------------------------------
  // Legacy bitmap-recognition fallback
  // -------------------------------------------------------------------------

  /// Recognizes text from a page rendered as an image.
  ///
  /// Used when the ink model is unavailable, printed text must be recognized,
  /// or the page contains images with text.
  static Future<OcrResult> recognizeText(
    Page page, {
    required ui.Size sheetSize,
    required Map<String, ui.Image> imageCache,
    ImageService? imageService,
    TextRecognitionScript script = TextRecognitionScript.latin,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('OCR is only available on Android and iOS.');
    }

    // Render the page to a temporary PNG.
    final pngBytes = await ExportService.renderPagePng(
      page,
      sheetSize: sheetSize,
      imageCache: imageCache,
      options: const ExportOptions(maxDimension: kOcrResolution),
    );

    // Save the image to a temporary file.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/inklus_ocr_temp.png');
    await file.writeAsBytes(pngBytes);

    // Run ML Kit bitmap text recognition.
    final inputImage = InputImage.fromFilePath(file.path);
    final textRecognizer = TextRecognizer(script: script);

    try {
      final recognized = await textRecognizer.processImage(inputImage);

      // Convert ML Kit blocks to the app model.
      final blocks = <OcrBlock>[];
      for (final block in recognized.blocks) {
        blocks.add(
          OcrBlock(
            text: block.text,
            x: block.boundingBox.left.toDouble(),
            y: block.boundingBox.top.toDouble(),
            width: block.boundingBox.width.toDouble(),
            height: block.boundingBox.height.toDouble(),
          ),
        );
      }

      return OcrResult(text: recognized.text, blocks: blocks);
    } finally {
      await textRecognizer.close();
      // Remove the temporary file.
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // -------------------------------------------------------------------------
  // Unified method that chooses the best strategy
  // -------------------------------------------------------------------------

  /// Recognizes page text using the best available strategy.
  ///
  /// Vector-ink recognition is attempted first because it is more accurate for
  /// handwriting. Missing strokes or failures fall back to bitmap OCR.
  static Future<OcrResult> recognizeSmart(
    Page page, {
    required ui.Size sheetSize,
    required Map<String, ui.Image> imageCache,
    ImageService? imageService,
    required String languageCode,
  }) async {
    final language =
        ocrLanguageByCode(languageCode) ?? supportedOcrLanguages.first;

    // Keep handwriting strokes and remove erasers and special tools.
    final inkStrokes = _inkStrokesOf(page);

    // Try digital-ink recognition when vector strokes are available.
    if (inkStrokes.isNotEmpty) {
      try {
        final inkResult = await recognizeStrokes(
          inkStrokes,
          sheetSize: sheetSize,
          languageCode: language.code,
        );
        // Use the ink result when it contains text.
        if (!inkResult.isEmpty) return inkResult;
        // No ink result and no bitmap fallback means recognition is finished.
        if (language.script == null) return inkResult;
      } on OcrModelUnavailableError {
        rethrow;
      } catch (e) {
        debugPrint('OcrService.recognizeSmart (ink): $e');
        if (language.script == null) {
          throw OcrModelUnavailableError(language);
        }
        // Continue with the fallback.
      }
    }

    final script = language.script;
    if (script == null) {
      return const OcrResult(text: '', blocks: []);
    }

    // Bitmap fallback also captures printed text and embedded images.
    return recognizeText(
      page,
      sheetSize: sheetSize,
      imageCache: imageCache,
      imageService: imageService,
      script: script,
    );
  }

  /// Strokes included in OCR, excluding erasers and special tools.
  static List<Stroke> _inkStrokesOf(Page page) => page.strokes
      .where(
        (s) =>
            s.tool != ToolType.eraser &&
            s.tool != ToolType.select &&
            s.tool != ToolType.lasso &&
            s.tool != ToolType.bucket &&
            s.tool != ToolType.text,
      )
      .toList();

  // -------------------------------------------------------------------------
  // Recognition helpers
  // -------------------------------------------------------------------------

  /// Recognizes one line and returns its ranked candidates.
  static Future<OcrLine> _recognizeLine(
    ink.DigitalInkRecognizer recognizer,
    List<Stroke> strokes, {
    required ui.Size sheetSize,
    required Map<String, String> corrections,
    OcrLexicon? lexicon,
    String? preContext,
    required bool compactWritingArea,
  }) async {
    final bounds = _estimateTextBounds(strokes);

    // ML Kit interprets stroke size relative to the writing area. Passing the
    // full page height makes a normal handwritten line look punctuation-sized
    // and is especially harmful for Thai. Keep the page width, but translate
    // Y into a padded line-local area as recommended for single-line input.
    final verticalPadding = math.max(bounds.height * 0.35, 4.0);
    final horizontalPadding = math.max(bounds.height * 0.5, 4.0);
    final originX = compactWritingArea
        ? bounds.left - horizontalPadding
        : (bounds.left < 0 ? bounds.left - 4 : 0.0);
    final origin = ui.Offset(originX, bounds.top - verticalPadding);
    final writingWidth = compactWritingArea
        ? math.max(bounds.width + horizontalPadding * 2, 1.0)
        : math.max(sheetSize.width - origin.dx, bounds.right - origin.dx + 4);
    final writingHeight = math.max(bounds.height + verticalPadding * 2, 1.0);

    final inkStrokes = _convertToInkStrokes(strokes, origin: origin);
    if (inkStrokes.isEmpty) {
      return const OcrLine(
        text: '',
        block: OcrBlock(text: '', x: 0, y: 0, width: 0, height: 0),
        strokes: [],
      );
    }
    final inkData = ink.Ink()..strokes = inkStrokes;

    // ML Kit normalizes against the sheet-sized writing area. The end of the
    // previous line supplies language context.
    final context = ink.DigitalInkRecognitionContext(
      preContext: preContext,
      writingArea: ink.WritingArea(width: writingWidth, height: writingHeight),
    );

    final rawCandidates = await recognizer.recognize(inkData, context: context);
    if (rawCandidates.isEmpty) {
      return const OcrLine(
        text: '',
        block: OcrBlock(text: '', x: 0, y: 0, width: 0, height: 0),
        strokes: [],
      );
    }

    // Apply user corrections and deduplicate candidates that become equal.
    final seen = <String>{};
    final candidates = <OcrCandidate>[];
    for (final raw in rawCandidates) {
      final corrected = OcrCorrectionStore.apply(raw.text, corrections).trim();
      if (corrected.isEmpty || !seen.add(corrected)) continue;
      candidates.add(OcrCandidate(text: corrected, score: raw.score));
    }
    if (candidates.isEmpty) {
      return const OcrLine(
        text: '',
        block: OcrBlock(text: '', x: 0, y: 0, width: 0, height: 0),
        strokes: [],
      );
    }

    final ranked = lexicon == null
        ? _rankByModelScore(candidates)
        : lexicon.rank(candidates);
    final best = ranked.first;

    // Digital Ink returns only complete text, so estimate its position from
    // the points belonging to this line.
    return OcrLine(
      text: best.text,
      block: OcrBlock(
        text: best.text,
        x: bounds.left,
        y: bounds.top,
        width: bounds.width,
        height: bounds.height,
      ),
      strokes: List<Stroke>.unmodifiable(strokes),
      candidates: List<OcrCandidate>.unmodifiable(ranked),
    );
  }

  /// Ranks candidates only by model score when no lexicon is available.
  static List<OcrCandidate> _rankByModelScore(List<OcrCandidate> candidates) {
    if (candidates.length <= 1) return candidates;
    final sorted = [...candidates];
    sorted.sort(
      (a, b) => _sortableScore(a.score).compareTo(_sortableScore(b.score)),
    );
    return sorted;
  }

  static double _sortableScore(double score) =>
      score.isNaN ? double.infinity : score;

  /// Normalizes previous text to a single line before passing it to the model.
  static String? _cleanPreContext(String? text) {
    if (text == null) return null;
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return null;
    if (clean.length <= _preContextChars) return clean;
    return clean.substring(clean.length - _preContextChars);
  }

  // -------------------------------------------------------------------------
  // Conversion helpers
  // -------------------------------------------------------------------------

  /// Converts app [Stroke] objects to ML Kit `ink.Stroke` objects.
  ///
  /// Uses real timing (`StrokePoint.t`, milliseconds from stroke start) when
  /// available. Legacy strokes synthesize one millisecond per point, with a
  /// 50-millisecond gap between strokes.
  static List<ink.Stroke> _convertToInkStrokes(
    List<Stroke> strokes, {
    ui.Offset origin = ui.Offset.zero,
  }) {
    final result = <ink.Stroke>[];
    var baseTime = 0; // Monotonically increasing time across strokes.

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final inkPoints = <ink.StrokePoint>[];
      var relative = 0;

      for (var i = 0; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final real = p.t;
        if (real != null && real > relative) {
          // Preserve real timing within the stroke.
          relative = real;
        } else if (i > 0) {
          // Add one millisecond for an untimed legacy or partial point.
          relative += 1;
        }
        inkPoints.add(
          ink.StrokePoint(
            x: p.x - origin.dx,
            y: p.y - origin.dy,
            t: baseTime + relative,
          ),
        );
      }

      result.add(ink.Stroke()..points = inkPoints);
      // Start the next stroke after a short pause.
      baseTime += relative + 50;
    }

    return result;
  }

  /// Estimates text bounds from stroke points.
  ///
  /// Returns a [Rect] containing all stroke points plus a thickness margin.
  static ui.Rect _estimateTextBounds(List<Stroke> strokes) {
    if (strokes.isEmpty) return ui.Rect.zero;

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    var maxSize = 0.0;

    for (final stroke in strokes) {
      for (final p in stroke.points) {
        if (p.x < left) left = p.x;
        if (p.y < top) top = p.y;
        if (p.x > right) right = p.x;
        if (p.y > bottom) bottom = p.y;
      }
      if (stroke.size > maxSize) maxSize = stroke.size;
    }

    // Include the widest stroke thickness.
    final margin = maxSize;
    return ui.Rect.fromLTRB(
      left - margin,
      top - margin,
      right + margin,
      bottom + margin,
    );
  }

  /// Renders the supplied strokes to a temporary PNG for bitmap OCR fallback.
  static Future<OcrResult> _recognizeFallback(
    List<Stroke> strokes, {
    required ui.Size sheetSize,
    required TextRecognitionScript script,
  }) async {
    if (strokes.isEmpty) return const OcrResult(text: '', blocks: []);

    // Create a temporary page containing only these strokes.
    final tempPage = Page.blank(name: 'ocr_temp');
    tempPage.strokes.addAll(strokes);

    return recognizeText(
      tempPage,
      sheetSize: sheetSize,
      imageCache: {},
      script: script,
    );
  }

  /// Groups strokes into lines; exposed for tests and the UI.
  @visibleForTesting
  static List<List<Stroke>> segmentIntoLines(List<Stroke> strokes) =>
      segmentStrokesIntoLines(strokes);
}
