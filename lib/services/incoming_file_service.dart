// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';

enum IncomingFileKind { pdf, html, archive, unsupported }

class IncomingFile {
  const IncomingFile({
    required this.path,
    required this.displayName,
    required this.kind,
    this.temporary = false,
  });

  final String path;
  final String displayName;
  final IncomingFileKind kind;
  final bool temporary;

  static IncomingFile? fromChannel(Object? value) {
    // Compatibility with builds that sent only the copied archive path.
    if (value is String) {
      final path = value.trim();
      if (path.isEmpty) return null;
      return IncomingFile(
        path: path,
        displayName: _basename(path),
        kind: _kindFrom(null, path),
        temporary: true,
      );
    }
    if (value is! Map) return null;

    final path = value['path']?.toString().trim() ?? '';
    if (path.isEmpty) return null;
    final suppliedName = value['displayName']?.toString().trim() ?? '';
    final displayName = suppliedName.isEmpty ? _basename(path) : suppliedName;
    return IncomingFile(
      path: path,
      displayName: displayName,
      kind: _kindFrom(value['kind']?.toString(), displayName),
      temporary: value['temporary'] == true,
    );
  }

  static IncomingFileKind _kindFrom(String? rawKind, String name) {
    switch (rawKind?.toLowerCase()) {
      case 'pdf':
        return IncomingFileKind.pdf;
      case 'html':
        return IncomingFileKind.html;
      case 'archive':
        return IncomingFileKind.archive;
      case 'unsupported':
        return IncomingFileKind.unsupported;
    }
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return IncomingFileKind.pdf;
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return IncomingFileKind.html;
    }
    if (lower.endsWith('.inklus') || lower.endsWith('.zip')) {
      return IncomingFileKind.archive;
    }
    return IncomingFileKind.unsupported;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}

abstract interface class IncomingFileReceiver {
  Future<void> start(Future<void> Function(IncomingFile file) onFile);

  Future<void> stop();
}

class MethodChannelIncomingFileReceiver implements IncomingFileReceiver {
  MethodChannelIncomingFileReceiver({
    this.channel = const MethodChannel('inklus/open'),
  });

  final MethodChannel channel;

  @override
  Future<void> start(Future<void> Function(IncomingFile file) onFile) async {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'file') return;
      final file = IncomingFile.fromChannel(call.arguments);
      if (file != null) await onFile(file);
    });
    try {
      final file = IncomingFile.fromChannel(
        await channel.invokeMethod<Object?>('take'),
      );
      if (file != null) await onFile(file);
    } on MissingPluginException {
      // The receiver is only available in the Android host application.
    }
  }

  @override
  Future<void> stop() async {
    channel.setMethodCallHandler(null);
  }
}
