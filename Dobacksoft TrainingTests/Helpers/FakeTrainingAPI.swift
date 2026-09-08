import Foundation

@testable import Dobacksoft_Training

/// Stand-in for the network layer.
///
/// Scripted per endpoint: a test sets the results it needs and asserts on the
/// recorded calls. Everything not configured throws `.notFound`, so a test that
/// exercises an unexpected endpoint fails loudly instead of quietly passing.
actor FakeTrainingAPI: TrainingAPI {
    // MARK: Scripted results

    var loginResult: Result<AuthLoginResponseDTO, Error> = .failure(APIError.notFound(.resourceMissing))
    var refreshResult: Result<RefreshResponseDTO, Error> = .failure(APIError.notFound(.resourceMissing))

    /// Consumed in order, one per `me(accessToken:)` call, so a test can say
    /// "first call fails with 401, the retry succeeds".
    var meResults: [Result<UserDTO, Error>] = []

    /// Consumed in order by `standing(convocatoriaId:accessToken:)`.
    var standingResults: [Result<StandingDTO, Error>] = []
    var progressResults: [Result<ProgressDTO, Error>] = []
    var cardResults: [Result<CardDTO, Error>] = []
    var gpsResults: [Result<GpsPayloadDTO, Error>] = []
    var pinResults: [Result<PinDTO, Error>] = []
    var routeResults: [Result<RouteDetailDTO, Error>] = []
    private(set) var routeRequests: [(String, String?)] = []
    var passwordResult: Result<Void, Error> = .success(())
    private(set) var passwordBodies: [[String]] = []
    private(set) var progressConvocatoriaIds: [String?] = []

    // MARK: Recorded calls

    private(set) var loginCalls: [(email: String, password: String)] = []
    private(set) var refreshCalls: [String] = []
    private(set) var meTokens: [String] = []
    private(set) var standingTokens: [String] = []

    // MARK: Configuration

    func setLoginResult(_ result: Result<AuthLoginResponseDTO, Error>) { loginResult = result }
    func setRefreshResult(_ result: Result<RefreshResponseDTO, Error>) { refreshResult = result }
    func setMeResults(_ results: [Result<UserDTO, Error>]) { meResults = results }
    func setStandingResults(_ results: [Result<StandingDTO, Error>]) { standingResults = results }
    func setProgressResults(_ results: [Result<ProgressDTO, Error>]) { progressResults = results }
    func setCardResults(_ results: [Result<CardDTO, Error>]) { cardResults = results }
    func setGpsResults(_ results: [Result<GpsPayloadDTO, Error>]) { gpsResults = results }
    func setPinResults(_ results: [Result<PinDTO, Error>]) { pinResults = results }
    func setRouteResults(_ results: [Result<RouteDetailDTO, Error>]) { routeResults = results }
    func setPasswordResult(_ result: Result<Void, Error>) { passwordResult = result }

    private func next<T>(_ queue: inout [Result<T, Error>]) throws -> T {
        guard !queue.isEmpty else { throw APIError.notFound(.resourceMissing) }
        return try queue.removeFirst().get()
    }

    // MARK: TrainingAPI

    func health() async throws -> HealthDTO { throw APIError.notFound(.resourceMissing) }

    func login(email: String, password: String) async throws -> AuthLoginResponseDTO {
        loginCalls.append((email, password))
        return try loginResult.get()
    }

    func refresh(refreshToken: String) async throws -> RefreshResponseDTO {
        refreshCalls.append(refreshToken)
        return try refreshResult.get()
    }

    func me(accessToken: String) async throws -> UserDTO {
        meTokens.append(accessToken)
        return try next(&meResults)
    }

    func standing(convocatoriaId: String, accessToken: String) async throws -> StandingDTO {
        standingTokens.append(accessToken)
        return try next(&standingResults)
    }

    func progress(convocatoriaId: String?, accessToken: String) async throws -> ProgressDTO {
        progressConvocatoriaIds.append(convocatoriaId)
        return try next(&progressResults)
    }

    func myCard(accessToken: String) async throws -> CardDTO {
        try next(&cardResults)
    }

    func attemptGps(id: String, accessToken: String) async throws -> GpsPayloadDTO {
        try next(&gpsResults)
    }

    func myPin(accessToken: String) async throws -> PinDTO {
        try next(&pinResults)
    }

    func myRoute(code: String, convocatoriaId: String?, accessToken: String) async throws -> RouteDetailDTO {
        routeRequests.append((code, convocatoriaId))
        return try next(&routeResults)
    }

    func changePassword(
        current: String,
        new: String,
        confirm: String,
        accessToken: String
    ) async throws {
        passwordBodies.append([current, new, confirm])
        try passwordResult.get()
    }

    func myConvocatorias(accessToken: String) async throws -> [ConvocatoriaSummaryDTO] {
        throw APIError.notFound(.resourceMissing)
    }
    func myAttempts(convocatoriaId: String, accessToken: String) async throws -> [AttemptSummaryDTO] {
        throw APIError.notFound(.resourceMissing)
    }
    func convocatorias(accessToken: String) async throws -> [ConvocatoriaSummaryDTO] {
        throw APIError.notFound(.resourceMissing)
    }
    func convocatoriaDetail(id: String, accessToken: String) async throws -> ConvocatoriaSummaryDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func ranking(convocatoriaId: String, accessToken: String) async throws -> RankingResponseDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func matrix(convocatoriaId: String, accessToken: String) async throws -> MatrixResponseDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func attempt(id: String, accessToken: String) async throws -> AttemptDetailDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func managerDashboard(accessToken: String) async throws -> ManagerDashboardDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func studentProfile(studentId: String, accessToken: String) async throws -> StudentProfileDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func webfletAlerts(accessToken: String) async throws -> WebfletAlertsResponseDTO {
        throw APIError.notFound(.resourceMissing)
    }
    func webfletSync(accessToken: String) async throws -> SyncResultDTO {
        throw APIError.notFound(.resourceMissing)
    }
}

// MARK: - Fixtures

extension UserDTO {
    static func stub(id: String = "u-1", role: String = "STUDENT") -> UserDTO {
        UserDTO(
            id: id,
            email: "aspirante@cmadrid.example",
            name: "Aspirante de prueba",
            role: role,
            organizationId: "org-1",
            studentProfileId: nil
        )
    }
}

extension AuthLoginResponseDTO {
    static func stub(
        access: String = "access-1",
        refresh: String = "refresh-1",
        user: UserDTO = .stub()
    ) -> AuthLoginResponseDTO {
        AuthLoginResponseDTO(
            access_token: access,
            refresh_token: refresh,
            token_type: "Bearer",
            expires_in: 3600,
            user: user
        )
    }
}

extension RefreshResponseDTO {
    static func stub(access: String = "access-2") -> RefreshResponseDTO {
        RefreshResponseDTO(access_token: access, expires_in: 3600)
    }
}

extension StandingDTO {
    static func stub(
        position: Int = 3,
        requiredRoutes: [String]? = nil,
        completedRequired: Int? = nil,
        pendingRequired: Int? = nil,
        scoreOfCompleted: Double? = nil
    ) -> StandingDTO {
        StandingDTO(
            convocatoriaId: "conv-1",
            position: position,
            totalCandidates: 42,
            score: 7.5,
            attemptsCompleted: 3,
            attemptsTotal: 5,
            status: "ACTIVE",
            requiredRoutes: requiredRoutes,
            completedRequired: completedRequired,
            pendingRequired: pendingRequired,
            scoreOfCompleted: scoreOfCompleted
        )
    }
}
