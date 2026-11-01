// SPDX-License-Identifier: GPL-3.0-or-later

/// A possible reading returned by the ML Kit digital-ink model.
///
/// [score] follows the model convention: lower values are better. It can be
/// negative or `NaN` for models that do not provide scores.
class OcrCandidate {
  const OcrCandidate({required this.text, required this.score});

  final String text;
  final double score;
}
