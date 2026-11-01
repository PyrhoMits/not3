# Not3 — Rework plan (foundation, community and premium UI)

> Status (2026-10-15): **Phases A–D executed**; *Round 2* and the items marked "pending" below remain. Audit from 2026-10-14. Handover document: whoever picks the work back up can start here. Technical context in `ROADMAP.md`; architecture in `docs/ARCHITECTURE.md` (Phase A creates it from the current technical guide).

## Goal
Get Not3 ready for contributors and make the library, covers and editor bar feel like a premium product (GoodNotes/Notability level), while keeping it: free, offline-first, GPL-3.0-or-later, multilingual.

## Project rules (apply to every run)
- Everything under the maintainer's name (Pedro, `Pedroj-64`) with their git/gh identity. No trailers or mentions of code-generation tools in commits, PRs, docs or code.
- Don't commit/push/PR without an explicit request from the maintainer.
- Never check in secrets (`key.properties`, `*.jks`, `client_secret*.json`).
- Target languages: es, en, pt-BR, fr, de. New text always through ARB (`context.l10n`).
- Git history: don't rewrite (decided).

> **Pending from phases A–D:** `Hero` card→editor (not done: the editor is a heavy canvas, it has no equivalent destination element); native pt/fr/de review; pt/fr/de READMEs (es/en left); default titles stored in data ('Untitled'); a `dart format` pass (the repo isn't formatted and doing it would dirty the history).

## Phase A — Cleanup and governance (without touching app code)
1. **Clean the tree**: `ROADMAP.md` (lines 3 and 5, "for the AI" → "for contributors"); `.gitignore` (assistant block, L154-187: leave neutral rules; local stuff goes to the developer's global ignore); delete `.github/modernize/`; `AGENTS.md` leaves the repo and its content moves to `docs/ARCHITECTURE.md`, written as a contributor guide.
2. **Community files** (es/en wherever public):
   - `CONTRIBUTING.md` (+ `.es.md`): setup, `flutter analyze` at 0, tests, Conventional Commits, branches, DCO (`Signed-off-by`, no CLA), PR flow, how to translate.
   - `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `SECURITY.md` (private report via GitHub Security Advisories), `SUPPORT.md`, a short `GOVERNANCE.md` (lead maintainer, how decisions are made), `CODEOWNERS`.
   - `.github/ISSUE_TEMPLATE/{bug,feature,translation}.yml` + `config.yml`, `.github/pull_request_template.md`, `dependabot.yml`.
   - License: keep GPL-3.0-or-later; document OFL fonts (`third_party_licenses/`) and the CC0/CC-BY rule for the marketplace.
3. **Docs**: `docs/ARCHITECTURE.md`, `docs/DESIGN_SYSTEM.md` (tokens, UI rules, premium checklist), `docs/TRANSLATING.md`, `docs/RELEASING.md` (signing, tags, CHANGELOG; no secrets). Link them from both READMEs. Reduce `ROADMAP.md` to status + upcoming rounds.

## Phase B — Safe data
- `WidgetsBindingObserver` → `flush()` on `paused/inactive/detached` (`lib/logic/canvas_controller.dart`, `lib/ui/home_screen.dart`).
- Visible warning if saving fails (today it's only `debugPrint` in `saveNow`); route the critical `catch (_)` blocks in `storage_service.dart` to `ErrorLog`.
- Per-note `schemaVersion` (`Note.toJson/fromJson`) with a trivial migration and a round-trip test.
- `analysis_options.yaml`: `strict-casts`, `strict-raw-types`, `unawaited_futures`, `use_build_context_synchronously`, `prefer_const_constructors`; fix whatever comes up without suppressing it.

## Phase C — UI consistency and premium feel
Reuse `ui/theme/tokens.dart`, `inklus_colors.dart`, `ui/widgets/page_scaffold.dart`, `dialogs.dart`.
1. Delete dead code `lib/utils/design_tokens.dart` and `lib/utils/theme_colors.dart`.
2. New tokens: elevations/shadows (today 6 loose `BoxShadow` and 12 `elevation:`) and text roles for the ~58 inline `fontSize:`; unify the brand blue (`app_theme.dart:19` 0xFF3B6FF6 vs `constants.dart:135` 0xFF3B82F6; `kAccentDark`).
3. Migrate to tokens: `create_notebook_screen.dart` (45 literals), `template_picker_sheet.dart` (36), `notebook_library.dart` (17), `custom_color_dialog.dart`, `layers_sidebar.dart` (L160 breaks dark mode). Remove text <12 pt and targets <48 dp.
4. Single components: library uses `EmptyState`; sheets with `SheetHeader`; card menu with `MenuAnchor` (`note_list_screen.dart:339`); a single snackbar helper; `showConfirmDialog/showTextPrompt` with mandatory l10n labels.
5. **Elegant notes**: covers with a page-1 thumbnail or title plate (bundled fonts), title color with automatic contrast, painter radius = card radius, layered shadows, `Hero` card→editor, press feedback and haptic; floating rounded editor bar with its own glyphs (nib, width and color live); `textScaler` and flexible cells; max content width on wide screens; semantics on swatches, covers and thumbnails.
6. Visual verification: `flutter test tool/screenshots/screenshots_test.dart` in light/dark, es/en and a long language (de).

## Phase D — Multilingual
- Add `app_pt.arb` (pt-BR), `app_fr.arb`, `app_de.arb` from `app_es.arb` (603 keys). Extend `test/l10n_test.dart` to all five languages.
- Move the remaining literals to l10n (`Half Ltr`, `Hex`, names in `kCoverColors`). Default titles stored in data ('Untitled', 'My notebook') remain documented debt: neutral key + migration in a later round.
- Minimal pt/fr/de READMEs or leave es/en and ask for community help in `docs/TRANSLATING.md`.

## Round 2 (later)
Ink latency (`getCoalescedEvents`, predicted points, incremental active stroke, pressure curve/calibration); split `StorageService` (1,606 lines) and `HomeScreen` (1,783 lines); tests for eraser, lasso, undo, painters with goldens; vector PDF; full accessibility; marketplace with real content.

## Verification
- `flutter analyze` → 0 issues; `flutter test`; `flutter test integration_test -d linux`.
- Light/dark screenshots and a manual walkthrough library → notebook → editor (`flutter run -d linux`); tablet test according to `docs/testing.md`.
- Search the tree (excluding `.git`, `build`, `.dart_tool`) for mentions of code-generation tools or "the AI" with no results, except on-device handwriting recognition (ML Kit), which is legitimate.

---

# Appendix — Audit findings (2026-10-14)

## Governance
- Present: `LICENSE` (GPL-3.0), `CHANGELOG.md`, `ROADMAP.md`, `docs/{privacy,testing}.md`, `third_party_licenses/` (8 OFL), `marketplace/`, CI in `.github/workflows/ci.yml`.
- Missing: CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, SUPPORT, GOVERNANCE, CODEOWNERS, issue/PR templates, dependabot.
- Seven old commits (v1.1–1.3) carry automatic trailers from an external tool; they're left as they are (don't rewrite history).
- i18n (at audit time): only es/en, 603 keys each; now there are 5 languages with parity required by `test/l10n_test.dart`.

## Code and canvas
1. No autosave flush when the app pauses → the last strokes can be lost (<600 ms).
2. `saveNow` only does `debugPrint` on failure; 19 silent `catch (_)`.
3. No per-note `schemaVersion`.
4. Ink: no `getCoalescedEvents` or predicted points; pressure 0/>1 → 0.5, no curve or tilt; `getStroke` recomputes the whole active stroke every frame (`world_painter.dart:466-476`); `CanvasPainter.shouldRepaint` creates lists on every call (`drawing_canvas.dart:230-241`).
5. Large files: `home_screen.dart` 1,783, `storage_service.dart` 1,606, `canvas_controller.dart` 1,544, `drawing_canvas.dart` 1,273, `notebook_library.dart` 1,195.
6. No tests for: eraser, lasso, undo_stack, bucket_fill, stroke_engine, painters (no goldens), Drive, OCR, PDF.
7. Only `flutter_lints`; raster PDF import/export; `cupertino_icons` and `_discoveryapis_commons` possibly unnecessary; the only TODO is in `world_painter.dart:61`.

## UI
- Existing design system: `ui/theme/{app_theme,inklus_colors,tokens}.dart`, `ui/widgets/{page_scaffold,dialogs}.dart`. Adoption: Spacing 211 uses, Radii 37, Motion 7; ~58 inline `fontSize:`, ~69 `Color(0x..)`, 51 `Colors.x`.
- UI rule violations: `layers_sidebar.dart:160`, `text_edit_overlay.dart:295,712`, `notebook_library.dart:968`, `create_notebook_screen.dart:449,463`, `template_picker_sheet.dart:806`, `tool_popovers.dart:298,351`. Text <12 pt: `note_list_screen.dart:509`, `layers_sidebar.dart:195,286`, `custom_color_dialog.dart:61,82`, `template_picker_sheet.dart:374,907`. Targets <48 dp: `editor_toolbar.dart:382`, `notebook_library.dart:986`.
- Inconsistencies: duplicated empty state (`notebook_library.dart:750-821`); sheets without `SheetHeader` (`notebook_library.dart:293,455`, `home_screen.dart:659,1408`, `template_picker_sheet.dart`); `MenuAnchor` vs `PopupMenuButton`; hardcoded 'OK/Cancel' in `dialogs.dart:19-20,113-114`; ~33 snackbars without a helper.
- Gaps vs GoodNotes/Notability/Samsung Notes: covers without thumbnail or materials, no `Hero`, non-floating bar, generic icons, no multi-select or drag-to-folder, no `textScaler`, no max width, incomplete semantics.

## References (ideas only; respect licenses)
Saber (Flutter, GPL-3.0, github.com/saber-notes/saber), Xournal++ (`.xopp` format, audio, LaTeX), GoodNotes and Notability (UX). Flutter and DevTools as models for CONTRIBUTING and CODE_OF_CONDUCT.
