# Lasso Selection Filter Plan

## Goal

Let the lasso choose which kinds of page content it can select instead of
always selecting every object inside the drawn boundary. The available
filters will be:

- Handwriting and drawing strokes
- Highlighter strokes
- Text boxes
- Images

The wording "highlight, text, or image" is interpreted as content-type
filtering. Handwriting remains available because moving handwriting and OCR
are existing lasso workflows. Highlighter is kept separate so it can be
selected without also moving the writing underneath it.

Users may enable one or several filters. At least one filter must remain
enabled.

## Current behavior

`CanvasController.endLasso()` currently selects every visible eligible stroke,
plus every unlocked image and text box whose center lies inside the lasso.
There is no selection policy or toolbar UI for choosing content types. After a
successful lasso, the controller changes to the select tool and the existing
selection bar operates on the mixed selection.

## User experience

1. Tapping Lasso activates it as today.
2. Tapping the active Lasso button again opens a small anchored settings
   popover.
3. The popover shows four independent toggles: **Handwriting**,
   **Highlighter**, **Text**, and **Images**.
4. The chosen filters apply to the next lasso and remain active until changed.
5. Drawing a lasso selects only enabled content types. Disabled content inside
   the boundary is untouched and is not included in the selection bounds,
   count, copy, delete, move, scale, or rotate operations.
6. The selection action bar remains context-sensitive: OCR/color/thickness are
   shown only when the resulting selection contains compatible strokes.

Default all four filters to enabled so existing users do not lose current
behavior after upgrading.

## Implementation

### 1. Model the filter state

- Add an immutable `LassoSelectionFilter` value with booleans for handwriting,
  highlighter, text, and images.
- Store the current filter in `CanvasController` and expose it through a
  read-only getter.
- Add explicit toggle/update methods that prevent the final enabled type from
  being disabled.
- Persist the filter through `SharedPreferences`, alongside the other editor
  input/tool preferences. Treat missing or invalid saved data as "all
  enabled."
- Notify `toolContextNotifier` when the filter changes so the toolbar popover
  and accessibility state update without repainting unrelated document state.

### 2. Filter during lasso hit-testing

Update `endLasso()` in `canvas_selection.dart` so filtering happens before an
object enters selection state:

- `ToolType.highlighter` is controlled only by the highlighter filter.
- Normal drawable stroke tools are controlled by the handwriting filter.
- Text IDs are collected only when the text filter is enabled.
- Image IDs are collected only when the image filter is enabled.
- Existing hidden-layer and locked-layer rules remain unchanged.
- Eraser, select, and lasso pseudo-strokes remain ineligible.

Filtering at hit-test time keeps `selectionCount`, `selectionBoundsAll`, undo,
clipboard operations, transforms, and drawing overlays correct without adding
special cases downstream.

### 3. Add the Lasso settings popover

- Change the Lasso toolbar button to use the existing "tap active tool again"
  anchored-popover pattern used by Pen and Eraser.
- Add a compact `LassoPopover` in `tool_popovers.dart` with one checkbox or
  switch per content type.
- Use icons that distinguish handwriting, highlighter, text, and images.
- Include semantic labels, selected state, and a disabled state for the last
  enabled option.
- Keep the popover usable at narrow phone widths and in light/dark themes.

### 4. Keep selection actions type-aware

- Continue showing copy, duplicate, delete, and deselect for any selected
  content.
- Show recolor, thickness, and OCR only when compatible strokes are selected.
- Ensure an image-only or text-only selection never exposes stroke actions.
- Decide separately whether text recoloring belongs in the text editor; do not
  overload the lasso stroke-color action in this change.

### 5. Tests

Add controller tests covering:

- all filters enabled preserves current mixed selection behavior;
- handwriting-only excludes highlighter, text, and images;
- highlighter-only excludes handwriting underneath it;
- text-only and image-only select only their respective item type;
- combined filters select the expected union;
- hidden and locked layers remain excluded;
- at least one filter must remain enabled;
- filter persistence and invalid preference fallback;
- selection bounds/count and copy/delete/undo contain only filtered objects.

Add widget tests covering:

- second tap on active Lasso opens the filter popover;
- toggles update controller state and remain accessible;
- the last enabled toggle cannot be turned off;
- image-only/text-only selections hide stroke-only actions;
- no toolbar overflow at the compact and reference widths.

Finally run analysis, the focused lasso/controller/widget tests, and the full
Flutter test suite. Generate light and dark screenshots of the Lasso popover
for visual review; build an APK only when explicitly requested.

## Completion criteria

- A user can constrain lasso selection to any non-empty combination of the
  four content types.
- Highlighter can be selected independently from handwriting beneath it.
- Disabled content never enters any selection operation.
- Existing mixed-selection behavior remains the default.
- Filter choice survives an app restart.
- Existing move, transform, clipboard, OCR, undo, and redo behavior continues
  to pass tests.
