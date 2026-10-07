import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @State private var isChangingPassword = false
    @State private var sessionError: String?
    @State private var isReturningToAdministrator = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                GlassPanel {
                    HStack(spacing: AppSpacing.lg) {
                        Image(systemName: session.currentUser?.avatarSystemImage ?? "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(BrandColor.red)
                            .frame(width: 82, height: 82)
                            .background(BrandColor.red.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(session.currentUser?.name ?? "Usuario")
                                .font(.system(.title, design: .rounded).weight(.bold))
                            Text(session.currentUser?.role.label ?? "Sin rol")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(session.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Foto de perfil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: "Apariencia", subtitle: "Ajustes locales del dispositivo")
                        Toggle("Modo noche", isOn: $isDarkModeEnabled)
                            .font(.headline)
                    }
                }

                if session.isRolePreviewActive {
                    rolePreviewPanel
                }

                GlassPanel {
                    ActionButtonGrid {
                        Button {
                            isChangingPassword = true
                        } label: {
                            Label("Cambiar password", systemImage: "key.fill")
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))

                        Button {
                            Task {
                                await session.signOut()
                            }
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
        .sheet(isPresented: $isChangingPassword) {
            ChangePasswordView()
                .environmentObject(session)
        }
        .alert(
            "No se pudo cambiar la vista",
            isPresented: Binding(
                get: { sessionError != nil },
                set: { if !$0 { sessionError = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(sessionError ?? "")
        }
    }

    private var rolePreviewPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Sesion temporal activa",
                    subtitle: "La sesión administrativa permanece protegida en este iPad"
                )
                Label(
                    "Estás probando como \(session.currentUser?.role.label ?? "otro rol")",
                    systemImage: "eye.fill"
                )
                .font(.headline)
                .foregroundStyle(BrandColor.red)

                Button {
                    returnToAdministrator()
                } label: {
                    if isReturningToAdministrator {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Volver a administrador", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
                .disabled(isReturningToAdministrator)
            }
        }
    }

    private func returnToAdministrator() {
        isReturningToAdministrator = true
        Task {
            do {
                let administrator = try await session.returnToAdministrator()
                _ = administrator
            } catch {
                sessionError = error.localizedDescription
            }
            isReturningToAdministrator = false
        }
    }
}

private struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Credenciales") {
                    SecureField("Password actual", text: $currentPassword)
                        .textContentType(.password)
                    SecureField("Nuevo password", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Repetir nuevo password", text: $confirmation)
                        .textContentType(.newPassword)
                }

                Section {
                    Text("El nuevo password debe tener al menos 8 caracteres. Al cambiarlo se cerraran todas tus sesiones.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(BrandColor.red)
                    }
                }
            }
            .navigationTitle("Cambiar password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmation
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await session.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
                .environmentObject(SessionStore())
        }
    }
}
