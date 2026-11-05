# 🌍 UI language

Not3 currently ships an English-only interface. `lib/l10n/app_en.arb` is the
single source of UI strings; unsupported system locales resolve to English.

## New text in code

Never hardcode literals in widgets: add the key to `app_en.arb` and use it with
`context.l10n.key`. After an `await` in a `State`, use `_l10n`. Visible errors:
throw `AppError(code)` and show them with `userError(l10n, e)`.

## What is not translated

Content stored in data (default titles, page/layer names) is translated when displayed with `displayTitle`; the marketplace's remote catalog and technical diagnostics/logs are left as they are.

## Style

Use a friendly, direct English tone. Keep interface terms consistent
(library/notebook/note/page, lasso, eraser, ruler).
