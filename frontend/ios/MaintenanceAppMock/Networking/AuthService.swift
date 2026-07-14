import Foundation

struct AuthService {
    private let client: APIClient

    init(baseURLString: String) {
        self.client = APIClient(baseURLString: baseURLString)
    }

    func login(email: String, password: String) async throws -> AuthenticatedUser {
        let response: LoginResponse = try await client.post(
            "api/v1/auth/login",
            body: LoginRequest(email: email, password: password)
        )
        return AuthenticatedUser(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            user: response.user.mockUser
        )
    }
}

struct AuthenticatedUser {
    let accessToken: String
    let refreshToken: String
    let user: MockUser
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let user: APIUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

private struct APIUser: Decodable {
    let id: String
    let name: String
    let email: String
    let role: String
    let roleLabel: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case roleLabel = "role_label"
    }

    var mockUser: MockUser {
        MockUser(
            id: id,
            name: name,
            role: userRole,
            email: email,
            avatarSystemImage: avatarSystemImage
        )
    }

    private var userRole: UserRole {
        switch role {
        case "COORDINATOR":
            return .coordinator
        case "BOSS":
            return .boss
        case "ADMINISTRATOR":
            return .administrator
        default:
            return .technician
        }
    }

    private var avatarSystemImage: String {
        switch userRole {
        case .technician:
            return "person.crop.circle.fill"
        case .coordinator:
            return "person.crop.square.fill"
        case .boss:
            return "person.crop.rectangle.fill"
        case .administrator:
            return "person.badge.key.fill"
        }
    }
}
