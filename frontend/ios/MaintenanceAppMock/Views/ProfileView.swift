import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MockMaintenanceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                GlassPanel {
                    HStack(spacing: AppSpacing.lg) {
                        Image(systemName: store.currentUser.avatarSystemImage)
                            .font(.system(size: 54))
                            .foregroundStyle(BrandColor.red)
                            .frame(width: 82, height: 82)
                            .background(BrandColor.red.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(store.currentUser.name)
                                .font(.system(.title, design: .rounded).weight(.bold))
                            Text(store.currentUser.role.label)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(store.currentUser.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Foto de perfil real o avatar por defecto en la app final")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: "Apariencia", subtitle: "Ajustes locales del mock")
                        Toggle("Modo noche", isOn: $store.isDarkModeEnabled)
                            .font(.headline)
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: "Pruebas de roles", subtitle: "Permite validar permisos sin iniciar sesion real")
                        ActionButtonGrid {
                            Button {
                                store.toggleRole()
                            } label: {
                                Label("Cambiar rol mock", systemImage: "person.badge.key")
                            }
                            .buttonStyle(ActionTileButtonStyle(prominent: true))
                        }
                    }
                }

                GlassPanel {
                    ActionButtonGrid {
                        Button {
                            store.signOut()
                        } label: {
                            Label("Cerrar sesion", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(ActionTileButtonStyle())
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Perfil")
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
                .environmentObject(MockMaintenanceStore())
        }
    }
}
