// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:collection';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'pdf_import_service.dart';

typedef PdfPicker = Future<PdfPickedFile?> Function();
typedef PdfRenderer = Stream<PdfPageImage> Function(String path);
typedef PdfImportedFileDeleter = Future<void> Function(String path);

@immutable
class PdfPickedFile {
  const PdfPickedFile({required this.path, required this.displayName});

  final String path;
  final String displayName;
}

@immutable
class PdfImportedPage {
  const PdfImportedPage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

@immutable
class PdfImportResult {
  PdfImportResult({
    required this.filename,
    required List<PdfImportedPage> pages,
  }) : pages = UnmodifiableListView(pages);

  final String filename;
  final List<PdfImportedPage> pages;

  String get suggestedTitle {
    final trimmed = filename.trim();
    final withoutExtension = trimmed.replaceFirst(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );
    return withoutExtension.trim().isEmpty ? trimmed : withoutExtension.trim();
  }

  List<({String path, int width, int height})> get backgroundPages => [
    for (final page in pages)
      (path: page.path, width: page.width, height: page.height),
  ];
}

enum PdfImportFailureKind { unsupported, empty, render }

class PdfImportException implements Exception {
  const PdfImportException(this.kind, [this.cause]);

  final PdfImportFailureKind kind;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'PDF import failed: ${kind.name}'
      : 'PDF import failed: ${kind.name}: $cause';
}

/// Shared picker and renderer pipeline used by every PDF import entry point.
class PdfImportCoordinator {
  const PdfImportCoordinator({
    this.picker,
    this.renderer,
    this.deleteImportedFile,
    this.supported,
  });

  final PdfPicker? picker;
  final PdfRenderer? renderer;
  final PdfImportedFileDeleter? deleteImportedFile;
  final bool? supported;

  bool get isSupported => supported ?? PdfImportService.isSupported;

  Future<PdfImportResult?> pickAndImport({
    ValueChanged<int>? onProgress,
  }) async {
    if (!isSupported) {
      throw const PdfImportException(PdfImportFailureKind.unsupported);
    }
    final picked = await (picker ?? _pickPdf)();
    if (picked == null) return null;

    final pages = <PdfImportedPage>[];
    try {
      await for (final page in (renderer ?? PdfImportService.importPages)(
        picked.path,
      )) {
        pages.add(
          PdfImportedPage(
            path: page.path,
            width: page.widthPx,
            height: page.heightPx,
          ),
        );
        onProgress?.call(pages.length);
      }
      if (pages.isEmpty) {
        throw const PdfImportException(PdfImportFailureKind.empty);
      }
      return PdfImportResult(filename: picked.displayName, pages: pages);
    } catch (error, stackTrace) {
      await _cleanup(pages);
      if (error is PdfImportException) rethrow;
      Error.throwWithStackTrace(
        PdfImportException(PdfImportFailureKind.render, error),
        stackTrace,
      );
    }
  }

  Future<void> _cleanup(List<PdfImportedPage> pages) async {
    for (final page in pages) {
      try {
        await (deleteImportedFile ?? _deleteFile)(page.path);
      } catch (_) {
        // Cleanup is best-effort; retain the original rendering failure.
      }
    }
  }

  static Future<PdfPickedFile?> _pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = file?.path;
    if (file == null || path == null || path.isEmpty) return null;
    return PdfPickedFile(path: path, displayName: file.name);
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
