import SwiftUI

@main
struct MaintenanceAppMockApp: App {
    @StateObject private var store = MockMaintenanceStore()

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView()
                .environmentObject(store)
                .tint(BrandColor.red)
                .preferredColorScheme(store.isDarkModeEnabled ? .dark : .light)
        }
    }
}

private struct AuthenticatedRootView: View {
    @EnvironmentObject private var store: MockMaintenanceStore

    var body: some View {
        Group {
            if store.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.28), value: store.isAuthenticated)
    }
}
