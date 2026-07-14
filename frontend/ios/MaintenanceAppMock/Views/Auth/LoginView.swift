import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @State private var email = ""
    @State private var password = ""
    @State private var apiBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000"
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    @State private var isLoadingSeedData = false

    var body: some View {
        ZStack {
            MaintenanceScreenBackground()

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    header
                    formPanel
                    demoUsersPanel
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            }
        }
        .task {
            await loadRemoteStateIfPossible()
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(BrandColor.red)
                .frame(width: 92, height: 92)
                .background(BrandColor.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: AppSpacing.xs) {
                Text("Maintenance App")
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                Text("Ingresa con tu correo para acceder al mock")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var formPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderText(title: "Iniciar sesion", subtitle: "Password temporal para pruebas: 123456")

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("URL API")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    TextField("http://127.0.0.1:8000", text: $apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Text("En iPad fisica usa la IP de tu Mac, por ejemplo http://192.168.1.20:8000")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Correo")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    TextField("correo@maintenance.local", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Password")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    SecureField("123456", text: $password)
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
                        if isSigningIn {
                            Label("Conectando", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Entrar", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    .disabled(isSigningIn)
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                }
            }
        }
    }

    private var demoUsersPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Usuarios de prueba", subtitle: "Todos usan password 123456")
                if isLoadingSeedData {
                    Label("Cargando usuarios desde la API", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if store.loginUsers.isEmpty {
                    Label("Sin usuarios cargados. Verifica que el backend este activo.", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColor.red)
                }
                ForEach(store.loginUsers) { user in
                    Button {
                        email = user.email
                        password = "123456"
                        errorMessage = nil
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: user.avatarSystemImage)
                                .foregroundStyle(BrandColor.red)
                                .frame(width: 34, height: 34)
                                .background(BrandColor.red.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(user.email) · \(user.role.label)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: email == user.email ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(email == user.email ? BrandColor.red : .secondary)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil
        UserDefaults.standard.set(apiBaseURL, forKey: "apiBaseURL")

        Task {
            do {
                let authenticatedUser = try await AuthService(baseURLString: apiBaseURL)
                    .login(email: email, password: password)
                let appState = try await AppStateService(baseURLString: apiBaseURL).fetchCurrentState()
                await MainActor.run {
                    store.apiBaseURL = apiBaseURL
                    store.applyRemoteState(appState)
                    store.completeAPISignIn(user: authenticatedUser.user)
                    isSigningIn = false
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadRemoteStateIfPossible() async {
        guard !isLoadingSeedData else { return }
        await MainActor.run {
            isLoadingSeedData = true
        }
        do {
            let state = try await AppStateService(baseURLString: apiBaseURL).fetchCurrentState()
            await MainActor.run {
                store.apiBaseURL = apiBaseURL
                store.applyRemoteState(state)
                isLoadingSeedData = false
            }
        } catch {
            await MainActor.run {
                isLoadingSeedData = false
                if store.loginUsers.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(MockMaintenanceStore())
    }
}
