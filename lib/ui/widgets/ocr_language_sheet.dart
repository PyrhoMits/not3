// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/ocr_language.dart';
import '../theme/inklus_colors.dart';
import '../theme/tokens.dart';
import 'dialogs.dart';
import 'page_scaffold.dart';

/// Result of selecting a language in [showOcrLanguageSheet].
class OcrLanguageSelection {
  const OcrLanguageSelection(this.language, {required this.needsDownload});

  final OcrLanguage language;

  /// Whether the model is missing and the user approved its download.
  final bool needsDownload;
}

/// Sheet for selecting the handwriting OCR language.
///
/// This only returns a selection; it does not download anything. The caller
/// requests the ML Kit model after consent. Returns null when dismissed.
Future<OcrLanguageSelection?> showOcrLanguageSheet(
  BuildContext context, {
  required String currentCode,
  required Set<String> downloadedCodes,
}) {
  return showModalBottomSheet<OcrLanguageSelection>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            icon: Icons.translate,
            title: sheetContext.l10n.ocrLanguageTitle,
          ),
          for (final language in supportedOcrLanguages)
            _LanguageTile(
              language: language,
              selected: language.code == currentCode,
              downloaded: downloadedCodes.contains(language.code),
            ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    ),
  );
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.downloaded,
  });

  final OcrLanguage language;
  final bool selected;
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(
        downloaded ? Icons.keyboard_outlined : Icons.cloud_download_outlined,
        color: context.colors.onSurfaceVariant,
      ),
      title: Text(language.label, style: context.text.titleSmall),
      subtitle: downloaded
          ? null
          : Text(
              l10n.ocrLanguageDownload,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
      trailing: selected
          ? Icon(Icons.check, color: context.colors.primary)
          : null,
      shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      onTap: () async {
        if (downloaded) {
          Navigator.pop(
            context,
            OcrLanguageSelection(language, needsDownload: false),
          );
          return;
        }
        final ok = await showConfirmDialog(
          context,
          title: l10n.ocrLanguageDownloadTitle(language.label),
          message: l10n.ocrLanguageDownloadMessage,
          confirmLabel: l10n.ocrLanguageDownload,
        );
        if (!context.mounted || !ok) return;
        Navigator.pop(
          context,
          OcrLanguageSelection(language, needsDownload: true),
        );
      },
    );
  }
}
