# Xcode Setup

## 1. Open Project

The Xcode project already exists in this repository:

```text
frontend/ios/MaintenanceAppMock.xcodeproj
```

Open it in Xcode and select the `MaintenanceAppMock` scheme.

The project deployment target is iPadOS/iOS 26.5 and the target supports both iPad and iPhone. The current Mac has Xcode 26.2 with the iOS 26.2 SDK, which can build the app but emits a deployment-target range warning for 26.5. Update Xcode/SDK to the matching 26.5 release when available.

## 2. Source Files

The source files under `frontend/ios/MaintenanceAppMock/` are already attached to the app target.

## 3. First Verification

The first run should show:

- tab navigation,
- `Inicio`,
- `Preventivos`,
- functional mock tabs for `Correctivos`, `Activos`, `Stock`, and `Perfil`,
- Hitachi red accent,
- local preventive activity data,
- local corrective event, asset, and stock data,
- status transitions in memory.
- iPadOS/iOS 26.5 deployment target with Liquid Glass-capable SwiftUI surfaces.
- universal iPhone/iPad target for later iPhone validation.

## 4. Known Limitations

- No backend.
- No real auth.
- No real PDF generation.
- No real Share Sheet yet.
- No persistence after app restart.
