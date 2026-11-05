// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/pdf_import_coordinator.dart';

Future<PdfImportResult?> runPdfImportWithProgress(
  BuildContext context,
  PdfImportCoordinator coordinator,
) async {
  return _runPdfImportWithProgress(context, coordinator);
}

Future<PdfImportResult?> runPdfFileImportWithProgress(
  BuildContext context,
  PdfImportCoordinator coordinator,
  PdfPickedFile file,
) async {
  return _runPdfImportWithProgress(context, coordinator, file: file);
}

Future<PdfImportResult?> _runPdfImportWithProgress(
  BuildContext context,
  PdfImportCoordinator coordinator, {
  PdfPickedFile? file,
}) async {
  if (!coordinator.isSupported) {
    throw const PdfImportException(PdfImportFailureKind.unsupported);
  }
  final outcome = await showDialog<_PdfImportOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _PdfImportProgressDialog(coordinator: coordinator, file: file),
  );
  if (outcome == null) return null;
  if (outcome.error != null) {
    Error.throwWithStackTrace(outcome.error!, outcome.stackTrace!);
  }
  return outcome.result;
}

String pdfImportErrorMessage(BuildContext context, Object error) {
  if (error is PdfImportException) {
    return switch (error.kind) {
      PdfImportFailureKind.unsupported => context.l10n.pdfUnsupported,
      PdfImportFailureKind.empty => context.l10n.pdfNoPages,
      PdfImportFailureKind.render => context.l10n.pdfImportFailed(
        '${error.cause ?? context.l10n.pdfReadFailed}',
      ),
    };
  }
  return context.l10n.pdfImportFailed('$error');
}

class _PdfImportOutcome {
  const _PdfImportOutcome.success(this.result)
    : error = null,
      stackTrace = null;

  const _PdfImportOutcome.failure(this.error, this.stackTrace) : result = null;

  final PdfImportResult? result;
  final Object? error;
  final StackTrace? stackTrace;
}

class _PdfImportProgressDialog extends StatefulWidget {
  const _PdfImportProgressDialog({required this.coordinator, this.file});

  final PdfImportCoordinator coordinator;
  final PdfPickedFile? file;

  @override
  State<_PdfImportProgressDialog> createState() =>
      _PdfImportProgressDialogState();
}

class _PdfImportProgressDialogState extends State<_PdfImportProgressDialog> {
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      void onProgress(int count) {
        if (mounted) setState(() => _pageCount = count);
      }

      final result = widget.file == null
          ? await widget.coordinator.pickAndImport(onProgress: onProgress)
          : await widget.coordinator.importFile(
              widget.file!,
              onProgress: onProgress,
            );
      if (mounted) {
        Navigator.pop(context, _PdfImportOutcome.success(result));
      }
    } catch (error, stackTrace) {
      if (mounted) {
        Navigator.pop(context, _PdfImportOutcome.failure(error, stackTrace));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 24),
          Flexible(child: Text(context.l10n.pdfImportProgress(_pageCount))),
        ],
      ),
    ),
  );
}
