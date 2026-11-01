# Inklus Privacy Policy

*Last updated: September 27, 2026*

Inklus is a **free and open source** handwriting app (GPL-3.0 license). It has no accounts of its own, no ads, no analytics and no paid features. This policy explains what data the app handles and where it goes.

## Summary

- **Your notes are stored on your device.** Inklus has no servers and nobody but you can read them.
- **Google Drive is optional.** If you connect your account, Inklus uploads a copy of your notes to **your** Drive. We have no access to it.
- **No analytics, no ads, no tracking.** We don't sell or share data with anyone.

## Data stored on the device

Notebooks, notes, pages, strokes, images you insert, templates, tags, reminders, writing statistics and version history are stored in the app's private folder (`inklus/`). They are deleted when you uninstall the app. You can export them at any time (Settings → "Export full backup").

## Google Drive (optional)

Only if you tap "Connect" in Settings:

- **Google sign-in**: the app receives your account email only to show you which account you're connected with. It is not stored on any server.
- **`drive.file` permission**: Inklus **can only see and modify the files it creates itself** (an "Inklus" folder with one `.inklus` file per note). It cannot read the rest of your Drive.
- Backups can be **encrypted with a password** (AES-256-GCM) before being uploaded. The password never leaves the device.
- Google handles those files according to [Google's privacy policy](https://policies.google.com/privacy). You can disconnect the account in Settings and delete the "Inklus" folder from your Drive whenever you want.

Inklus' use and transfer to any other app of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## Handwriting recognition (ML Kit)

The "Convert to text", "Recognize text" and "Index handwriting" features use **Google ML Kit**, which recognizes text **on the device**: your strokes and pages are not sent to any server. The available languages are English, Japanese and Thai. The first time you choose a language, the app asks you to confirm and downloads its model (~20 MB) from Google's servers; after that it works offline. Under its [terms](https://developers.google.com/ml-kit/terms), ML Kit may send Google anonymous technical usage and performance metrics, which do not include the content of your notes.

## Marketplace

When you open the Marketplace, the app downloads the catalog and the free packs (templates, palettes, stickers) from the public jsDelivr CDN (`cdn.jsdelivr.net`), which serves the public `inklus-marketplace` GitHub repository. Like any web download, that CDN sees your IP address. No other data is sent.

## Error log

If the app fails, the error is stored **only on your device** (Settings → "Error log"). It is not automatically sent to anyone. You can share it yourself if you want to help fix the bug.

## Android permissions

- **Internet**: only for Google Drive (if you enable it), the Marketplace and the ML Kit models.
- **Files**: only the ones you choose in the system picker (import PDFs, images or `.inklus`; export).

## Minors

Inklus does not collect personal data, so it is suitable for any age. Google sign-in is subject to Google's age requirements.

## Changes and contact

If this policy changes, this document will be updated (its history is in the repository). For any questions, open an *issue* at <https://github.com/Pedroj-64/inklus/issues>.
