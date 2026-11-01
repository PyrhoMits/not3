# 🌍 Translating Inklus

The app follows the system language. Languages: **es** (source), **en**, **pt** (Brazilian Portuguese, `app_pt.arb`), **fr** and **de**; anything else falls back to English (`resolveAppLocale` in `lib/app.dart`). The pt/fr/de translations are a first draft: corrections from native speakers are very welcome. You don't need to know Dart: just edit an `.arb` file (JSON).

## Fixing a translation

1. Open `lib/l10n/app_<language>.arb`.
2. Edit the value (not the key). Keep the `{name}` placeholders and the plurals `{n, plural, one{…} other{…}}`.
3. Open a PR (or a translation issue with the key and the proposed text).

## Adding a language

1. Copy `lib/l10n/app_es.arb` to `lib/l10n/app_<code>.arb` (for example `app_pt.arb`, `app_fr.arb`, `app_de.arb`; for regional variants `app_pt_BR.arb`).
2. Change `"@@locale"` and translate all the values. The `@key` entries (metadata) only live in `app_es.arb`.
3. `flutter gen-l10n` (also done by `flutter pub get`) and `flutter test test/l10n_test.dart`: it requires all languages to have **exactly the same keys** and the same placeholders.
4. Test the app with the system language or with `kAppLocale` (screenshots/tests only) and check for overflow on narrow screens.

## New text in code

Never hardcode literals in widgets: add the key first to `app_es.arb` (source) and to all the other ARBs, and use it with `context.l10n.key`. After an `await` in a `State`, use `_l10n`. Visible errors: throw `AppError(code)` and show them with `userError(l10n, e)`.

## What is not translated

Content stored in data (default titles, page/layer names) is translated when displayed with `displayTitle`; the marketplace's remote catalog and technical diagnostics/logs are left as they are.

## Style

Friendly, direct tone, the same as the Spanish source. Keep the interface terms consistent (notebook/note/page, lasso, eraser, ruler). If in doubt, leave the sentence in English and mention it in the PR: someone else can review it.
