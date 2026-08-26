import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            MaintenanceScreenBackground()

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    header
                    formPanel
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(BrandColor.red)
                .frame(width: 92, height: 92)
                .background(
                    BrandColor.red.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )

            VStack(spacing: AppSpacing.xs) {
                Text("Maintenance App")
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                Text("Ingresa con tu cuenta para continuar")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderText(
                    title: "Iniciar sesion",
                    subtitle: "La sesion se almacena de forma segura en este dispositivo"
                )

                fieldLabel("Entorno") {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(AppEnvironment.name)
                            .font(.body.weight(.bold))
                        Text(AppEnvironment.apiBaseURL)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                fieldLabel("Correo") {
                    TextField("correo@empresa.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .textFieldStyle(.roundedBorder)
                }

                fieldLabel("Password") {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColor.red)
                }

                ActionButtonGrid {
                    Button {
                        signIn()
                    } label: {
                        Label(
                            isSigningIn ? "Conectando" : "Entrar",
                            systemImage: isSigningIn
                                ? "arrow.triangle.2.circlepath"
                                : "arrow.right.circle.fill"
                        )
                    }
                    .disabled(isSigningIn || email.isEmpty || password.isEmpty)
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                }
            }
        }
    }

    private func fieldLabel<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                _ = try await session.signIn(
                    email: email,
                    password: password,
                    baseURL: AppEnvironment.apiBaseURL
                )
                isSigningIn = false
            } catch {
                isSigningIn = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(SessionStore())
    }
}
