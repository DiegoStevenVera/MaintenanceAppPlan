import Foundation

struct APIClient {
    enum APIError: LocalizedError {
        case invalidBaseURL
        case invalidResponse
        case unauthorized
        case requestTimedOut
        case localServerUnavailable
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "La URL de la API no es valida."
            case .invalidResponse:
                return "La API respondio con un formato no esperado."
            case .unauthorized:
                return "La sesion vencio o las credenciales no son validas."
            case .requestTimedOut:
                return "El servidor no respondio. Verifica la IP de la Mac y que ambos dispositivos esten en la misma red."
            case .localServerUnavailable:
                return "No se pudo acceder al servidor local. Revisa el permiso de Red local del iPad y que FastAPI este activo."
            case .serverError(let message):
                return message
            }
        }
    }

    var baseURLString: String
    private let session: URLSession

    init(baseURLString: String, session: URLSession = .shared) {
        self.baseURLString = baseURLString
        self.session = session
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody,
        bearerToken: String? = nil
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(bearerToken, to: &request)
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)

        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func post<ResponseBody: Decodable>(
        _ path: String,
        bearerToken: String
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        applyAuthorization(bearerToken, to: &request)

        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func get<ResponseBody: Decodable>(
        _ path: String,
        bearerToken: String? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        let endpoint = endpointURL(baseURL: baseURL, path: path)
        guard var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidBaseURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let requestURL = components.url else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 15
        applyAuthorization(bearerToken, to: &request)
        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func getData(
        _ path: String,
        bearerToken: String? = nil
    ) async throws -> Data {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.timeoutInterval = 30
        applyAuthorization(bearerToken, to: &request)
        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
        return data
    }

    func put<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody,
        bearerToken: String? = nil
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "PUT"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(bearerToken, to: &request)
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)

        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func patch<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody,
        bearerToken: String? = nil
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(bearerToken, to: &request)
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)

        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func delete(
        _ path: String,
        bearerToken: String? = nil
    ) async throws {
        guard let baseURL = URL(
            string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        ) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        applyAuthorization(bearerToken, to: &request)
        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
    }

    func postWithoutResponse<RequestBody: Encodable>(
        _ path: String,
        body: RequestBody,
        bearerToken: String? = nil
    ) async throws {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(bearerToken, to: &request)
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)

        let (data, response) = try await responseData(for: request)
        try validate(response: response, data: data)
    }

    private func endpointURL(baseURL: URL, path: String) -> URL {
        path
            .split(separator: "/")
            .reduce(baseURL) { partialURL, component in
                partialURL.appendingPathComponent(String(component))
            }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode != 401 else {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder.apiDecoder.decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(message?.detail ?? "Error \(httpResponse.statusCode) desde la API.")
        }
    }

    private func applyAuthorization(_ token: String?, to request: inout URLRequest) {
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func responseData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw APIError.requestTimedOut
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
                 .notConnectedToInternet, .dataNotAllowed:
                throw APIError.localServerUnavailable
            default:
                throw error
            }
        }
    }
}

private struct APIErrorResponse: Decodable {
    let detail: String?
}

private extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
