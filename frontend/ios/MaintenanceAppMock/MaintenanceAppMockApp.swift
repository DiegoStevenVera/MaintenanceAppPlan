import SwiftUI

@main
struct MaintenanceAppMockApp: App {
    @StateObject private var store = MockMaintenanceStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .tint(BrandColor.red)
        }
    }
}

