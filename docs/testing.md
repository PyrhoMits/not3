# Device testing (before every release)

The automated tests (`flutter test`, screenshots and `integration_test`) cover data, logic and the main flows. Everything that depends on the **real stylus, the screen and the network** must be checked by hand on a tablet. This script takes about 15 minutes.

**Reference devices:** Galaxy Tab S (S-Pen), a tablet with a USI stylus and a phone (no stylus).

## 0. Installation

- [ ] The release APK (signed) installs **on top of** the previous version without losing notes.
- [ ] Settings shows the correct version.

## 1. Writing and stylus

- [ ] Write with the stylus: stroke with no visible lag, with pressure variation (pen, brush).
- [ ] Rest your palm while writing: it leaves no marks.
- [ ] Once the stylus is detected, one finger scrolls the page and two fingers zoom without jumps.
- [ ] S-Pen side button / stylus eraser: erases while held.
- [ ] Holding the stylus still at the end of a shape straightens it (line, rectangle, circle).
- [ ] Ruler: drags with one finger, rotates with two, the stroke sticks to the edge.

## 2. View (performance)

Import the stress notebook (`flutter test tool/stress/stress_note_test.dart` → `build/inklus_stress.inklus`) and open it with `flutter run --profile` (key `P` to see the frame graph):

- [ ] Scroll and zoom on the page with 1,700 strokes: smooth; it looks crisp on release.
- [ ] While scrolling, no lines or jumps appear between the "frozen" area and the one drawn live.
- [ ] Page with 5 12 MP photos: opens and moves without memory-related crashes.
- [ ] Fixed sheet: when dragged far, the sheet stops near the edge.

## 3. Selection

- [ ] Lasso around strokes + image + text: move, scale (bottom-right handle) and rotate (top handle); undo reverts it in one step.
- [ ] Copy and paste the selection: it appears offset and selected.

## 4. Data

- [ ] Force-close the app right after writing: when you come back, the stroke is there.
- [ ] Delete a note and restore it from the Trash: it returns to its notebook.
- [ ] Export a full backup, import it (Settings → Import): notebooks intact.
- [ ] Export page PNG/PDF and notebook PDF (high quality): the photos are visible.

## 5. Google Drive (with the test account)

- [ ] Connect: no `DEVELOPER_ERROR` (the APK's SHA-1 fingerprint is registered).
- [ ] Write, leave the editor: the note is uploaded (green ☁️).
- [ ] Version history: local copies and Drive revisions appear; restoring one works.
- [ ] On another device: Settings → Restore from Drive brings the notes over.

## 5b. Handwriting OCR (Android/iOS)

- [ ] Lasso → "Convert to text": the sheet with English / 日本語 / ไทย appears.
- [ ] An already-downloaded language recognizes directly, without a download dialog.
- [ ] A language without a model asks for confirmation; Cancel doesn't download or recognize.
- [ ] Without Wi-Fi, the download fails with a clear warning (the plugin requires Wi-Fi).
- [ ] Thai with a model recognizes Thai; without a model and offline it shows the error (it doesn't fall back to Latin).
- [ ] Page "Recognize text" and "Index handwriting" use the last chosen language.
- [ ] After restarting the app, the last language is remembered.

## 6. Theme and accessibility

- [ ] Dark mode: all screens legible (library, notes, settings, trash, stats, sheets).
- [ ] Reminder date picker in Spanish.

Note the device, the Android version and any failure in an *issue*; if the app crashed, attach Settings → Error log → Share.
