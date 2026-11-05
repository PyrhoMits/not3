// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/inklus_colors.dart';
import 'widgets/page_scaffold.dart';
import 'theme/tokens.dart';

import '../models/note.dart';
import '../models/notebook.dart';
import '../models/page.dart' as models;
import '../models/template.dart';
import '../services/drive_sync_service.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import '../services/pdf_import_coordinator.dart';
import '../services/html_import_service.dart';
import '../services/search_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'html_annotation_screen.dart';
import 'widgets/dialogs.dart';
import '../l10n/l10n.dart';
import '../utils/date_utils.dart' as date_util;
import 'widgets/notebook_covers.dart';
import 'widgets/pdf_import_progress.dart';

/// Displays the notes inside one notebook.
///
/// The persisted container is still named [Notebook] for file compatibility.
/// Users can create, import, rename, duplicate, delete and move notes here.
class NoteListScreen extends StatefulWidget {
  final Notebook notebook;
  final StorageService? storage;
  final SearchService? search;
  final PdfImportCoordinator pdfImporter;
  final HtmlImportService htmlImporter;
  final String? initialNoteId;

  const NoteListScreen({
    super.key,
    required this.notebook,
    this.storage,
    this.search,
    this.pdfImporter = const PdfImportCoordinator(),
    this.htmlImporter = const HtmlImportService(),
    this.initialNoteId,
  });

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  late final StorageService _storage;
  late final SearchService _search;
  final ImageService _imageService = ImageService();
  late Notebook _notebook;
  final Map<String, Future<Uint8List>> _thumbs = {};
  final Set<String> _selectedNoteIds = {};
  bool _importingPdf = false;
  bool _importingHtml = false;

  bool get _selecting => _selectedNoteIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? StorageService.instance;
    _search =
        widget.search ??
        (widget.storage == null
            ? SearchService.instance
            : SearchService(storage: _storage));
    _notebook = widget.notebook;
    final initialNoteId = widget.initialNoteId;
    if (initialNoteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final note = _notebook.notes
            .where((candidate) => candidate.id == initialNoteId)
            .firstOrNull;
        if (note != null) unawaited(_openNote(note));
      });
    }
  }

  Future<Uint8List> _thumbFor(Note note) =>
      _thumbs.putIfAbsent(note.id, () => _renderThumb(note));

  Future<Uint8List> _renderThumb(Note note) async {
    if (note.pages.isEmpty) throw StateError('Sin páginas');
    final page = note.pages.first;
    for (final item in page.images) {
      await _imageService.ensureCached(item.localPath);
    }
    final templatePath = page.template.imagePath;
    if (templatePath != null) {
      await _imageService.ensureCached(templatePath);
    }
    return ExportService.renderPagePng(
      page,
      sheetSize: page.template.sheetSize,
      imageCache: _imageService.cache,
      options: const ExportOptions(maxDimension: 320),
    );
  }

  Future<void> _reload() async {
    final nb = await _storage.loadNotebook(_notebook.id);
    if (nb != null && mounted) {
      setState(() => _notebook = nb);
    }
  }

  // ------------------------------------------------------------------------- CRUD

  Future<void> _createNote() async {
    final result = await _showCreateNoteDialog();
    if (result == null) return;
    final note = await _storage.createNote(
      _notebook.id,
      title: result.name,
      template: result.template,
    );
    if (!mounted) return;
    await _reload();
    // Abrir la nota recién creada
    await _openNote(note);
  }

  Future<void> _openNote(Note note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => note.pages.length == 1 && note.pages.single.isHtml
            ? HtmlAnnotationScreen(
                note: note,
                notebookId: _notebook.id,
                storage: _storage,
              )
            : HomeScreen(
                note: note,
                notebookId: _notebook.id,
                storage: _storage,
                search: _search,
                pdfImporter: widget.pdfImporter,
              ),
      ),
    );
    await _reload();
  }

  Future<void> _renameNote(Note note) async {
    final name = await _promptText(
      titulo: context.l10n.noteRenameTitle,
      hint: context.l10n.createName,
      prefilled: displayTitle(context.l10n, note.title),
    );
    if (name == null) return;
    await _storage.renameNote(_notebook.id, note.id, name);
    await _reload();
  }

  Future<void> _duplicateNote(Note note) async {
    await _storage.duplicateNote(_notebook.id, note.id);
    await _reload();
  }

  Future<void> _importPdf() async {
    if (_importingPdf) return;
    setState(() => _importingPdf = true);
    PdfImportResult? result;
    var attached = false;
    try {
      result = await runPdfImportWithProgress(context, widget.pdfImporter);
      if (result == null || !mounted) return;
      final note = await _storage.createNote(
        _notebook.id,
        title: result.suggestedTitle,
        pages: [
          for (final (index, page) in result.pages.indexed)
            models.Page.background(
              name: '${index + 1}',
              path: page.path,
              width: page.width,
              height: page.height,
            ),
        ],
      );
      attached = true;
      await _reload();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_openNote(note));
        });
      }
    } catch (error) {
      if (result != null && !attached) await widget.pdfImporter.discard(result);
      if (mounted) showSnack(context, pdfImportErrorMessage(context, error));
    } finally {
      if (mounted) setState(() => _importingPdf = false);
    }
  }

  Future<void> _importHtml() async {
    if (_importingHtml) return;
    setState(() => _importingHtml = true);
    try {
      final picked = await widget.htmlImporter.pick();
      if (picked == null) return;
      final prepared = await widget.htmlImporter.prepare(picked);
      if (!mounted) return;
      if (prepared.requiresLargeFileConfirmation) {
        final sizeMiB = prepared.sourceBytes / (1024 * 1024);
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.htmlImportLargeTitle),
            content: Text(
              context.l10n.htmlImportLargeBody(sizeMiB.toStringAsFixed(1)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.htmlImportAction),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
      final note = await _storage.createHtmlNote(
        _notebook.id,
        title: prepared.suggestedTitle,
        sanitizedHtml: prepared.html,
      );
      await _reload();
      if (!mounted) return;
      if (prepared.removedActiveContent) {
        showSnack(context, context.l10n.htmlImportRemovedUnsafe);
      }
      await _openNote(note);
    } on HtmlImportException catch (error) {
      if (mounted) showSnack(context, _htmlImportError(error));
    } catch (error) {
      if (mounted) showSnack(context, context.l10n.htmlImportFailed('$error'));
    } finally {
      if (mounted) setState(() => _importingHtml = false);
    }
  }

  String _htmlImportError(HtmlImportException error) => switch (error.kind) {
    HtmlImportFailureKind.unsupportedPlatform => context.l10n.htmlAndroidOnly,
    HtmlImportFailureKind.unsupportedFileType =>
      context.l10n.htmlUnsupportedFileType,
    HtmlImportFailureKind.missingFile => context.l10n.htmlFileMissing,
    HtmlImportFailureKind.empty => context.l10n.htmlFileEmpty,
    HtmlImportFailureKind.tooLarge => context.l10n.htmlFileTooLarge(
      _htmlSizeMiB(error.details),
    ),
    HtmlImportFailureKind.tooComplex => context.l10n.htmlFileTooComplex,
    HtmlImportFailureKind.invalidEncoding => context.l10n.htmlUtf8Required,
    HtmlImportFailureKind.unsupportedResource =>
      context.l10n.htmlUnsupportedResource,
    HtmlImportFailureKind.oversizedImage => context.l10n.htmlOversizedImage,
    HtmlImportFailureKind.invalidImage => context.l10n.htmlInvalidImage,
  };

  String _htmlSizeMiB(String? bytes) {
    final length = int.tryParse(bytes ?? '');
    return length == null
        ? 'over 5'
        : (length / (1024 * 1024)).toStringAsFixed(1);
  }

  void _toggleSelection(String noteId) {
    setState(() {
      if (!_selectedNoteIds.add(noteId)) _selectedNoteIds.remove(noteId);
    });
  }

  void _clearSelection() => setState(_selectedNoteIds.clear);

  Future<String?> _pickDestinationNotebook() async {
    final metas =
        (await _storage.loadIndex())
            .where((meta) => meta.id != _notebook.id)
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    if (!mounted) return null;
    const createNew = '__create_new_notebook__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: Text(context.l10n.noteMoveTitle),
              subtitle: Text(context.l10n.noteMoveHint),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(context.l10n.noteCreateNotebook),
              onTap: () => Navigator.pop(context, createNew),
            ),
            for (final meta in metas)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(displayTitle(context.l10n, meta.title)),
                onTap: () => Navigator.pop(context, meta.id),
              ),
          ],
        ),
      ),
    );
    if (selected != createNew) return selected;
    if (!mounted) return null;
    final notebookCount = (await _storage.loadIndex()).length;
    if (!mounted) return null;
    final name = await _promptText(
      titulo: context.l10n.createTitle,
      hint: context.l10n.createNameHint,
      prefilled: context.l10n.createDefaultName(notebookCount + 1),
    );
    if (name == null) return null;
    final notebook = await _storage.createNotebook(
      title: name,
      createInitialNote: false,
    );
    return notebook.id;
  }

  Future<void> _moveNotes(Set<String> noteIds) async {
    if (noteIds.isEmpty) return;
    final destinationId = await _pickDestinationNotebook();
    if (destinationId == null || !mounted) return;
    try {
      await _storage.moveNotes(_notebook.id, destinationId, noteIds);
      await _search.moveNotesToNotebook(noteIds, destinationId);
      final destination = await _storage.loadNotebook(destinationId);
      final meta = (await _storage.loadIndex())
          .where((candidate) => candidate.id == destinationId)
          .firstOrNull;
      if (destination != null &&
          meta != null &&
          meta.isSyncEnabled &&
          DriveSyncService.instance.isSignedIn) {
        unawaited(_syncMovedNotes(destination, noteIds, meta.title));
      }
      await _reload();
      if (!mounted) return;
      _clearSelection();
      showSnack(context, context.l10n.noteMoved(noteIds.length));
    } catch (error) {
      if (mounted) showSnack(context, context.l10n.noteMoveFailed('$error'));
    }
  }

  Future<void> _syncMovedNotes(
    Notebook destination,
    Set<String> noteIds,
    String notebookTitle,
  ) async {
    for (final note in destination.notes.where((n) => noteIds.contains(n.id))) {
      try {
        await DriveSyncService.instance.backupNote(
          note,
          notebookId: destination.id,
          notebookTitle: notebookTitle,
        );
      } catch (_) {
        return;
      }
    }
  }

  Future<void> _deleteNote(Note note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.noteDeleteTitle),
        content: Text(context.l10n.noteDeleteBody(note.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.libDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _storage.deleteNote(_notebook.id, note.id);
    await _reload();
  }

  Future<void> _renameNotebook() async {
    final name = await _promptText(
      titulo: context.l10n.libRenameTitle,
      hint: context.l10n.createName,
      prefilled: displayTitle(context.l10n, _notebook.title),
    );
    if (name == null) return;
    await _storage.renameNotebook(_notebook.id, name);
    await _reload();
  }

  // ------------------------------------------------------------------------- Diálogos

  Future<_CreateNoteResult?> _showCreateNoteDialog() async {
    final nameController = TextEditingController(
      text: context.l10n.noteDefaultName(_notebook.notes.length + 1),
    );
    var selectedTemplate = const PageTemplate();

    return showDialog<_CreateNoteResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.noteNew),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.createName,
                    hintText: context.l10n.noteNameHint,
                  ),
                  onSubmitted: (_) {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.pop(
                        context,
                        _CreateNoteResult(
                          name: nameController.text.trim(),
                          template: selectedTemplate,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.createTemplate,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                _CompactTemplateGrid(
                  selected: selectedTemplate.type,
                  onSelect: (t) => setDialogState(() {
                    selectedTemplate = selectedTemplate.copyWith(type: t);
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  context,
                  _CreateNoteResult(name: name, template: selectedTemplate),
                );
              },
              child: Text(context.l10n.noteCreate),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptText({
    required String titulo,
    required String hint,
    required String prefilled,
  }) async {
    final result = await showTextPrompt(
      context,
      title: titulo,
      hint: hint,
      initialValue: prefilled,
      confirmLabel: context.l10n.commonSave,
    );
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  // ------------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final count = _notebook.notes.length;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _clearSelection();
      },
      child: Not3Page(
        title: _selecting
            ? context.l10n.noteSelectedCount(_selectedNoteIds.length)
            : _notebook.title,
        subtitle: _selecting ? null : context.l10n.noteCount(count),
        maxWidth: double.infinity,
        headerTrailing: null,
        actions: _selecting
            ? [
                IconButton(
                  tooltip: context.l10n.noteSelectAll,
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    _selectedNoteIds
                      ..clear()
                      ..addAll(_notebook.notes.map((note) => note.id));
                  }),
                ),
                IconButton(
                  tooltip: context.l10n.noteMoveToNotebook,
                  icon: const Icon(Icons.drive_file_move_outlined),
                  onPressed: () => _moveNotes(Set.of(_selectedNoteIds)),
                ),
                IconButton(
                  tooltip: context.l10n.commonClose,
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
              ]
            : [
                IconButton(
                  tooltip: context.l10n.libRenameTitle,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _renameNotebook,
                ),
              ],
        floatingActionButton: _selecting
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _importingPdf || !widget.pdfImporter.isSupported
                        ? null
                        : _importPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(context.l10n.pdfImportAction),
                  ),
                  const SizedBox(height: Spacing.xs),
                  OutlinedButton.icon(
                    onPressed:
                        _importingHtml || !widget.htmlImporter.isSupported
                        ? null
                        : _importHtml,
                    icon: _importingHtml
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.html_outlined),
                    label: Text(context.l10n.htmlImportAction),
                  ),
                  const SizedBox(height: Spacing.sm),
                  FloatingActionButton.extended(
                    onPressed: _createNote,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.noteNew),
                  ),
                ],
              ),
        slivers: [
          if (count == 0)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.note_add_outlined,
                title: context.l10n.noteEmptyTitle,
                message: context.l10n.noteEmptyHint,
                actions: [
                  FilledButton.icon(
                    onPressed: _createNote,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.noteCreateAction),
                  ),
                  if (widget.htmlImporter.isSupported)
                    OutlinedButton.icon(
                      onPressed: _importHtml,
                      icon: _importingHtml
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.html_outlined),
                      label: Text(context.l10n.htmlImportAction),
                    ),
                ],
              ),
            )
          else
            _buildNoteGrid(),
        ],
      ),
    );
  }

  Widget _buildNoteGrid() {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 210,
        crossAxisSpacing: Spacing.md,
        mainAxisSpacing: Spacing.md,
      ),
      itemCount: _notebook.notes.length,
      itemBuilder: (context, index) {
        final note = _notebook.notes[index];
        final pageCount = note.pages.length;
        final timeAgo = date_util.relativeTime(context.l10n, note.updatedAt);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              if (_selecting) {
                _toggleSelection(note.id);
              } else {
                _openNote(note);
              }
            },
            onLongPress: () {
              unawaited(HapticFeedback.selectionClick());
              _toggleSelection(note.id);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Miniatura de la primera página
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: context.colors.surfaceContainerHighest,
                        child: FutureBuilder<Uint8List>(
                          future:
                              note.pages.length == 1 && note.pages.single.isHtml
                              ? Future<Uint8List>.error('HTML preview')
                              : _thumbFor(note),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              );
                            }
                            if (snapshot.hasError) {
                              return Icon(
                                Icons.description_outlined,
                                color: context.colors.outline,
                                size: 36,
                              );
                            }
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Menú contextual flotante
                      if (!_selecting)
                        Positioned(
                          top: Spacing.xs,
                          right: Spacing.xs,
                          child: MenuAnchor(
                            menuChildren: [
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.edit_outlined),
                                onPressed: () => _renameNote(note),
                                child: Text(context.l10n.libRename),
                              ),
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.copy_outlined),
                                onPressed: () => _duplicateNote(note),
                                child: Text(context.l10n.libDuplicate),
                              ),
                              MenuItemButton(
                                leadingIcon: const Icon(
                                  Icons.drive_file_move_outlined,
                                ),
                                onPressed: () => _moveNotes({note.id}),
                                child: Text(context.l10n.noteMoveToNotebook),
                              ),
                              const Divider(),
                              MenuItemButton(
                                leadingIcon: Icon(
                                  Icons.delete_outline,
                                  color: context.inklus.danger,
                                ),
                                onPressed: () => _deleteNote(note),
                                child: Text(
                                  context.l10n.libDelete,
                                  style: TextStyle(
                                    color: context.inklus.danger,
                                  ),
                                ),
                              ),
                            ],
                            builder: (context, menu, _) => IconButton(
                              tooltip: context.l10n.noteOptions,
                              style: IconButton.styleFrom(
                                backgroundColor: context.colors.surface
                                    .withValues(alpha: 0.85),
                                foregroundColor: context.colors.onSurface,
                              ),
                              icon: const Icon(Icons.more_vert),
                              onPressed: () =>
                                  menu.isOpen ? menu.close() : menu.open(),
                            ),
                          ),
                        ),
                      if (_selectedNoteIds.contains(note.id))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                border: Border.all(
                                  color: context.colors.primary,
                                  width: 3,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(Spacing.sm),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: context.colors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Info de la nota
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.sm,
                    Spacing.sm,
                    Spacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle(context.l10n, note.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall,
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              context.l10n.notePageCount(pageCount, timeAgo),
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Helpers ---

/// Resultado del diálogo de creación de nota.
class _CreateNoteResult {
  final String name;
  final PageTemplate template;
  _CreateNoteResult({required this.name, required this.template});
}

/// Grid compacto de selección de plantillas.
class _CompactTemplateGrid extends StatelessWidget {
  final TemplateType selected;
  final ValueChanged<TemplateType> onSelect;

  const _CompactTemplateGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final templates = <(TemplateType, IconData, String)>[
      (TemplateType.blank, Icons.landscape, context.l10n.noteTplInfinite),
      (
        TemplateType.ruled,
        Icons.format_list_bulleted,
        context.l10n.createTplRuled,
      ),
      (TemplateType.grid, Icons.grid_on, context.l10n.createTplGrid),
      (TemplateType.dots, Icons.grain, context.l10n.createTplDots),
      (TemplateType.sheet, Icons.description, context.l10n.noteTplSheet),
      (TemplateType.music, Icons.music_note, context.l10n.createTplMusic),
      (TemplateType.planner, Icons.calendar_today, context.l10n.noteTplPlanner),
      (TemplateType.habit, Icons.checklist, context.l10n.createTplHabit),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: templates.map((t) {
        final (type, icon, label) = t;
        final isSelected = selected == type;
        return GestureDetector(
          onTap: () => onSelect(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primary.withAlpha(20)
                  : context.colors.surfaceContainerHighest,
              borderRadius: Radii.smAll,
              border: Border.all(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
