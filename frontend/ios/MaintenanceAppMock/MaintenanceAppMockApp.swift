import SwiftUI

enum AppEnvironment {
    static let apiBaseURL: String = requiredInfoValue(for: "API_BASE_URL")
    static let name: String = requiredInfoValue(for: "APP_ENVIRONMENT")

    static func configure() {
        UserDefaults.standard.set(apiBaseURL, forKey: "apiBaseURL")
    }

    private static func requiredInfoValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("$(") else {
            fatalError("Missing build setting: \(key)")
        }
        return value
    }
}

@main
struct MaintenanceAppMockApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @StateObject private var session = SessionStore()
    @StateObject private var assetStore = AssetStore()
    @StateObject private var activityStore = MaintenanceActivityStore()
    @StateObject private var offlineStore = OfflineReportStore()

    init() {
        AppEnvironment.configure()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView()
                .environmentObject(session)
                .environmentObject(assetStore)
                .environmentObject(activityStore)
                .environmentObject(offlineStore)
                .tint(BrandColor.red)
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
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
            if await session.restoreSession() != nil {
                await offlineStore.configure(session: session)
            }
        }
        .task(id: session.currentUser?.id) {
            await offlineStore.configure(session: session)
        }
    }
}
