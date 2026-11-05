# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

Each release is written in English. The release workflow copies the matching section into the GitHub release notes.

## Unreleased

### Added

- Added a fail-closed Huawei MatePad 11 / M-Pencil (2nd generation) Pen–Eraser double-tap bridge using the confirmed DBY-W09 `M-Pencil Mouse` key-event signature, with queued tool switching, a persistent preference, and exact tablet-and-stylus fingerprint checks.

### Fixed

- Recognized rectangles, triangles, and ellipses now keep a seamless closed edge after release; a rectangle no longer gains a clipped fifth corner at its starting point.
- Dragging two shape-edit handles close together no longer changes a rectangle into a triangle.

## [1.9.1] — 2026-10-20

### Changed

- **Live eraser**: strokes vanish while you erase (a single undo on release), interpolated so fast pen movement leaves no gaps; the eraser path bounds are computed once per move instead of once per stroke.
- Universal APK (32-bit and 64-bit) in releases for phones with a 32-bit userland on ARM64 CPUs.

### Fixed

- A right triangle is no longer straightened into a rectangle; all four corners are required.
- The stylus side button works as an eraser whether it is reported as primary or secondary.

## [1.9.0] — 2026-10-15

### Added

- **Brazilian Portuguese, French, and German**: the app was translated into five languages and followed the system language, with English as the fallback.
- **Temporary eraser**: after erasing with the toolbar tool, the app returns to the previous tool. This can be configured in the eraser popover.
- Cover title plates readable on any color, a floating editor toolbar, a thickness indicator on pens, and touch feedback on cards.
- Community files: contribution guide, code of conduct, security policy, and issue and pull request templates.

### Changed

- Shape straightening on hold requires almost a second and a long stroke, so pausing while writing no longer turns handwriting into a shape.
- Two-finger-tap undo is disabled by default (⋮ menu → View).
- The interface uses shared design tokens for spacing, radii, text, and shadows, with 48 dp touch targets and a 12 pt minimum text size.

### Fixed

- The latest strokes are no longer lost if the app moves to the background; changes are saved immediately, and a warning appears when saving fails, such as when the disk is full.
- Notes store a schema version (`schemaVersion`) for future migrations.

## [1.8.0] — 2026-10-01

### Added

- **Rich text in text boxes**: bold, italic, underline, alignment, and eight bundled fonts (Lato, Lora, Caveat, Oswald, Playfair Display, Pacifico, Indie Flower, and Source Code Pro; OFL licenses are in `third_party_licenses/`). Formatting applies to the selection or the whole box and appears consistently on the canvas, in the editor, and in exports.
- **Open `.inklus` files from outside the app on Android**: Not3 appears as an option from Drive, Files, or Share, then imports the notebook or note into the library.
- **Fully localized interface**: every screen and error message follows the system language.
- **More precise shapes**: nearly horizontal or vertical lines snap to the axis (±4°, or ±8° for the highlighter), and the highlighter straightens only lines.

### Changed

- Redesigned notebook creation, covers, the Marketplace, and the templates sheet.
- Unified user-facing errors (`AppError`): services no longer return interface text.
- Improved Google Drive synchronization and backup import.

### Fixed

- Tapping a text box's formatting bar no longer reaches the page underneath.
- Text-box editing records a single undo action per edit.
- The secret scan no longer flags local Graphify caches, which are now ignored by Git.

## [1.7.0] — 2026-09-27

### Added

- **Continuous scrolling between sheets**: fixed sheets stack vertically, scrolling moves smoothly between them, and writing on the next sheet activates it. This can be disabled under ⋮ → View.
- **Per-page undo**: changing pages no longer clears the undo history for the previous page.
- A [privacy policy](docs/privacy.md), linked from Settings next to the source-code link.
- **Local error log**: failures are stored only on the device. Settings → Error log lets users share or clear them. No analytics or third-party logging services are used.
- Localization infrastructure for multiple interface languages. System date and time pickers and Settings followed the selected locale while the remaining screens were still in progress.
- Integration tests covering onboarding → notebook → pen → save, including CI execution, plus the on-device test guide in `docs/testing.md`.
- GitHub release notes generated from this changelog, with CI validation that the tag matches the app version.

### Changed

- Split `CanvasController` into view, selection, and layer parts without changing its public API.
- Centralized data paths in `AppPaths` and removed unused legacy Drive and export code.
- Reminders created in the editor are linked to their notebook, matching reminders created from the reminders screen.

## [1.6.0] — 2026-09-27

### Added

- **Complete lasso support**: scaling, rotating, copying, pasting, and duplicating also work with images and text boxes, not only strokes, with one undo action per operation.
- **Google Drive revisions in version history**: the Version history sheet shows local copies and the revisions Drive retains for each upload. They can be restored in the same way, after the current state is saved. Encrypted copies request their password.
- **Note trash**: restoring a deleted note returns it to its notebook, or to a newly created notebook with the same name if the original no longer exists. Each item shows its type, origin, and remaining retention time.

### Changed

- **Consistent design across every screen**: Trash, Reminders, Statistics, the note list, Onboarding, Tags, Smart folders, Stroke options, Layers, and the template picker use theme colors and measurements in both light and dark modes.
- Redesigned Statistics with totals in cards, streaks, and a chart that adapts to the available width.
- Updated onboarding to explain one-finger scrolling in stylus-only mode, the top toolbar, and local note storage.

### Fixed

- Deleting a notebook no longer creates ghost notes named “Untitled” with a date of December 31, 1969; permanently deleting it no longer leaves its notes in Trash; and the advertised automatic 30-day cleanup now runs.
- Swipe-to-delete works for reminders without throwing a Flutter error.
- Bottom sheets no longer display two drag handles.
- Selection rotation no longer drifts because its pivot is stable between frames, and selection handles are drawn and detected at the same positions.
- Smart folders use the correct color names, including “Other,” and cover colors now use one shared palette throughout the app.

## [1.5.0] — 2026-09-27

### Performance

- **Panning and zooming on full pages**: during the gesture, the canvas draws from a snapshot and paints only newly exposed strips live. It repaints sharply when the gesture ends. Previously, every stroke was redrawn on every frame.
- **Canvas photos at screen resolution** (up to 2560 px per side): a 12 MP photo uses about 20 MB instead of about 48 MB in memory. High-resolution exports decode images at their original resolution one page at a time.

### Fixed

- **Infinite panning on a fixed sheet**: sheet edges now stop 48 px from the screen edge, so the sheet cannot be lost off-screen.
- Full-notebook PDF and PPTX exports no longer omit images from unopened pages or pages evicted from the cache.
- Touch feedback is now visible on Smart folder options instead of being hidden by the sheet background.

### Tools

- `tool/stress/stress_note_test.dart` creates a stress-test notebook with 5,100 strokes and ten 12 MP photos for on-device measurement.

## [1.4.3] — 2026-09-27

### Fixed

- **Stale save timestamps**: notes were written with the `updatedAt` value from the previous save, which could let the wrong Drive copy win during synchronization. Copies restored from Drive retain their original timestamp.
- **Importing a standalone note** from a Drive `.inklus` copy or the editor's `.inklus` copy failed with “Not a valid `.inklus` v2 notebook.” The format is now detected from its contents (`notebook.json` or `document.json`).
- **Legacy `.inklus` imports appearing empty**: the note was saved outside the newly created notebook; it is now stored inside with a new ID.

### Performance

- Creating, renaming, duplicating, or deleting a note, and changing a notebook's title, color, or tags, no longer reads and rewrites every note in that notebook.
- Large notes with more than about 20,000 points are encoded and written in another isolate, so autosave does not block writing.

## [1.4.2] — 2026-09-26

### Added

- **Restore from Drive** in Settings retrieves the newest version of every note using last-write-wins and places notes missing from the device in a “Recovered from Drive” notebook.
- **Unified import**: one “Import `.inklus` or backup” action detects notebook `.inklus` v1/v2 and complete `.zip` backups by content, including `.inklus` files that Android renames to `.zip`.

### Fixed

- **Release-mode startup crash**: R8 removed WorkManager's `WorkDatabase_Impl`, which Room creates through reflection; the required `-keep` rules are now in `proguard-rules.pro`.
- **Google sign-in failure** (`serverClientId must be provided`): `google_sign_in` 7 is initialized once with the web client before any call.
- **Synchronization hanging indefinitely**: Drive requests time out after 60 seconds instead of leaving the cloud indicator in a permanent synchronizing state.
- **Work lost after an unexpected close**: the configurable autosave interval of up to 30 minutes was removed, and every change is saved immediately.

### Changed

- **New icon**: a fountain-pen nib with a gold ink stroke on a blue gradient; SVG sources are in `assets/icon/`.
- **Redesigned Settings** using the design system, with shared components in `ui/widgets/page_scaffold.dart` and the app version displayed.

## [1.4.0] — 2026-09-26

### Added

- **Redesigned editor**: one top bar, tool options in popovers, a page side panel, and compact page and zoom indicators.
- **Favorite pens**: three pens and one highlighter, each with its own color and thickness, plus recent colors.
- **Complete palm rejection**: stylus contact and hover detection, a grace period, and contact-size filtering; automatic stylus-only mode and one-finger scrolling; stylus side button as an eraser.
- **Usable ruler and protractor**: fixed size, sheet centimeters and millimeters, live angle display, touch dragging and rotation, and strokes snapped to the edge or arc.
- **Lasso for strokes, images, and text**: move, delete, recolor, change thickness, duplicate, and convert to text.
- **Eraser** with partial, whole-stroke, and highlighter-only modes.
- **Shapes**: hold to straighten, plus triangle and ellipse recognition.
- **Laser pointer** and a **magnifier** that follows the stylus.
- **Rich text**: bold, italic, underline, alignment, font family, and size.
- **Search across all notes**, covering typed and recognized handwriting with accent-insensitive matching, from the library.
- **Page bookmarks**, go to page, and keyboard shortcuts.
- **Import PDF for annotation**, creating one note page per PDF page.
- **Local version history** and **night writing mode**.
- **New library** with side navigation, favorites, recent items, and grid and list views.
- **Marketplace** for free template, palette, and sticker packs with SHA-256 verification.
- **GPL-3.0-or-later** license.

### Fixed

- Cropped exports and thumbnails that displayed only one quarter of a sheet.
- Fixed sheets opening offset and the ruled-paper margin appearing in the center.
- Touch input becoming unresponsive after moving a selection with the stylus.
- A double tap with the stylus eraser deleting the page without an undo option.
- Rectangles being detected without a fourth side and ovals being forced into circles.
- Layer, shape, and setting loss when pasting, transforming, or filling, plus incorrect stroke order after undo.
- Local backups omitting notebooks and notes, non-atomic writes, and zip-slip exposure.

### Changed

- Centralized design system for theme, tokens, and colors, with remembered light and dark theme choice.
- Canvas performance improvements including culling, per-stroke caches, O(1) active-stroke handling, and template levels of detail.
