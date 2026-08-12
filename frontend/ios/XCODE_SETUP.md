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

- authenticated login backed by FastAPI,
- tab navigation,
- `Inicio`,
- `Preventivos`,
- functional mock tabs for `Correctivos`, `Activos`, `Stock`, and `Perfil`,
- Hitachi red accent,
- iPadOS/iOS 26.5 deployment target with Liquid Glass-capable SwiftUI surfaces.
- universal iPhone/iPad target for later iPhone validation.

## 4. Physical iPad Local Backend

Start FastAPI on every Mac network interface:

```bash
make backend-dev-postgres
```

Find the Mac Wi-Fi address:

```bash
ipconfig getifaddr en0
```

Enter `http://<mac-ip>:8000` on the login screen. The Mac and iPad must be on the same LAN, with
VPN and guest-network client isolation disabled. On first access, accept the iPadOS local-network
permission. If it was previously denied, enable MaintenanceAppMock under Settings > Privacy &
Security > Local Network.

The target declares `NSLocalNetworkUsageDescription` and `NSAllowsLocalNetworking` in
`Info.plist`. When these keys change, delete the previous app from the iPad and install the new
build so iPadOS requests permission again.

## 5. Known Limitations

- Authentication is connected to FastAPI, but operational screens are still moving from the
  transitional store to normalized domain APIs.
- PDF generation and file download are pending backend implementation.
