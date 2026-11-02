// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';

enum LassoContentType { handwriting, highlighter, text, images }

/// Content types that may enter a lasso selection.
@immutable
class LassoSelectionFilter {
  const LassoSelectionFilter({
    required this.handwriting,
    required this.highlighter,
    required this.text,
    required this.images,
  });

  const LassoSelectionFilter.all()
    : handwriting = true,
      highlighter = true,
      text = true,
      images = true;

  final bool handwriting;
  final bool highlighter;
  final bool text;
  final bool images;

  int get enabledCount => [
    handwriting,
    highlighter,
    text,
    images,
  ].where((enabled) => enabled).length;

  bool get hasEnabledType => enabledCount > 0;

  bool isEnabled(LassoContentType type) => switch (type) {
    LassoContentType.handwriting => handwriting,
    LassoContentType.highlighter => highlighter,
    LassoContentType.text => text,
    LassoContentType.images => images,
  };

  LassoSelectionFilter withType(
    LassoContentType type,
    bool enabled,
  ) => LassoSelectionFilter(
    handwriting: type == LassoContentType.handwriting ? enabled : handwriting,
    highlighter: type == LassoContentType.highlighter ? enabled : highlighter,
    text: type == LassoContentType.text ? enabled : text,
    images: type == LassoContentType.images ? enabled : images,
  );

  Map<String, bool> toJson() => {
    'handwriting': handwriting,
    'highlighter': highlighter,
    'text': text,
    'images': images,
  };

  static LassoSelectionFilter? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final handwriting = value['handwriting'];
    final highlighter = value['highlighter'];
    final text = value['text'];
    final images = value['images'];
    if (handwriting is! bool ||
        highlighter is! bool ||
        text is! bool ||
        images is! bool) {
      return null;
    }
    final filter = LassoSelectionFilter(
      handwriting: handwriting,
      highlighter: highlighter,
      text: text,
      images: images,
    );
    return filter.hasEnabledType ? filter : null;
  }

  @override
  bool operator ==(Object other) =>
      other is LassoSelectionFilter &&
      handwriting == other.handwriting &&
      highlighter == other.highlighter &&
      text == other.text &&
      images == other.images;

  @override
  int get hashCode => Object.hash(handwriting, highlighter, text, images);
}
