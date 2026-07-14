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

            NavigationStack {
                CorrectiveListView()
            }
            .tabItem {
                Label("Correctivos", systemImage: "wrench.and.screwdriver")
            }

            NavigationStack {
                AssetSearchView()
            }
            .tabItem {
                Label("Equipos", systemImage: "square.stack.3d.up")
            }

            NavigationStack {
                StockListView()
            }
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

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(MockMaintenanceStore())
    }
}
