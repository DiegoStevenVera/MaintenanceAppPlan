import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var offlineStore: OfflineReportStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Inicio", systemImage: "house.fill")
            }

            NavigationStack {
                PreventiveListView()
            }
            .tabItem {
                Label("Preventivos", systemImage: "checklist")
            }

            NavigationStack {
                DatabaseCorrectiveListView()
            }
            .tabItem {
                Label("Correctivos", systemImage: "wrench.and.screwdriver")
            }

            if session.currentUser?.role == .administrator {
                NavigationStack {
                    PCONPlanningView()
                }
                .tabItem {
                    Label("PCON", systemImage: "calendar.badge.clock")
                }
            }

            NavigationStack {
                AssetSearchView()
            }
            .tabItem {
                Label("Equipos", systemImage: "square.stack.3d.up")
            }

            if session.currentUser?.role == .administrator {
                NavigationStack {
                    StockListView()
                }
                .tabItem {
                    Label("Stock", systemImage: "shippingbox.fill")
                }
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Perfil", systemImage: "person.crop.circle")
            }
        }
        // Keep the connectivity notice away from iPadOS's adaptive tab bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OfflineStatusBar()
        }
        .onChange(of: offlineStore.lastReconciledActivity?.id) { _, _ in
            guard let reconciliation = offlineStore.lastReconciledActivity else { return }
            activityStore.cacheDetail(reconciliation.detail)
            guard offlineStore.isNetworkAvailable else { return }
            Task { await refreshDashboard() }
        }
    }

    private func refreshDashboard() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        await activityStore.loadDashboard(dayFrom: start, dayTo: end, session: session)
    }
}

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Pendiente para siguientes slices."))
                .navigationTitle(title)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionStore())
            .environmentObject(AssetStore())
            .environmentObject(MaintenanceActivityStore())
            .environmentObject(OfflineReportStore())
    }
}
