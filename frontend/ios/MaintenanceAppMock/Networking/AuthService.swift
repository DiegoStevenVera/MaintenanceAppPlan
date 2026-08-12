import Foundation
import Security

struct AuthService {
    private let client: APIClient

    init(baseURLString: String) {
        self.client = APIClient(baseURLString: baseURLString)
    }

    func login(email: String, password: String) async throws -> AuthenticatedUser {
        let response: TokenPairResponse = try await client.post(
            "api/v1/auth/login",
            body: LoginRequest(email: email, password: password)
        )
        return response.authenticatedUser
    }

    func refresh(refreshToken: String) async throws -> AuthenticatedUser {
        let response: TokenPairResponse = try await client.post(
            "api/v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: refreshToken)
        )
        return response.authenticatedUser
    }

    func currentUser(accessToken: String) async throws -> MockUser {
        let response: APIUser = try await client.get(
            "api/v1/auth/me",
            bearerToken: accessToken
        )
        return response.mockUser
    }

    func logout(refreshToken: String) async throws {
        try await client.postWithoutResponse(
            "api/v1/auth/logout",
            body: RefreshTokenRequest(refreshToken: refreshToken)
        )
    }

    func changePassword(
        currentPassword: String,
        newPassword: String,
        accessToken: String
    ) async throws {
        try await client.postWithoutResponse(
            "api/v1/auth/change-password",
            body: ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword
            ),
            bearerToken: accessToken
        )
    }

    func impersonate(
        role: UserRole,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        let response: TokenPairResponse = try await client.post(
            "api/v1/auth/impersonate-role",
            body: ImpersonateRoleRequest(role: role.apiValue),
            bearerToken: accessToken
        )
        return response.authenticatedUser
    }

    func rolePreviewOptions(accessToken: String) async throws -> [RolePreviewOption] {
        try await client.get(
            "api/v1/auth/impersonation-roles",
            bearerToken: accessToken
        )
    }
}

struct AuthenticatedUser {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: MockUser
}

struct RolePreviewOption: Decodable, Identifiable {
    let roleValue: String
    let roleLabel: String
    let userName: String

    var id: String { roleValue }
    var role: UserRole? { UserRole(apiValue: roleValue) }

    enum CodingKeys: String, CodingKey {
        case roleValue = "role"
        case roleLabel = "role_label"
        case userName = "user_name"
    }
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshTokenRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

private struct ImpersonateRoleRequest: Encodable {
    let role: String
}

private struct TokenPairResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: APIUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    var authenticatedUser: AuthenticatedUser {
        AuthenticatedUser(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            user: user.mockUser
        )
    }
}

private struct APIUser: Decodable {
    let id: String
    let name: String
    let email: String
    let role: String

    var mockUser: MockUser {
        let resolvedRole: UserRole
        switch role {
        case "COORDINATOR":
            resolvedRole = .coordinator
        case "BOSS":
            resolvedRole = .boss
        case "ADMINISTRATOR":
            resolvedRole = .administrator
        default:
            resolvedRole = .maintenanceEngineer
        }

        let avatarSystemImage: String
        switch resolvedRole {
        case .maintenanceEngineer:
            avatarSystemImage = "person.crop.circle.fill"
        case .coordinator:
            avatarSystemImage = "person.crop.square.fill"
        case .boss:
            avatarSystemImage = "person.crop.rectangle.fill"
        case .administrator:
            avatarSystemImage = "person.badge.key.fill"
        }

        return MockUser(
            id: id,
            name: name,
            role: resolvedRole,
            email: email,
            avatarSystemImage: avatarSystemImage
        )
    }
}

struct KeychainStore {
    enum Key: String {
        case accessToken
        case refreshToken
        case administratorAccessToken
        case administratorRefreshToken
    }

    private let service = "com.maintenanceapp.mock.authentication"

    func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let attributes = [kSecValueData: data] as CFDictionary

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes)
        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(insertStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledStatus(updateStatus)
        }
    }

    func read(_ key: Key) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unhandledStatus(status)
        }
        return value
    }

    func delete(_ key: Key) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

private enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "No se pudo acceder al Keychain (\(status))."
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var currentUser: MockUser?
    @Published private(set) var isRestoring = true
    @Published private(set) var rolePreviewAdministrator: MockUser?

    private let keychain = KeychainStore()
    private let cachedUserKey = "authenticatedUserCache"
    private let cachedAdministratorKey = "rolePreviewAdministratorCache"

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var isRolePreviewActive: Bool {
        rolePreviewAdministrator != nil
    }

    func restoreSession() async -> MockUser? {
        defer { isRestoring = false }
        rolePreviewAdministrator = cachedAdministrator()

        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let accessToken = try? keychain.read(.accessToken),
              let refreshToken = try? keychain.read(.refreshToken) else {
            clearLocalSession()
            return nil
        }

        let service = AuthService(baseURLString: baseURL)
        do {
            let user = try await service.currentUser(accessToken: accessToken)
            currentUser = user
            return user
        } catch APIClient.APIError.unauthorized {
            do {
                let renewed = try await service.refresh(refreshToken: refreshToken)
                try persist(renewed)
                currentUser = renewed.user
                return renewed.user
            } catch APIClient.APIError.unauthorized {
                clearLocalSession()
                return nil
            } catch {
                let cachedUser = cachedUser()
                currentUser = cachedUser
                return cachedUser
            }
        } catch {
            let cachedUser = cachedUser()
            currentUser = cachedUser
            return cachedUser
        }
    }

    func signIn(email: String, password: String, baseURL: String) async throws -> MockUser {
        let normalizedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let authenticated = try await AuthService(baseURLString: normalizedURL)
            .login(email: email, password: password)
        try persist(authenticated)
        UserDefaults.standard.set(normalizedURL, forKey: "apiBaseURL")
        currentUser = authenticated.user
        return authenticated.user
    }

    func signOut() async {
        let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL")
        let refreshToken = try? keychain.read(.refreshToken)
        if let baseURL, let refreshToken {
            try? await AuthService(baseURLString: baseURL).logout(refreshToken: refreshToken)
        }
        if let baseURL,
           let administratorRefreshToken = try? keychain.read(.administratorRefreshToken) {
            try? await AuthService(baseURLString: baseURL).logout(
                refreshToken: administratorRefreshToken
            )
        }
        clearLocalSession()
    }

    func previewRole(_ role: UserRole) async throws -> MockUser {
        guard let administrator = currentUser,
              administrator.role == .administrator,
              !isRolePreviewActive,
              role != .administrator,
              let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let accessToken = try keychain.read(.accessToken),
              let refreshToken = try keychain.read(.refreshToken) else {
            throw APIClient.APIError.unauthorized
        }

        let preview = try await AuthService(baseURLString: baseURL).impersonate(
            role: role,
            accessToken: accessToken
        )
        try keychain.save(accessToken, for: .administratorAccessToken)
        try keychain.save(refreshToken, for: .administratorRefreshToken)
        if let data = try? JSONEncoder().encode(administrator) {
            UserDefaults.standard.set(data, forKey: cachedAdministratorKey)
        }
        try persist(preview)
        rolePreviewAdministrator = administrator
        currentUser = preview.user
        return preview.user
    }

    func rolePreviewOptions() async throws -> [RolePreviewOption] {
        guard currentUser?.role == .administrator,
              let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.unauthorized
        }
        return try await withValidAccessToken { token in
            try await AuthService(baseURLString: baseURL)
                .rolePreviewOptions(accessToken: token)
        }
    }

    func returnToAdministrator() async throws -> MockUser {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let refreshToken = try keychain.read(.administratorRefreshToken) else {
            throw APIClient.APIError.unauthorized
        }
        let administrator = try await AuthService(baseURLString: baseURL)
            .refresh(refreshToken: refreshToken)
        try persist(administrator)
        clearAdministratorPreview()
        currentUser = administrator.user
        return administrator.user
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let accessToken = try keychain.read(.accessToken) else {
            throw APIClient.APIError.unauthorized
        }
        try await AuthService(baseURLString: baseURL).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            accessToken: accessToken
        )
        await signOut()
    }

    func withValidAccessToken<Value>(
        _ operation: (String) async throws -> Value
    ) async throws -> Value {
        guard let accessToken = try keychain.read(.accessToken) else {
            throw APIClient.APIError.unauthorized
        }

        do {
            return try await operation(accessToken)
        } catch APIClient.APIError.unauthorized {
            let renewed = try await renewSession()
            return try await operation(renewed.accessToken)
        }
    }

    private func renewSession() async throws -> AuthenticatedUser {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let refreshToken = try keychain.read(.refreshToken) else {
            throw APIClient.APIError.unauthorized
        }
        do {
            let renewed = try await AuthService(baseURLString: baseURL)
                .refresh(refreshToken: refreshToken)
            try persist(renewed)
            currentUser = renewed.user
            return renewed
        } catch APIClient.APIError.unauthorized {
            clearLocalSession()
            throw APIClient.APIError.unauthorized
        } catch {
            throw error
        }
    }

    private func persist(_ authenticated: AuthenticatedUser) throws {
        try keychain.save(authenticated.accessToken, for: .accessToken)
        try keychain.save(authenticated.refreshToken, for: .refreshToken)
        if let data = try? JSONEncoder().encode(authenticated.user) {
            UserDefaults.standard.set(data, forKey: cachedUserKey)
        }
    }

    private func clearLocalSession() {
        try? keychain.delete(.accessToken)
        try? keychain.delete(.refreshToken)
        clearAdministratorPreview()
        UserDefaults.standard.removeObject(forKey: cachedUserKey)
        currentUser = nil
    }

    private func clearAdministratorPreview() {
        try? keychain.delete(.administratorAccessToken)
        try? keychain.delete(.administratorRefreshToken)
        UserDefaults.standard.removeObject(forKey: cachedAdministratorKey)
        rolePreviewAdministrator = nil
    }

    private func cachedUser() -> MockUser? {
        guard let data = UserDefaults.standard.data(forKey: cachedUserKey) else {
            return nil
        }
        return try? JSONDecoder().decode(MockUser.self, from: data)
    }

    private func cachedAdministrator() -> MockUser? {
        guard let data = UserDefaults.standard.data(forKey: cachedAdministratorKey) else {
            return nil
        }
        return try? JSONDecoder().decode(MockUser.self, from: data)
    }
}
