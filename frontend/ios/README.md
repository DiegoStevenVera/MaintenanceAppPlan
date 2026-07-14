# iOS Frontend

SwiftUI iPad mock-first frontend targeting iPadOS/iOS 26.5.

This folder contains the first source scaffold for the iPad preventive maintenance mock. It is intentionally backend-free and uses local in-memory mock data.

## Current Scope

The first slice is defined in `../../docs/mock-slice-01.md`.

Included source scaffold:

```text
MaintenanceAppMock/
  MaintenanceAppMockApp.swift
  DesignSystem/
  Models/
  MockData/
  Views/
```

## Xcode Project

The iPad mock now includes an Xcode project:

```text
MaintenanceAppMock.xcodeproj
```

Open it in Xcode and run the `MaintenanceAppMock` scheme on an iPad running iPadOS 26.5. The target is universal (`iPhone` + `iPad`) so it can also be installed on an iPhone running iOS 26.5 for validation, although the primary layout is still optimized for iPad.

Current local note: Xcode 26.2 provides the iOS 26.2 SDK and accepts deployment target 26.5 with a warning. Install the matching iOS 26.5 SDK/Xcode release when available to remove that warning.

See `XCODE_SETUP.md`.
