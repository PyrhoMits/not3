# 🚀 Publishing a release

Distribution without Google Play: **GitHub Releases** (APK/AAB signed by CI on `v*` tags) and ideally IzzyOnDroid. GPL-3.0-or-later license.

## Before tagging

1. `flutter analyze` (0 issues), `flutter test`, `flutter test integration_test -d linux`.
2. Test on a tablet with the script in [`testing.md`](testing.md).
3. Bump the version in **`pubspec.yaml`** (`version: X.Y.Z+N`, `N` always increasing) and in **`lib/constants.dart`** (`kAppVersion`). `test/app_version_test.dart` checks that they match.
4. Add the `## [X.Y.Z] — YYYY-MM-DD` section to `CHANGELOG.md` in English. The workflow copies that section into the release notes.
5. Update `ROADMAP.md` if the project status changes.

## Tagging

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

CI (`.github/workflows/ci.yml`, `release` job) checks that the tag matches `pubspec.yaml`, signs the APK/AAB and creates the release with the CHANGELOG notes.

## Signing (once, manually)

- Generate a keystore **and keep it safe**: if the key changes, users must uninstall to update.
- Repository secrets (Settings → Secrets → Actions): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- For signed local builds use `android/key.properties` (**never checked in**) with the same four keys; without it, release builds are signed with the debug key.
- For SHA-1 fingerprints (Google Sign-In registration) use `keytool -list`; they're public, the passwords aren't.
- **Never** upload `key.properties`, `*.jks` or `client_secret*.json`; CI runs gitleaks.

## Google Sign-In / Drive

The debug and release SHA-1s must be registered in Google Cloud (Android OAuth client). For public use, publish the consent screen (*Publish app*) with the [`privacy.md`](privacy.md) URL; otherwise you get 100 test users and 7-day tokens.

## After

Download the release APK and check it on a clean device (install, open a notebook and note, write, export).
