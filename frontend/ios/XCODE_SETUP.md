# Xcode Setup

## 1. Create Project

On the company Mac:

1. Open Xcode.
2. Select `File > New > Project`.
3. Choose `iOS > App`.
4. Product Name: `MaintenanceAppMock`.
5. Interface: `SwiftUI`.
6. Language: `Swift`.
7. Minimum iOS version: iOS 17 if possible.
8. Save the project inside `frontend/ios/`.

## 2. Add Existing Source Files

After Xcode creates the project:

1. In Finder, keep the generated Xcode project.
2. Add the files from `frontend/ios/MaintenanceAppMock/` to the Xcode target.
3. If Xcode generated its own `MaintenanceAppMockApp.swift`, replace it with the one in this scaffold.
4. Build for an iPad simulator.

## 3. First Verification

The first run should show:

- tab navigation,
- `Inicio`,
- `Preventivos`,
- placeholder tabs for `Correctivos`, `Activos`, `Stock`, and `Perfil`,
- Hitachi red accent,
- local preventive activity data,
- status transitions in memory.

## 4. Known Limitations

- No backend.
- No real auth.
- No real PDF generation.
- No real Share Sheet yet.
- No persistence after app restart.

