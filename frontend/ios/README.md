# iOS Frontend

SwiftUI iPad mock-first frontend targeting iPadOS/iOS 26.5.

This folder contains the SwiftUI iPad application evolving from the approved visual mock into V1.
Authentication is connected to FastAPI; operational modules are being migrated from the
transitional mock store to normalized APIs feature by feature.

## Current Scope

The first slice is defined in `../../docs/mock-slice-01.md`.

Included source scaffold:

```text
MaintenanceAppMock/
  MaintenanceAppMockApp.swift
  DesignSystem/
  Models/
  MockData/
  Networking/
  Views/
```

## Authentication

- The login screen calls `POST /api/v1/auth/login`.
- Access and refresh tokens are stored in the iOS Keychain.
- App launch validates the access token with `/api/v1/auth/me` and uses `/api/v1/auth/refresh`
  when renewal is required.
- Closing the session revokes the refresh session in PostgreSQL and removes local Keychain items.
- Changing the password is available in Profile and closes every active refresh session.

## Equipment

- The Equipment tab reads business-anchor assets from `GET /api/v1/assets`.
- Search and subsystem filters are evaluated by PostgreSQL through the API.
- Equipment detail, component/slot hierarchy, and maintenance history use the normalized
  asset endpoints.
- Every request uses the authenticated session and automatically refreshes an expired access token.

## Maintenance Read Slice

- Preventive and corrective lists use `GET /api/v1/maintenance-activities` with server-side
  search and date filters.
- Detail screens use `GET /api/v1/maintenance-activities/{id}` and display normalized context,
  assets, report versions, preventive steps/tests, or corrective report activities.
- Preventive and corrective detail screens expose only the lifecycle actions permitted for the
  authenticated role and current state. They call the normalized start, complete, close, and
  reopen endpoints, confirm destructive transitions, display API errors, and refresh list,
  detail, and dashboard state after success.
- Detail comments are loaded from `GET /api/v1/maintenance-activities/{id}/comments` and are
  written from the detail screen. Preventive comments are reusable by template/equipment;
  corrective comments belong only to their event. Engineers, coordinators, the boss, and
  administrators may write them.
- Preventive and corrective forms load their editor catalogs and existing draft from the
  normalized report API. Saving persists steps/tests or corrective activities, participants,
  drawn signature strokes, and gallery evidence. Maintenance detail screens show the
  reusable preventive comments or event-local corrective comments and allow new comments.
- Corrective component replacement searches the affected equipment hierarchy and database stock;
  the actual hierarchy change occurs only when the report version is finalized.
- Preventive, corrective, and calibration PDF generation is connected to the backend.
- Preventive and corrective report drafts are stored locally and automatically retried
  when connectivity returns. Finalization still requires a live server connection.

## Offline report drafts

After one successful online sign-in, the app can restore the cached user profile and
open locally cached preventive or corrective report drafts without reaching the API.
Draft data, signatures, and evidence files are written atomically under Application
Support with iOS file protection enabled.

The top status bar exposes pending drafts and their synchronization state. A draft is
retried when the network path becomes available, when the app returns to the foreground,
and periodically while the API remains unreachable. The server validates the report
version used as the editing base; a newer server version moves the local draft to
`needsAttention` instead of silently overwriting it.

Only drafts are queued offline. Finalizing a report remains an online operation because
it can trigger lifecycle and inventory effects that require an authoritative server
transaction.

### Manual offline validation

1. Start PostgreSQL and FastAPI, sign in once, and open an in-progress preventive or
   corrective report. The first online load caches the editor context required offline.
2. Stop only FastAPI with `Control-C` in its terminal. Leave Docker and PostgreSQL
   running. This simulates a reachable network with an unavailable application server.
3. Change report fields, add a signature or evidence, wait for autosave, and tap
   `Guardar borrador`. After the request timeout, the form must show that the draft is
   protected locally and pending synchronization.
4. Close and relaunch the app. The cached session should restore, and the global status
   bar must expose the pending draft through `Ver`.
5. Start FastAPI again. Synchronization should occur automatically within the retry
   window, or immediately after tapping `Reintentar`.
6. Reopen the report and confirm that the server returns the synchronized values.

On a physical iPad, disabling Wi-Fi after step 1 additionally validates immediate
`NWPathMonitor` detection. Stopping FastAPI is the better Simulator test because it
does not disturb Docker data and also exercises timeout/retry behavior.

The app has one compile-time scheme, `MaintenanceApp`. Its API URL and
environment label come from `MaintenanceAppMock/Config/Environment.xcconfig`.
The checked-out Git revision determines its values: `develop` uses DEV and a
QA release tag uses QA. The login view does not expose an editable server URL.

## Xcode Project

The iPad mock now includes an Xcode project:

```text
MaintenanceAppMock.xcodeproj
```

Open it in Xcode and run the `MaintenanceAppMock` scheme on an iPad running iPadOS 26.5. The target is universal (`iPhone` + `iPad`) so it can also be installed on an iPhone running iOS 26.5 for validation, although the primary layout is still optimized for iPad.

Current local note: Xcode 26.2 provides the iOS 26.2 SDK and accepts deployment target 26.5 with a warning. Install the matching iOS 26.5 SDK/Xcode release when available to remove that warning.

See `XCODE_SETUP.md`.
