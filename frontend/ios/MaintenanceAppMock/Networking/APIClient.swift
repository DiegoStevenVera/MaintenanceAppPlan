import Foundation

struct APIClient {
    enum APIError: LocalizedError {
        case invalidBaseURL
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "La URL de la API no es valida."
            case .invalidResponse:
                return "La API respondio con un formato no esperado."
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
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func get<ResponseBody: Decodable>(_ path: String) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        let request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
    }

    func put<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: endpointURL(baseURL: baseURL, path: path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(ResponseBody.self, from: data)
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

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder.apiDecoder.decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(message?.detail ?? "Error \(httpResponse.statusCode) desde la API.")
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
