# 🏗️ Not3 Architecture

Technical guide for anyone who wants to contribute. Not3 is a handwriting app for tablets with a stylus (GoodNotes-style), **Flutter 3.47 / Dart 3.13**, Material 3, with an English interface and English source comments. Targets: **Android** (primary) + **Linux desktop** (development).

> How to contribute: [`CONTRIBUTING.md`](../CONTRIBUTING.md) · Design system: [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) · Translating: [`TRANSLATING.md`](TRANSLATING.md) · Publishing releases: [`RELEASING.md`](RELEASING.md) · Next steps: [`ROADMAP.md`](../ROADMAP.md)

## Commands

```bash
flutter pub get
flutter analyze            # must end with 0 issues
flutter test               # test/*.dart: models, storage, backup, encryption, canvas, history, l10n
flutter test integration_test -d linux   # end-to-end flows (also in CI with xvfb)
flutter gen-l10n           # after editing lib/l10n/*.arb (pub get/build do it too)
flutter run -d linux       # desktop development
flutter run                # connected Android tablet
flutter build apk --debug  # APK → build/app/outputs/flutter-apk/
tool/sync_android_icons.fish      # install pre-sized Android launcher icons
```

## Architecture (lib/)

```
models/      Notebook → Note → Page → Stroke/ImageItem/TextItem; PageTemplate, Layer,
             id.dart (newId: clock+counter+random). Document = LEGACY/migration ONLY.
             Stroke is IMMUTABLE: editing = creating another instance (copyWith/translated);
             caches pointBounds/paintBounds and stores thinning/smoothing/streamline (null = defaults)
             Page.bookmarked; TextItem with formatting (bold/italic/underline/align/fontFamily)
logic/
  canvas_controller.dart   ★ Central ChangeNotifier state (+ `part`: canvas_view = zoom/pan and
                             continuous scroll, canvas_selection = lasso/clipboard/transform,
                             canvas_layers = layers; mixins over `_CanvasCore`, which declares shared state):
                             tool/color/size, view,
                             active stroke, undo, pages (+bookmarks), saving, layers,
                             lasso selection (strokes + images + text), shapes
                             (ShapeMode: off/hold/always), laser, ruler, eraser (EraserMode)
  pen_presets.dart         favorite pens (3 + highlighter) with their own color/width, persistent
  palm_rejection.dart      pure palm-rejection policy (stylus resting/near, hover, contact)
  ruler.dart               pure ruler/protractor geometry (fixed on-screen size, snapping)
  stroke_engine.dart       perfect_freehand: polygon/Path per stroke cached with Expando
  eraser.dart              partial erase: splits the stroke into fragments (keeps order)
  undo_stack.dart          CanvasAction (+ strokeDiff with indices) and applyOrderedSwap (z-order)
  lasso.dart / bucket_fill.dart / shape_detector.dart / snap_guides.dart  pure geometry
services/
  storage_service.dart     ★ v2 index + notebooks/ + notes/; atomic writes, index
                             queue, corrupt-index recovery, full backup, favorites
  app_paths.dart           ★ SINGLE source of `<appSupport>/inklus` and subfolders (rootOverride in tests)
  error_log.dart           LOCAL error log (main.dart feeds it; Settings shares it)
  file_utils.dart          writeAtomic, writeJsonAtomic (isolate for large notes), safeJoin/
                             safeFileName, decodeJsonAsync, SerialQueue
  backup_crypto.dart       AES-256-GCM + PBKDF2 in an isolate
  search_service.dart      v2 search index per note (title, typed text, recognized
                             handwriting); accent-insensitive; shared SearchService.instance
  version_history_service.dart  local history: versions/<noteId>/<ms>.json.gz (max. 20)
  marketplace/             ★ marketplace_models.dart + marketplace_service.dart: catalog from a CDN
                             (cache and bundled catalog without network), install with sha256,
                             installed templates/palettes/stickers
  image_service.dart       copies files into the app + BoundedImageCache (LRU); the canvas decodes
                             to ≤ kCanvasImageMaxSide (2560 px); export uses imagesForExport
  export_service.dart      PNG/PDF/PPTX/SVG off-screen (reuses paintWorld)
  inklus_format.dart       ★ .inklus format (self-contained ZIP)
  drive_sync_service.dart  ★ Google Drive offline-first (drive.file)
  pdf_import_service.dart  importPages: one note page per PDF page
  import_service.dart      one-off import: detects .inklus v1/v2 or full
                             backup by CONTENT (accepts .inklus.zip renamed by Android)
  template_library_service.dart  "My templates" (your own images)
ui/
  theme/                   ★ app_theme.dart (light/dark ThemeData), inklus_colors.dart
                             (ThemeExtension + context.inklus/colors/text/isDark), tokens.dart
                             (Spacing, Radii, Motion, Sizes, Breakpoints)
  editor/                  editor_toolbar (single bar), tool_popovers (pen/eraser/color),
                             version_history_sheet (local copies + Drive revisions),
                             anchored_popover, selection_bar, pages_panel, editor_shortcuts,
                             tool_visuals (icon+name per tool)
  notebook_library.dart    home: side navigation (All/Recent/Favorites/Folders/
                             Marketplace), search (+ in content), grid/list
  marketplace_screen.dart  browse / install packs
  home_screen.dart         editor: EditorToolbar + canvas + SelectionBar + PagesPanel + zoom/pages
  canvas/                  drawing_canvas (input), world_painter (painting shared with export),
                             canvas_overlays (ruler, magnifier)
  widgets/                 controller_selector, dialogs (showTextPrompt, showConfirmDialog, runWithLoading),
                             search_sheet, custom_color_dialog, text_edit_overlay, inklus_logo,
                             page_scaffold (Not3Page, PageHeader, SectionCard, SettingsTile,
                             EmptyState, SheetHeader: base of secondary screens)…
l10n/ (lib/l10n)           English ARB (`app_en`) → AppLocalizations; `context.l10n.key`.
                             New text → the ARB. The app follows the
                             system language (`kAppLocale` only for screenshots/tests). Visible errors: throw
                             `AppError(code)` and show with `userError(l10n, e)`; services never return UI
                             text (use enums/`message(l10n)`). After `await`, in a State use `_l10n`.
integration_test/          end-to-end flows (`flutter test integration_test -d linux|tablet`)
docs/                      privacy.md (policy, linked in the app), testing.md (device script)
tool/screenshots/          screenshots of the real UI without a device (outside the test suite)
tool/stress/               generates build/inklus_stress.inklus (5,100 strokes + 10 photos) for profiling
marketplace/               template of the inklus-marketplace repo (validator + CI + examples)
```

## 🎨 UI rules

Summary in [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md).

## ★ Critical flows (don't break without tests)

### 1. Stylus and palm rejection — `drawing_canvas.dart` + `logic/palm_rejection.dart`
- A **raw** `Listener` receives ALL events (it doesn't take part in the gesture arena), including `onPointerHover` (stylus hover marks "stylus nearby").
- `PalmRejection` (pure, tested): a touch is discarded if the stylus is resting, hovering nearby, was lifted less than 400 ms ago, or if `radiusMajor` is large. When the stylus touches down, `_rejectPalmInProgress()` cancels any stroke/pan a finger was doing.
- Stylus state is updated **at the start** of `_onPointerUp/_onPointerCancel` (before any `return`): otherwise it stayed "resting" forever.
- `invertedStylus` or `kSecondaryStylusButton` (S-Pen button) = eraser for that stroke. There are **no** destructive stylus shortcuts.
- `controller.onStylusDetected()`: the first time it switches to *stylus only* (`fingerDrawingEnabled=false`, persisted); then **one finger scrolls** the page (`_oneFingerPans`) and two fingers zoom. Zoom is incremental (no jumps when fingers enter/leave).
- Ruler (`logic/ruler.dart`): fixed on-screen size; one finger drags it and a second finger rotates it (`_rulerPointers`); the stroke snaps to an edge only if it **starts** within <26 px of it (`RulerGeometry.snapFor/project`).
- Fixed sheet: `_setView` clamps panning with `clampToWorldRect` (the sheet —and its stacked neighbors— never
  goes out of view); infinite canvas has no limit.
- **Continuous scrolling** (`continuousScroll`, persistent pref): fixed sheets are stacked
  (`_neighbor(±1)`, `pageGap` spacing); `CanvasPainter.neighbors` paints them (only the first sheet
  paints the desktop: `paintWorld(paintDesk:)`). When the view center enters a neighbor,
  `_enterNeighborPage` makes it current by shifting `translate` by the same amount (no jump); `beginStroke`
  adopts the neighbor if the stroke starts on it. Undo is **per page** (`_undoStacks[page.id]`).
- Conversion: `world = (local - translate) / scale` (controller methods `viewportToWorld`/`worldToViewport`). The fixed sheet is **centered at the world origin** (`fitView`, `paintWorld`, export and ruler assume it).

### 2. Paint layers — `drawing_canvas.dart` (CanvasPainter / ActiveLayerPainter)
- **Confirmed layer** (template+images+strokes) inside a `RepaintBoundary`. Its `shouldRepaint` compares `contentVersion` (incremented in `_touch()`) + `scale`/`translate`/`sheetSize`/`imageCache`: if only the active stroke changes, it does NOT repaint (that's where the optimization lives).
- **Pan/zoom by composition**: while `_viewGesture` (pan/zoom) is active, `CanvasPainter` draws a `ViewSnapshot` (`toImageSync` of the view at the start) transformed, and paints live only the uncovered strips (`uncoveredStrips`); it retakes it if the content changes or the zoom varies ×1.6, and releases it on release (crisp repaint). Any other gesture that moves the view continuously must enable `_transforming`.
- **Active layer** (in-progress stroke, eraser cursor, selection) on top, `shouldRepaint => true` always. The in-progress stroke uses a mutable point list (adding = O(1)); on release it is frozen (`List.unmodifiable`).
- `page` is mutated in place (the instance is never replaced), which is why versioning is by counter, not identity. `_touch()` = real change (repaints + schedules save); `_touchLive()` = live drag (repaints only; saved on commit).
- `paintWorld` does **culling** with `stroke.paintBounds` and applies layer opacity with a `saveLayer` per layer segment (`_LayerPainter`). The image cache exposes `version` so `CanvasPainter` repaints when decoding finishes.
- The editor does NOT rebuild the screen on every point: `ControllerSelector` + granular notifiers (`toolContextNotifier`/`bottomBarContextNotifier`, which `notifyListeners()` only fires if what they show changed).

### 3. Undo/redo — `undo_stack.dart` + `canvas_controller._applyAction`
- Each operation pushes a `CanvasAction` with `strokesAdded/Removed` + `imagesAdded/Removed` + `textItemsAdded/Removed`. `_applyAction` uses `applyOrderedSwap`: if an added item has the same id as a removed one it is replaced **in its position**; if the action carries `strokesRemovedAt/AddedAt` (eraser, delete selection → `CanvasAction.strokeDiff`) it is reinserted by index. Never `addAll` at the end (it would change the z-order). Images: `updateImageLive` during the drag (no action) and `commitImageChange(before, after)` on release (a single action).
- When creating derived strokes ALWAYS use `copyWith`/`translated` (they keep layer, shape, fill and settings); a hand-built `Stroke(...)` loses attributes.

### 4. Export — `export_service.dart`
- `paintWorld` (in `world_painter.dart`) paints template+images+strokes in a given rect; the canvas calls it with the transformed visible rect and export with the content rect → what you see = what you export.
- `renderPagePng` MUST do `canvas.translate(-bounds.left, -bounds.top)`: bounds start negative (centered sheet). There is a regression test (`test/export_test.dart`).
- `paintWorld(viewScale:)`: constant on-screen template line width and level of detail (`_lodSpacing`) for infinite patterns when zooming out.

### 5. Editor, pens and selection
- `EditorToolbar`: tapping a tool activates it; tapping it **again** opens its popover.
- `PenPresetsController.activate()` applies a pen (with an `_applying` guard so it doesn't copy the
  previous color); `HomeScreen` listens to `bottomBarContextNotifier` and calls `syncFrom` to save changes.
- Lasso: strokes by instance, images and text **by id**; move/scale/rotate save a snapshot on the
  first frame and `commitMoveStrokes`/`commitTransformSelection` push a single action with all three
  types (text doesn't rotate: it only moves). Copy/paste/duplicate: all three types. Color and width:
  strokes only. Handles come from `selectionHandles` (same source for painting and hit-testing).
- Trash (`StorageService.loadTrash` → `TrashEntry`): notebooks (their notes travel in `noteIds`, not
  loose), loose notes (marked `_trash.notebookId` → they return to their notebook) and legacy; `_trash.deletedAt`
  (or the file date) and automatic purge after 30 days.

### 5b. Rich text (text boxes)
- `TextItem.runs` (`TextRun` in `models/text_item.dart`): per-range formatting `[start,end)` on top of the box's; `applyRunStyle`/`adjustRunsForEdit` are pure (tested). `models/text_layout.dart` = **single source** of style/height (`textItemStyle`, `buildTextItemSpan`, `measureTextItemHeight`): canvas, export and editor share it. Fonts bundled in `assets/fonts` (OFL in `third_party_licenses/`).
- `TextEditOverlay` is a **sibling** (not a child) of the canvas `Listener` in `DrawingCanvas`: if it were a child, tapping its bar would reach the page (the original bug). It's a real `TextField` with `RichTextController` (readjusts runs on every text change); the bar acts on the selection (or the whole box when there's no selection) and lives in `TextFieldTapRegion` + `ExcludeFocus`. Top edge fixed while typing (`_topWorld`).
- Undo: `addTextItem` doesn't push an action; `commitEditingText()` (idempotent) pushes ONE (add/replace/remove). With the text tool, tapping an existing box edits it (`textItemAt`).
- Shapes: the highlighter only straightens straight lines (`ShapeDetector.detect(lineOnly:)`, larger tolerance); every nearly horizontal/vertical line snaps to the axis (±4°, highlighter ±8°).

### 6. Marketplace and search
- `MarketplaceService.validatePack` = rules from `marketplace/bin/build_catalog.dart` (keep them identical).
- Install: download → check size and sha256 → `writeAtomic`; if anything fails the pack is deleted.
- `SearchService.indexNote` on opening/leaving a note; recognized handwriting (OCR, "Index
  handwriting", "Convert to text") is stored with `setHandwriting` and preserved on reindex.
- OCR: `OcrService` receives `languageCode` on all its entry points. `services/ocr_language.dart`
  defines the three languages (`en`, `ja`, `th`), the bitmap-fallback script and the last choice
  (`SharedPreferences`, `ocr_ink_language`). The sheet `ui/widgets/ocr_language_sheet.dart` asks
  for confirmation before downloading a model; `th` has no fallback (ML Kit doesn't support it in bitmap).

### 7. Sync — `drive_sync_service.dart` (Google Drive, offline-first)
- **Singleton** `DriveSyncService.instance` (`ChangeNotifier`): the session is shared between library and editor; the ☁️ listens with `Listenable.merge([controller, service])`.
- `signIn()`: `GoogleSignIn.instance.authenticate(scopeHint: [drive.file])`. The **access token does NOT come in `authentication`** (v7 only brings idToken): it's requested with `account.authorizationClient.authorizeScopes([drive.file])` (interactive) or `authorizationForScopes` (silent, may return null).
- Every call to `GoogleSignIn.instance` is preceded by `await _ensureInitialized()` (`initialize(serverClientId:)` once; retryable if it fails).
- `restoreSession()` (silent, One Tap) is called on startup in `NotebookLibraryScreen`.
- `restoreLibrary(storage)` (Settings → "Restore from Drive"): last-write-wins per note; ones that don't exist locally go to a new notebook "Recovered from Drive". `_BearerClient` applies a 60 s timeout.
- Backup: `Not3/<Notebook>/<Note>.inklus` in Drive (a folder per notebook and a file per note, both identified by `appProperties` `notebookId`/`noteId`, not by name: renaming only renames; old `<id>.inklus` copies at the root are located and relocated on upload). `restoreLibrary` returns each note to its notebook according to the folder. ☁️ status per note **and** per notebook. `lastSignInIssue` stores the detail when Android reports "cancelled" (usually an unregistered SHA-1) and the UI shows it. Upsert, doesn't duplicate in the app's own `Not3Format` (document + **embedded images** → the backup is self-contained). Restore: lists the folder, imports each `.inklus` (extracts images to `<appSupport>/inklus/restored/<id>/`) and picks the most recent by `updatedAt`. `googleapis` 16 (`drive/v3.dart`): `files.create/update` with `uploadMedia: commons.Media`; download with GET `alt=media` via `_BearerClient` (http).
- Automatic backup = silent (if the scope isn't authorized it's skipped, local already protects you); 'Upload now' uses `promptForConsent: true` (may show consent).
- The UI finds out via `controller.onRemoteSync` (callback on every local save; `HomeScreen` batches it: at most one upload every 20 s + on exit) and `controller.replaceNote(note)` after restoring.
- Leaving the editor: `_goBack()`/`PopScope` do `await controller.flush()` before the `pop` (the library reads the already-updated index); `HomeScreen.dispose` does `controller.dispose()`.
- Export (editor ⋮ menu): page PNG/PDF, **notebook PDF** (`renderNotebookPdf`) and **.inklus copy** (`Not3Format.exportBytes` → `FilePicker.saveFile`).

## 🔐 Secrets

- Never read/print/write passwords from `android/key.properties`, or `client_secret*.json`. For fingerprints use `keytool -list` passing the password via command substitution and filtering only `SHA1`.
- OAuth Client IDs and SHA-1 are public. The Manifest sets `allowBackup=false` and `usesCleartextTraffic=false` (everything is https). CI has the `secret-scan` job (gitleaks).

## 🚨 Version gotchas (already resolved, don't revert)

- **file_picker 12**: static API — `FilePicker.pickFiles()` → `List<PlatformFile>`, `FilePicker.pickFile()` → `PlatformFile?`, `FilePicker.saveFile({fileName, bytes})` → `Uri?`. `FilePicker.platform` **does not exist**.
- **google_sign_in 7**: requires `GoogleSignIn.instance.initialize(serverClientId: <web client>)` **once and awaited** before any other call (otherwise: "serverClientId must be provided"). `GoogleSignIn.instance.authenticate({scopeHint})` / `attemptLightweightAuthentication()` (One Tap). `authentication` only brings `idToken`; the access token is requested with `authorizationClient.authorizeScopes/authorizationForScopes`. `default_web_client_id` is **manually** in `android/app/src/main/res/values/strings.xml` (google-services no longer generates it; don't use Firebase).
- **googleapis 16 / `_discoveryapis_commons`**: `drive.DriveApi(client)` with `uploadMedia: commons.Media(Stream.value(bytes), len, contentType:)`; `files.update(File request, String fileId, ...)` (the request goes first!). googleapis_auth doesn't export its `AuthenticatedClient` → use your own `_BearerClient` over `http`.
- **No Firebase**: the app doesn't initialize or depend on Firebase (it was removed). If reintroduced, `main.dart` must call `Firebase.initializeApp()` before touching `FirebaseAuth.instance` (the cause of the startup crash).
- **perfect_freehand 2.5.2**: `getStroke(List<PointVector>, options:)` → `List<Offset>` (polygon). `StrokeOptions` has `size/thinning/smoothing/streamline/simulatePressure/start/end/isComplete` (no `roughness`). In `stroke_engine.dart` it's imported with `hide StrokePoint` (collision with our model).
- **pdf 3.x**: `pw.Document`, `pw.Page(pageFormat: PdfPageFormat...)`, `pw.MemoryImage(pngBytes)`.
- **Google Drive API** must be enabled in the Google Cloud project (`inklus`) and the `drive.file` scope on the OAuth consent screen; without that, sign-in returns `403 accessNotConfigured`.
- Flutter's `MaterialApp` exports `Page` (navigator): wherever our `models/page.dart` is imported alongside material, use `hide Page`.

## Data model (JSON)

`Notebook{id,title,noteIds[],color,coverStyle,coverImagePath,tags}` → `Note{id,title,createdAt,updatedAt,pages[]}` → `Page{id,name,template,strokes[],images[],textItems[],layers[]}` → `Stroke{id,tool,color,size,points[{x,y,p}],fillColor,layer,shape,th,sm,sl}` (`Document` = legacy format, migration only), `ImageItem{id,path,x,y,w,h,rotation,layer}`, `TextItem{id,x,y,w,text,fontSize,color,layer}`, `PageTemplate{type,lineColor,spacing,imagePath,infiniteFill,customW,customH}`, `Layer{name,visible,locked}`. Strokes and images in **world coordinates**; layers filter visibility.

## Business rules

- The **library** (`NotebookLibraryScreen`) is the home screen → `NoteListScreen` → `HomeScreen(note:, notebookId:)`, which receives the already-loaded `Note` (it doesn't read it from disk). On return, the index and thumbnails are refreshed.
- `StorageService`: `index.json` (`formatVersion: 2`, metadata by `updatedAt`) + `notebooks/<id>.json` (only `noteIds`) + `notes/<id>.json`. Every write goes through `writeAtomic`; every index modification through `_updateIndex` (serialized queue). Notebook changes that don't touch content (create/rename/duplicate/delete note, title, color, tags) go through `_editNotebook` (only `notebooks/<id>.json` + index, **without** loading or rewriting the notes); `saveNotebook` rewrites everything and is only for new/imported notebooks. `saveNote` calls `touch()` **before** writing (`touch: false` for restored copies: they keep their date). `.inklus`: v2 = has `notebook.json`; v1/loose note = `document.json` (it also carries `format.json`, don't use it for detection). Images live in shared `inklus/images/`; `collectOrphanedImages` deletes unreferenced ones (active notes, trash and versions) with a 10-minute grace period.
- Migration: `current_document.json` or a v1 index (`documents/`) are automatically converted to Notebook+Note.
- Infinite canvas: `blank/ruled/grid/custom+infiniteFill` templates; finite sheet: `sheet/custom without fill` (content cropped to the sheet).
- `fitView` centers the finite sheet or sets zoom 1.0 on infinite ones.

## Design decisions (made; open an issue before proposing changes)

- **Everything free, no premium.** Not3 is open source and will have no paid features. GoodNotes/Samsung Notes/Notability premium features are implemented here for free.
- **Drive conflicts: last-write-wins**. When two devices edit the same notebook, the document with the most recent `updatedAt` wins. It's simpler than per-page merge and avoids unintentional content loss. The user can see all versions in Drive (☁️ menu → "View versions") and restore whichever they want.
- **Backup encryption: AES-256-GCM + PBKDF2-HMAC-SHA256 (100k)** with `cryptography` (it replaced the original XOR). Format `[salt 16][nonce 12][ciphertext][tag 16]`, in `BackupCrypto`. The key is derived from the UTF-8 bytes of the password; decryption retries with `codeUnits` to open old backups.
- **Selective sync**: `NotebookMeta.syncEnabled` (null = true by default for compatibility). Automatic backup only uploads notebooks with sync enabled.
