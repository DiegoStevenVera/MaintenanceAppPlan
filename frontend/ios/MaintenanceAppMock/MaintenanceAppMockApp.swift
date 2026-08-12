import SwiftUI

@main
struct MaintenanceAppMockApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = MockMaintenanceStore()
    @StateObject private var session = SessionStore()
    @StateObject private var assetStore = AssetStore()
    @StateObject private var activityStore = MaintenanceActivityStore()
    @StateObject private var offlineStore = OfflineReportStore()

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView()
                .environmentObject(store)
                .environmentObject(session)
                .environmentObject(assetStore)
                .environmentObject(activityStore)
                .environmentObject(offlineStore)
                .tint(BrandColor.red)
                .preferredColorScheme(store.isDarkModeEnabled ? .dark : .light)
                .onChange(of: scenePhase) { _, phase in
                    Task {
                        if phase == .active {
                            await offlineStore.configure(session: session)
                        } else {
                            await offlineStore.queueLocalDraftsForSync()
                        }
                    }
                }
        }
    }
}

private struct AuthenticatedRootView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var offlineStore: OfflineReportStore

    var body: some View {
        Group {
            if session.isRestoring {
                ProgressView("Restaurando sesion")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MaintenanceScreenBackground())
            } else if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.28), value: session.isAuthenticated)
        .task {
            if let user = await session.restoreSession() {
                store.completeAPISignIn(user: user)
                await offlineStore.configure(session: session)
            } else {
                store.signOut()
            }
        }
        .task(id: session.currentUser?.id) {
            await offlineStore.configure(session: session)
        }
    }
}
