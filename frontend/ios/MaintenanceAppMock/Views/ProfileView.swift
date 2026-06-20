import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MockMaintenanceStore

    var body: some View {
        Form {
            Section("Usuario mock") {
                LabeledContent("Nombre", value: store.currentUser.name)
                LabeledContent("Rol", value: store.currentUser.role.label)
            }

            Section("Pruebas de roles") {
                Button("Cambiar rol mock") {
                    store.toggleRole()
                }
            }
        }
        .navigationTitle("Perfil")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(MockMaintenanceStore())
    }
}

