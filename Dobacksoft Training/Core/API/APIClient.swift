import Foundation
import os

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        // `URLSession.shared` usa defaults muy permisivos (60s/request y 7 días/resource):
        // si el endpoint no responde, la UI queda "trabada" varios minutos con
        // `isLoading == true`. Acotamos a 15s/30s para fallar rápido y mostrar error.
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
        self.decoder = JSONDecoder()
    }

    // MARK: - Public endpoints

    func health() async throws -> HealthDTO {
        try await get("/api/v1/health")
    }

    func login(email: String, password: String) async throws -> AuthLoginResponseDTO {
        try await post(
            "/api/v1/auth/login",
            body: ["email": email, "password": password]
        )
    }

    func refresh(refreshToken: String) async throws -> RefreshResponseDTO {
        try await post("/api/v1/auth/refresh", body: [:], token: refreshToken)
    }

    // MARK: - Authenticated endpoints

    func me(accessToken: String) async throws -> UserDTO {
        try await get("/api/v1/me", token: accessToken)
    }

    func myConvocatorias(accessToken: String) async throws -> [ConvocatoriaSummaryDTO] {
        let response: ConvocatoriasListDTO = try await get("/api/v1/me/convocatorias", token: accessToken)
        return response.items
    }

    func standing(convocatoriaId: String, accessToken: String) async throws -> StandingDTO {
        try await get("/api/v1/me/convocatorias/\(convocatoriaId)/standing", token: accessToken)
    }

    func myAttempts(convocatoriaId: String, accessToken: String) async throws -> [AttemptSummaryDTO] {
        let response: MyAttemptsListDTO = try await get(
            "/api/v1/me/convocatorias/\(convocatoriaId)/attempts",
            token: accessToken
        )
        return response.items
    }

    func convocatorias(accessToken: String) async throws -> [ConvocatoriaSummaryDTO] {
        let response: ConvocatoriasListDTO = try await get("/api/v1/convocatorias", token: accessToken)
        return response.items
    }

    func convocatoriaDetail(id: String, accessToken: String) async throws -> ConvocatoriaSummaryDTO {
        try await get("/api/v1/convocatorias/\(id)", token: accessToken)
    }

    func ranking(convocatoriaId: String, accessToken: String) async throws -> RankingResponseDTO {
        try await get("/api/v1/convocatorias/\(convocatoriaId)/ranking", token: accessToken)
    }

    func attempt(id: String, accessToken: String) async throws -> AttemptDetailDTO {
        try await get("/api/v1/attempts/\(id)", token: accessToken)
    }

    func matrix(convocatoriaId: String, accessToken: String) async throws -> MatrixResponseDTO {
        try await get("/api/v1/convocatorias/\(convocatoriaId)/matrix", token: accessToken)
    }

    // MARK: - Manager / Admin

    func managerDashboard(accessToken: String) async throws -> ManagerDashboardDTO {
        try await get("/api/v1/me/dashboard", token: accessToken)
    }

    func studentProfile(studentId: String, accessToken: String) async throws -> StudentProfileDTO {
        try await get("/api/v1/students/\(studentId)/profile", token: accessToken)
    }

    // MARK: - Webfleet (alerts + sync)

    /// Alertas operativas de enriquecimiento Webfleet (top-50, más recientes primero).
    /// Read-only. Endpoint resuelve el 404 histórico tras PR backend #279.
    func webfletAlerts(accessToken: String) async throws -> WebfletAlertsResponseDTO {
        try await get("/api/v1/webfleet/alerts", token: accessToken)
    }

    /// Dispara sync on-demand (FTP pickup + Webfleet GPS+rotativo + autoclose).
    /// ÚNICA escritura de dominio en la API móvil (excepción D-API-001).
    /// Rate limit backend: 3/min — manejar 429 sin reintentar automático.
    func webfletSync(accessToken: String) async throws -> SyncResultDTO {
        try await post("/api/v1/me/webfleet/sync", body: [:], token: accessToken)
    }

    // MARK: - Internal

    private func get<T: Decodable>(_ path: String, token: String? = nil) async throws -> T {
        try await send(try makeRequest(method: "GET", path: path, token: token))
    }

    private func post<T: Decodable>(
        _ path: String,
        body: [String: Any],
        token: String? = nil
    ) async throws -> T {
        var request = try makeRequest(method: "POST", path: path, token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await send(request)
    }

    private func makeRequest(method: String, path: String, token: String?) throws -> URLRequest {
        let base: URL
        do {
            base = try AppEnvironment.baseURL()
        } catch {
            AppLog.api.fault("BASE_URL inservible: \(String(describing: error), privacy: .public)")
            throw APIError.configuration(String(describing: error))
        }
        let url = base.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppEnvironment.userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpected(status: -1, body: nil)
        }
        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401:
            throw APIError.unauthenticated
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            throw APIError.validation(
                message: body?.message ?? "Validación fallida",
                details: body?.details
            )
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            throw APIError.server(
                message: body?.message ?? "Error del servidor",
                status: http.statusCode
            )
        default:
            let bodyStr = String(data: data, encoding: .utf8)
            throw APIError.unexpected(status: http.statusCode, body: bodyStr)
        }
    }
}
