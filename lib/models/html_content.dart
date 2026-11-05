// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Metadata for an Android-only continuous HTML annotation surface.
@immutable
class HtmlContent {
  const HtmlContent({
    required this.sourcePath,
    this.logicalWidth = defaultLogicalWidth,
    this.contentHeight = defaultContentHeight,
  });

  static const double defaultLogicalWidth = 1191;
  static const double defaultContentHeight = 1684;

  /// Path relative to the Not3 app-data root.
  final String sourcePath;
  final double logicalWidth;
  final double contentHeight;

  HtmlContent copyWith({
    String? sourcePath,
    double? logicalWidth,
    double? contentHeight,
  }) => HtmlContent(
    sourcePath: sourcePath ?? this.sourcePath,
    logicalWidth: logicalWidth ?? this.logicalWidth,
    contentHeight: contentHeight ?? this.contentHeight,
  );

  factory HtmlContent.fromJson(Map<String, dynamic> json) {
    final width = (json['logicalWidth'] as num?)?.toDouble();
    final height = (json['contentHeight'] as num?)?.toDouble();
    return HtmlContent(
      sourcePath: json['sourcePath'] as String? ?? '',
      logicalWidth: width != null && width.isFinite && width > 0
          ? width.clamp(320, 4096)
          : defaultLogicalWidth,
      contentHeight: height != null && height.isFinite && height > 0
          ? height.clamp(1, 10000000)
          : defaultContentHeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'sourcePath': sourcePath,
    'logicalWidth': logicalWidth,
    'contentHeight': contentHeight,
  };
}
