// SPDX-License-Identifier: GPL-3.0-or-later

const String defaultNoteTitle = 'Untitled';
const String defaultNotebookTitle = 'My notebook';

/// Converts default titles stored by older Spanish-only builds to English.
String normalizeNoteTitle(String? title) => switch (title) {
  null || 'Sin título' => defaultNoteTitle,
  _ => title,
};

/// Converts legacy notebook defaults while preserving user-defined titles.
String normalizeNotebookTitle(String? title) => switch (title) {
  null || 'Mi cuaderno' || 'Sin título' => defaultNotebookTitle,
  _ => title,
};
