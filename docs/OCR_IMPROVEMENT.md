# Handwriting OCR Improvement Plan

> Status (2026-10-31): **proposed plan, not yet executed**. Based on reading
> `lib/services/ocr_service.dart`, `lib/services/ocr_language.dart`,
> `lib/ui/editor/selection_bar.dart` and `lib/ui/home_screen.dart`.
> Architecture context: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6 ·
> Current state: [`../ROADMAP.md`](../ROADMAP.md) "OCR and search" ·
> Manual verification: [`testing.md`](testing.md) §5b.

## Problem

Handwriting recognition quality is poor, **especially for Thai**. For `th`,
the ML Kit ink model is the **only** path (`script: null` in
`ocr_language.dart`: there is no bitmap fallback), so every improvement has to
make the ink path better, not add a parallel path.

## Diagnosis: what the model receives today

`OcrService.recognizeStrokes` (`lib/services/ocr_service.dart`):

| # | Problem | Effect |
|---|---|---|
| 1 | **Synthetic timestamps**: 1 ms per point, 50 ms between strokes. The model is a temporal sequence model (the same technology as Gboard); stroke order and rhythm are signal, and 1 ms/point is actively wrong. | Worse recognition, especially in Thai where stroke order within a syllable matters. |
| 2 | **The whole page in a single call** (`recognizePageInk` / `recognizeSmart`). | The model's context window doesn't match a page; errors propagate across lines. |
| 3 | **`preContext` is never passed** (the API supports it). | No lexical context between lines. |
| 4 | **Only `candidates.first` is used.** The API returns multiple candidates and a `score` (lower = better). | The best available option is discarded without looking. |
| 5 | `writingArea` = full sheet size (1191×1684). | Correct, but the content is a tiny fraction of the area; not the problem. |

## Staged plan

### Stage 1 — Feed the model better input (highest value/effort, no new dependencies)

1. **Record real timestamps and pressure at capture time.**
   `StrokePoint` already has `pressure`; add `t` (ms since stroke start) where
   points are captured in the input handler. This is the single biggest lever:
   the model is a temporal sequence model and the synthetic 1 ms/point timing
   is wrong.
   - Affects: `lib/models/stroke.dart` (+ `t` field), the canvas input handler,
     migration for old strokes (`t: null` → synthesize as today).
2. **Segment into lines before recognizing.**
   Cluster strokes by vertical position (Y-overlap + X-gap heuristics, or
   connected components over each stroke's bounds). Recognize **one line per
   call** instead of the whole page. This alone usually cuts errors
   dramatically, because the model's window matches a line.
   - Affects: `ocr_service.dart` (new segmentation step before
     `recognizeStrokes`).
3. **Pass `preContext`** = last words of the previously recognized line (the
   API supports it; unused today).
   - Affects: `ocr_service.dart` (loop over lines).
4. **Use all candidates**, not just `first` — keep them for the Stage 2
   reranking and, at minimum, pick by `score` (the code currently assumes
   `first` is best, which the API only loosely guarantees).
   - Affects: `ocr_service.dart` (`OcrResult` can carry `candidates`).

### Stage 2 — Post-processing

5. **Rerank candidates against a Thai lexicon.**
   Bundle a Thai word list (PyThaiNLP's dictionary, ~400k words, a few MB; or
   the base `pythainlp` dictionary). Score each candidate by the fraction of
   whitespace-split tokens that are in the dictionary; prefer valid
   segmentations. It's cheap and catches "looks like a real word" errors.
   - Affects: new `lib/services/ocr_lexicon.dart` + bundled asset;
     `ocr_service.dart` applies the reranking after `recognize`.
6. **User-correction cache.**
   When the user edits the result in the existing dialog (`showTextPrompt` in
   `selection_bar.dart` already shows an editable prompt), diff old→new and
   store the `(wrong → right)` mappings in `SharedPreferences` (or a small
   local JSON). At recognition time, apply known corrections as a first pass,
   before/after the lexicon reranking. It compounds over time and is free.
   - Affects: `selection_bar.dart` + `home_screen.dart` (capture the edit),
     new local storage, `ocr_service.dart` (apply mappings).
7. **Per-word boxes for the "convert to text" path** (`selection_bar.dart`):
   that path already works on a selection; the page-wide path in
   `home_screen.dart` should let the user re-OCR a single line if the result
   looks wrong (UI: tap a line in the result dialog to re-recognize just those
   strokes).

### Stage 3 — Rasterized fallback for Thai (optional, only if 1+2 is not enough)

8. **Render strokes → high-contrast bitmap** (thick black on white, one line
   per image, normalized height ~128–256 px, padded) and run an on-device Thai
   OCR. Realistic options:
   - **PaddleOCR Thai (PP-OCRv4) via ONNX Runtime Mobile** — ~10–20 MB, fast
     on mid-range phones, but trained on *printed* text; expect mediocre
     handwriting accuracy out of the box. Use it as a **second opinion /
     fallback**, not a replacement: when the ink model's best candidate has a
     poor score or the lexicon reranking is weak, run the bitmap path and pick
     the better of the two.
   - **VLM (Gemma/Qwen-VL via LiteRT-LM)** — skip. Multi-GB, slow,
     flagship-only; wrong trade-off for a note app.
9. **Fine-tuning** only if Stage 1–2 leaves visible gaps: collect the
   user-corrected samples (Stage 2 already logs them) and fine-tune the
   PaddleOCR recognition head on your own handwriting corpus. This is a later,
   data-dependent step — don't plan it until you have ~1–5k corrected lines.

## What is skipped

- **Keeping whole-page recognition**: the line segmentation in Stage 1.2 makes
  it moot.
- **The VLM route**: cost/benefit doesn't fit a note app.
- **Dropping ML Kit**: its Thai ink model is still the best on-device
  handwriting-specific option; the bitmap recognizer is a complement, not a
  replacement.

## Suggested order

Stage 1 (1–4) first: it's all in `ocr_service.dart` + the input handler, no new
dependencies, and it attacks the root cause (bad input) rather than the
symptom. Then Stage 2 (5–7) for the long tail. Stage 3 only if measured
accuracy after 1+2 is still unacceptable on real Thai samples.

## Verification

- Each stage is validated against `docs/testing.md` §5b (OCR flows,
  Android/iOS).
- To measure real improvement: a fixed set of Thai sample pages (e.g. 20–50
  lines of your own handwriting) with the expected text annotated; compare
  per-line error rate before/after each stage. Without that set, "improvement"
  is not measurable.
