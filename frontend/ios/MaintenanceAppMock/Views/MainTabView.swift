import SwiftUI

struct MainTabView: View {
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

            PlaceholderTabView(title: "Correctivos", systemImage: "wrench.and.screwdriver")
                .tabItem {
                    Label("Correctivos", systemImage: "wrench.and.screwdriver")
                }

            PlaceholderTabView(title: "Activos", systemImage: "square.stack.3d.up")
                .tabItem {
                    Label("Activos", systemImage: "square.stack.3d.up")
                }

            PlaceholderTabView(title: "Stock", systemImage: "shippingbox.fill")
                .tabItem {
                    Label("Stock", systemImage: "shippingbox.fill")
                }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Perfil", systemImage: "person.crop.circle")
            }
        }
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

#Preview {
    MainTabView()
        .environmentObject(MockMaintenanceStore())
}

