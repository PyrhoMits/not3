# OneDrive Integration Plan

## Summary

Add Microsoft OneDrive as an optional cloud backup provider alongside Google
Drive while keeping Not3 offline-first. Local storage remains authoritative and
the app continues to work without an account or network connection.

The first release should allow a notebook to use **one cloud provider at a
time**. A user may connect both Google and Microsoft accounts, but each
notebook selects either Google Drive, OneDrive, or no automatic backup. This
avoids duplicate uploads and ambiguous restore/conflict behavior.

## Product decisions

- OneDrive is optional. No account is required to use Not3.
- Android is the first supported platform. Linux support follows after the
  Android implementation is stable.
- Support both personal Microsoft accounts and work/school accounts, subject
  to an early tenant compatibility test.
- Request only Microsoft Graph's `Files.ReadWrite.AppFolder` delegated
  permission. Do not request access to the user's whole OneDrive by default.
- Store backups in OneDrive's application folder (`Apps/Not3`).
- Reuse the existing self-contained `.inklus` backup format. Do not introduce
  a OneDrive-specific note format.
- Do not copy, move, or delete existing Google Drive backups when the user
  selects OneDrive.
- Do not propagate local deletions to OneDrive in the initial release. Remote
  deletion can be added only after a recoverable trash policy exists.
- Keep backup encryption provider-independent and use the existing
  AES-256-GCM `.inklus` implementation.

## Current constraints

`DriveSyncService` currently combines Google authentication, Google Drive API
calls, backup/restore logic, sync state, revisions, and UI notifications in one
singleton. `SettingsScreen`, `NotebookLibraryScreen`, `HomeScreen`, and the
version-history sheet use Google-specific types directly. Adding Graph calls to
that class would create two implementations of every branch and make both
providers harder to test.

`NotebookMeta.syncEnabled` is only a Boolean. It cannot represent which
provider owns a notebook's automatic backup.

The integration should therefore begin by separating provider-neutral sync
behavior from provider-specific APIs without changing current Google Drive
behavior.

## Proposed architecture

### Provider-neutral layer

Add these provider-neutral types under `lib/services/cloud_sync/`:

- `CloudProviderId`: `googleDrive` and `oneDrive`.
- `CloudAccount`: provider, stable account identifier, and display email/name.
- `CloudSyncStatus`: the current `SyncStatus` values.
- `CloudRevision`: provider, file/item ID, revision ID, modified time, and size.
- `CloudSyncProvider`: the interface implemented by each cloud provider.
- `CloudSyncCoordinator`: the singleton used by the UI and save pipeline.

The provider interface should cover only capabilities shared by both services:

```dart
abstract interface class CloudSyncProvider {
  CloudProviderId get id;
  bool get isSignedIn;
  CloudAccount? get account;

  Future<void> restoreSession();
  Future<bool> signIn();
  Future<void> signOut();
  Future<bool> switchAccount();

  Future<void> backupNote({
    required Note note,
    required String notebookId,
    required String notebookTitle,
    String? password,
  });
  Future<RestoreSummary> restoreLibrary(
    StorageService storage, {
    String? password,
  });
  Future<List<CloudRevision>> listRevisions(String noteId);
  Future<Note> downloadRevision(
    CloudRevision revision, {
    String? password,
  });
}
```

Move export/import, encryption, last-write comparison, throttling, and status
notifications into shared code where possible. Provider classes should handle
only authentication and remote file operations.

The intended dependency flow is:

```text
UI and save callbacks
        |
CloudSyncCoordinator
        |
        +-- GoogleDriveSyncProvider --> Google Drive API
        |
        +-- OneDriveSyncProvider ----> Microsoft Graph
        |
        +-- shared .inklus import/export, encryption, and conflict policy
```

### Notebook selection and migration

Replace the Boolean-only model with a provider-aware value:

```dart
CloudProviderId? syncProvider;
```

`null` means automatic cloud backup is disabled. Keep reading the existing
`syncEnabled` field during migration:

- `syncEnabled == false` becomes `syncProvider == null`.
- `syncEnabled == true` or missing becomes Google Drive for existing installs,
  preserving current behavior.
- New installs default to no provider until the user connects an account and
  explicitly enables backup.

Write only the new `syncProvider` field after migration, while accepting the
old field for at least one release. Do not silently upload existing notebooks
to OneDrive merely because a Microsoft account was connected.

If the user changes a notebook's provider, show a choice to upload the current
local copy or restore first. The previous provider's remote copy remains
untouched.

## Microsoft authentication

### Entra application registration

Create a Microsoft Entra application owned by the Not3 maintainer:

1. Enable personal Microsoft accounts and organizational work/school accounts.
2. Add the Android platform using Not3's package name and release signing
   certificate hash.
3. Register debug signing separately for development builds.
4. Configure the Android redirect URI generated for the app registration.
5. Add delegated `Files.ReadWrite.AppFolder` permission.
6. Do not create or embed a client secret. An installed app is a public client.

The client ID, tenant selection, and redirect URI are public configuration and
may be committed. Tokens, authorization codes, and account identifiers must
never be logged.

### Android implementation

Use Microsoft's supported MSAL Android library through a small Flutter platform
channel owned by this repository. Avoid making the integration depend on an
unmaintained third-party Flutter authentication wrapper.

Configure MSAL in single-account mode with the `common` authority so the same
flow can accept personal and work/school accounts. MSAL should own token
caching and refresh. Dart asks the native layer for a valid Graph access token;
it must not persist tokens in `SharedPreferences`.

Use Authorization Code with PKCE. Never place a client secret in the APK.

Before full implementation, complete a small authentication spike on:

- A personal Microsoft account.
- A Microsoft 365 work/school account, including a tenant that restricts user
  consent if one is available.
- A Huawei device without relying on Google Play Services.
- Sign-in cancellation, account switch, expired session, and revoked consent.

If an organization blocks app-folder permission or requires administrator
consent, show an actionable error. Do not silently fall back to broad
`Files.ReadWrite` access. Any broader permission must be a separate, explicit
product decision.

### Linux follow-up

For Linux, use the system browser with Authorization Code + PKCE and a loopback
redirect URI. Store refresh credentials in the desktop secret store, not a
plain preferences file. Linux is out of scope for the Android MVP.

## OneDrive storage design

Resolve the app folder through:

```http
GET /me/drive/special/approot
```

Use this remote layout:

```text
Apps/Not3/
  notebooks/
    <notebook-id>/
      notebook.json
      notes/
        <note-id>.inklus
```

The IDs, not visible titles, are stable remote keys. User-facing names remain
inside `.inklus` metadata, so renaming a notebook or note does not create a
duplicate. `notebook.json` contains only non-sensitive index metadata needed to
reconstruct notebook membership. If the extra manifest proves unnecessary
during implementation, folder IDs can provide the same mapping, but remote
identity must never depend on titles.

Maintain a local provider-state record keyed by provider account and note ID:

```text
providerAccountId, notebookId, noteId, driveItemId, eTag,
remoteModifiedAt, lastSyncedLocalUpdatedAt
```

Do not put OneDrive item IDs or account information into portable `.inklus`
files.

### Uploads and downloads

- Use simple upload for normal `.inklus` files up to 10 MiB.
- Use a resumable upload session above 10 MiB.
- Upload-session fragment sizes must be a multiple of 320 KiB; target 5--10 MiB
  per request.
- Stream downloads to a temporary file and import only after size/format checks
  succeed.
- Use request timeouts, cancellation, exponential backoff, and Graph's
  `Retry-After` value for HTTP 429 responses.
- Refresh authentication once after HTTP 401, then surface the error.
- Handle pagination on every Graph collection endpoint.
- Perform atomic local state updates only after the remote request succeeds.

### Concurrency and conflicts

Send the last known eTag in `If-Match` when replacing a remote item. HTTP 412
means the remote copy changed and must not be overwritten blindly.

Conflict rules:

1. Only local changed: upload using `If-Match`.
2. Only remote changed: download and restore the remote version.
3. Both changed since the last successful sync: retain both versions, create a
   recoverable local conflict copy, and ask the user which copy to keep.
4. No baseline exists: compare embedded `.inklus` `updatedAt` values and show a
   confirmation before replacing either side.

This is deliberately safer than applying last-write-wins after an eTag
conflict. Existing Google behavior can remain last-write-wins initially, but
the shared coordinator should eventually apply the same recoverable policy to
both providers.

### Revisions and change tracking

Map Graph DriveItem versions to `CloudRevision` so the current version-history
sheet can display local, Google Drive, and OneDrive revisions without
provider-specific types.

The MVP can enumerate the app folder during an explicit restore. After the
basic flow is stable, use the Graph delta API and persist its `deltaLink` per
account to discover remote changes efficiently. A delta response represents
the latest state, not an audit log; versions remain the source for historical
copies.

## User interface

Replace the Google-only settings section with **Cloud backup**:

- Provider choices: Google Drive, Microsoft OneDrive, and Off.
- Connected account and provider are always visible.
- Actions: Connect, Switch account, Sign out, Upload now, Restore, and View
  versions.
- Per-notebook controls select Off, Google Drive, or OneDrive.
- Status and errors name the provider involved.
- Provider switching explains that existing remote backups are kept.
- Restore previews the number of notebooks/notes and conflicts before writing
  local data.

Rename Google-specific localization keys to provider-neutral keys with a
provider parameter where appropriate. Keep all source strings in English and
regenerate Flutter localizations. Update onboarding and privacy text to say
that cloud backup is optional and may use Google Drive or Microsoft OneDrive.

Use a generic cloud icon unless Microsoft trademark guidance is reviewed and
the official OneDrive asset is added with the required attribution.

## Delivery phases

### Phase 0: feasibility spike

- Register the Entra application and Android redirects.
- Prove MSAL sign-in and silent token acquisition on the Huawei test device.
- Resolve `/me/drive/special/approot`, upload a test file, download it, and
  delete the test file.
- Verify personal and work/school account behavior.
- Record tenant/admin-consent limitations before committing to the supported
  account matrix.

Exit criterion: a debug build can sign in and round-trip a disposable file
using app-folder-only permission.

### Phase 1: provider refactor

- Introduce provider-neutral models, interface, and coordinator.
- Adapt the existing Google service behind `GoogleDriveSyncProvider`.
- Replace direct `DriveSyncService` and `DriveRevision` UI dependencies.
- Migrate `syncEnabled` to `syncProvider` without changing Google behavior.
- Add fakes and coordinator tests.

Exit criterion: all existing Google backup, restore, selective sync, and
version-history behavior passes without Microsoft code enabled.

### Phase 2: OneDrive manual backup and restore

- Add the native MSAL bridge and account lifecycle.
- Add a small typed Graph client with app-folder operations.
- Upload/download `.inklus` files and persist item/eTag mappings.
- Add OneDrive to Settings and notebook provider selection.
- Support Upload now and explicit Restore.

Exit criterion: a fresh Android installation can restore a backup produced by
another device/account session, including embedded images and encrypted
backups.

### Phase 3: automatic sync and versions

- Connect OneDrive to the existing save throttle and editor exit flush.
- Add eTag conflict handling and recoverable conflict copies.
- Add Graph version history and restoration.
- Add delta tracking for efficient remote-change discovery.

Exit criterion: two Android devices can edit the same notebook without silent
data loss, and either device can restore an earlier OneDrive version.

### Phase 4: hardening and release

- Complete error, offline, cancellation, rate-limit, and large-file tests.
- Update privacy documentation, architecture documentation, onboarding, and
  release notes.
- Verify release signing redirect configuration and code shrinking.
- Run a closed test with personal and work/school accounts.
- Add Linux support separately after Android stability.

Exit criterion: release APK testing passes on the Huawei device and at least
one additional Android device, with no tokens or note content in logs.

## Test plan

### Unit and HTTP tests

- Provider selection and legacy `syncEnabled` migration.
- Google provider behavior remains unchanged after refactoring.
- Graph request paths, JSON parsing, pagination, and app-folder creation.
- Simple upload and resumable upload boundaries/chunk continuation.
- 401 refresh, 403 consent/admin restriction, 404 missing item, 409 conflict,
  412 eTag conflict, 429 `Retry-After`, and retryable 5xx responses.
- Interrupted upload resumes or restarts safely.
- Remote item mapping is scoped to the signed-in account.
- Sign-out clears in-memory/account-specific mapping state but not local notes
  or remote backups.
- Encrypted and unencrypted `.inklus` round trips, including embedded images.
- Conflict copies remain discoverable and are never silently deleted.

### Device integration tests

- Personal Microsoft account on Huawei Android.
- Work/school account and administrator-consent failure message.
- First sign-in, silent restoration, switch account, revoke consent, and
  reinstall.
- Offline editing followed by reconnect/upload.
- Two-device concurrent edit.
- Large notebook crossing the upload-session threshold.
- Provider switch Google Drive -> OneDrive -> Off, confirming that neither
  provider's remote files are deleted.

## Security and privacy checklist

- App-folder-only delegated access is the default and only MVP permission.
- No client secret in source, resources, APK, or CI.
- MSAL owns Android token storage and refresh.
- No access tokens, authorization codes, account IDs, note titles, or Graph
  response bodies in production logs.
- HTTPS only; preserve Android's cleartext-traffic prohibition.
- Temporary downloads use private app storage and are removed after import or
  failure.
- Disconnecting an account does not imply deleting remote data.
- Privacy documentation names Microsoft as an optional cloud processor and
  explains what is uploaded and when.
- Account removal and remote-data deletion are separate, clearly labelled
  actions; remote deletion is deferred from the MVP.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Flutter authentication wrappers become unmaintained | Keep a narrow in-repo platform channel over supported MSAL Android APIs. |
| Enterprise tenants block user consent | Test early, show an administrator-consent explanation, and never broaden permissions silently. |
| Existing Google behavior regresses during refactor | Complete the provider abstraction as a behavior-preserving phase with fakes and regression tests before OneDrive UI work. |
| Users overwrite edits made on another device | Track item eTags and sync baselines; HTTP 412 creates a recoverable conflict instead of overwriting. |
| Large notebooks fail on unstable networks | Use resumable upload sessions above 10 MiB with persisted progress and bounded retries. |
| A user deletes or edits the app folder manually | Treat 404 as a missing backup, recreate folders when uploading, and never assume cloud data is authoritative. |
| Provider switching duplicates or removes data | Require an explicit per-notebook provider and preserve all previous remote copies. |

## Microsoft references

- [Use the app folder in OneDrive](https://learn.microsoft.com/en-us/graph/onedrive-sharepoint-appfolder)
- [Microsoft identity platform OAuth 2.0 authorization code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [MSAL for Android](https://learn.microsoft.com/en-us/entra/msal/android/)
- [Single-account mode for Android](https://learn.microsoft.com/en-us/entra/msal/android/shared-devices)
- [Upload or replace a DriveItem's contents](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content)
- [Create an upload session](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession)
- [Track changes with DriveItem delta](https://learn.microsoft.com/en-us/graph/api/driveitem-delta)
- [List DriveItem versions](https://learn.microsoft.com/en-us/graph/api/driveitem-list-versions)
