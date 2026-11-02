# 🎨 Not3 Design System

Goal: every screen should feel like the same product, at the level of GoodNotes/Notability. Code lives in `lib/ui/theme/` and `lib/ui/widgets/`.

## Pieces

| What | Where |
|---|---|
| Light/dark `ThemeData` (Material 3, `fidelity` scheme) | `ui/theme/app_theme.dart` |
| Custom colors (`context.inklus`, `context.colors`, `context.text`, `context.isDark`) | `ui/theme/inklus_colors.dart` |
| Measurements: `Spacing`, `Radii`, `Motion`, `Sizes`, `Breakpoints` | `ui/theme/tokens.dart` |
| Secondary screens: `Not3Page`, `PageHeader`, `SectionCard`, `SettingsTile`, `EmptyState`, `SheetHeader` | `ui/widgets/page_scaffold.dart` |
| Dialogs: `showConfirmDialog`, `showTextPrompt`, `runWithLoading` | `ui/widgets/dialogs.dart` |

## Rules

1. **Colors** only from `context.colors` (`ColorScheme`) or `context.inklus`. No `Colors.white` / `Color(0x…)` in widgets. Exception: colors that are **content** (covers `kCoverColors`, tags, template lines, color picker, canvas).
2. **Measurements** only from `Spacing`, `Radii`, `Sizes`, `Motion`. Touch target **≥ 48 dp**.
3. **Text** with the roles from `context.text` (tablet-adjusted scale). Nothing below **12 pt**; respect the system `textScaler`.
4. **Secondary screens** with `Not3Page` + `SectionCard`/`SettingsTile`/`EmptyState`. Bottom sheets with `SheetHeader` (the handle is added by the theme). Confirmations with `showConfirmDialog`.
5. **Tool options**: common drawing controls (recent colors and quick stroke sizes) may live in
   the editor tool row; complete palettes, sliders and advanced settings stay in anchored popovers
   (`showAnchoredPopover`).
6. **Rebuilds**: widgets that depend on the controller use `ControllerSelector` with the minimum value they display (the controller notifies on every stroke point).
7. **Visible text** always through l10n (`context.l10n`); see [`TRANSLATING.md`](TRANSLATING.md). Long text must not overflow: flexible cells, `Flexible`/`maxLines` + ellipsis.
8. **Accessibility**: `Semantics`/`tooltip` on icons without text, swatches, covers and thumbnails; enough contrast in light and dark.

## "Premium" checklist for a UI PR

- [ ] Tokens instead of literals; no text < 12 pt or targets < 48 dp
- [ ] Light and dark reviewed
- [ ] Long English labels do not overflow; text scale 1.3 does not break layouts
- [ ] Empty, loading and error states present
- [ ] Press feedback and transitions with `Motion` (no abrupt animations)
- [ ] Screenshots with `flutter test tool/screenshots/screenshots_test.dart`

## Brand and icon

- **Icon**: a white nib writing a golden stroke over a blue gradient (`#5B8CFF → #2A4FD6`, ink `#FFD66B → #FF9F43`). Vector source in `assets/icon/` (`icon_full.svg`, `icon_foreground.svg`, `icon_background.svg`); the `flutter_launcher_icons` PNGs come from there with `rsvg-convert`.
- **README**: `docs/assets/icon-animated.svg` (the nib writes the stroke in a loop) and `docs/assets/anim/*.en.svg` (pressure, palm rejection, shapes, lasso). They are hand-written SVG/SMIL and **generated** by `tool/docs_assets/generate.py` (no dependencies; edit the script, not the SVGs).
- A new animation is a `scene_*` function in the script with its own background, which must look correct in light and dark themes, and English text in `TXT`.
