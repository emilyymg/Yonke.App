import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL, .invalidResponse, .decoding:
            return "Respuesta inesperada del servidor."
        case .unauthorized:
            return "Sesión expirada. Inicia sesión de nuevo."
        case .server(_, let message):
            return message
        case .network:
            return "Sin conexión con el servidor."
        }
    }
}

/// Cliente HTTP único de la app. Adjunta el JWT guardado en Keychain
/// y avisa cuando una petición autenticada recibe 401.
final class APIClient {
    nonisolated static let shared = APIClient()

    /// Devuelve el JWT actual. Se consulta en cada petición.
    var tokenProvider: () -> String? = { KeychainManager.shared.readToken() }

    /// Se invoca cuando una petición autenticada responde 401 (sesión vencida o inválida).
    var onUnauthorized: (() -> Void)?

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func request<T: Decodable>(_ method: HTTPMethod = .get,
                               _ path: String,
                               body: (any Encodable)? = nil) async throws -> T {
        let data = try await send(method, path, body: body)
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[API] Falló decodificar \(T.self) de \(path): \(error)")
            print("[API] Cuerpo: \(String(data: data.prefix(1500), encoding: .utf8) ?? "<no UTF-8>")")
            #endif
            throw APIError.decoding(error)
        }
    }

    // MARK: - Private

    private func send(_ method: HTTPMethod, _ path: String, body: (any Encodable)?) async throws -> Data {
        guard let url = URL(string: AppConfig.apiBaseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let token = tokenProvider()
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.decoding(error)
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            // Un 401 solo significa sesión vencida si íbamos autenticados.
            // En el login, un 401 es "credenciales inválidas" y el mensaje viene en el body.
            if http.statusCode == 401, token != nil {
                onUnauthorized?()
                throw APIError.unauthorized
            }
            let message = (try? JSONDecoder().decode(ServerErrorBody.self, from: data))?.error
                ?? "Error \(http.statusCode) del servidor."
            throw APIError.server(status: http.statusCode, message: message)
        }

        return data
    }

    /// Decodificador compartido: snake_case → camelCase y fechas ISO-8601 con o sin milisegundos.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withMillis = ISO8601DateFormatter()
            withMillis.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withMillis.date(from: string) { return date }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: string) { return date }

            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath,
                                                    debugDescription: "Fecha inválida: \(string)"))
        }
        return decoder
    }
}

private struct ServerErrorBody: Decodable {
    let error: String
}
