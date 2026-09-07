import Testing
import Foundation

@testable import Dobacksoft_Training

/// `AuthSession` is `@MainActor`-isolated, so the suite is too.
///
/// These cases drive the real `login()`, `restoreFromKeychain()` and
/// refresh-on-401 paths through a scripted `TrainingAPI`. Before the protocol
/// existed the suite could only assert on values it had just assigned itself.
extension KeychainBacked {
    @MainActor
    struct AuthSessionTests {
        init() {
            try? TokenStore.clearAll()
        }

        // MARK: - Estado base

        @Test func initialSessionIsNotAuthenticated() {
            let session = AuthSession(api: FakeTrainingAPI())
            #expect(session.isAuthenticated == false)
            #expect(session.hasRestoredSession == false)
            #expect(session.user == nil)
            #expect(session.accessToken == nil)
            #expect(session.refreshToken == nil)
        }

        @Test func previewSessionIsAuthenticated() {
            let session = AuthSession.previewAuthenticated
            #expect(session.isAuthenticated == true)
            #expect(session.user?.isAdminLike == true)
            #expect(session.user?.isStudent == false)
        }

        // MARK: - Login

        @Test func loginStoresTokensAndUser() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)

            try await session.login(email: "aspirante@cmadrid.example", password: "secreto")

            #expect(session.accessToken == "acc")
            #expect(session.refreshToken == "ref")
            #expect(session.user?.id == "u-1")
            #expect(session.isAuthenticated == true)
            #expect(try TokenStore.load(for: .accessToken) == "acc")
            #expect(try TokenStore.load(for: .refreshToken) == "ref")
        }

        @Test func failedLoginLeavesNoSession() async {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.failure(APIError.unauthenticated))
            let session = AuthSession(api: api)

            await #expect(throws: APIError.self) {
                try await session.login(email: "quien@cmadrid.example", password: "mal")
            }

            #expect(session.isAuthenticated == false)
            #expect(session.accessToken == nil)
        }

        @Test func logoutClearsMemoryAndKeychain() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub()))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await session.logout(reason: .userInitiated)

            #expect(session.isAuthenticated == false)
            #expect(session.user == nil)
            #expect(try TokenStore.load(for: .accessToken) == nil)
            #expect(try TokenStore.load(for: .refreshToken) == nil)
        }

        // MARK: - Restauración al arrancar

        @Test func restoreUsesStoredAccessTokenWhenStillValid() async throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.success(.stub())])
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()

            #expect(session.isAuthenticated == true)
            #expect(await api.refreshCalls.isEmpty)
        }

        @Test func restoreRefreshesWhenStoredAccessTokenExpired() async throws {
            try TokenStore.save("caducado", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.failure(APIError.unauthenticated), .success(.stub())])
            await api.setRefreshResult(.success(.stub(access: "renovado")))
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()

            #expect(session.isAuthenticated == true)
            #expect(session.accessToken == "renovado")
            #expect(await api.refreshCalls == ["ref"])
        }

        /// Both tokens rejected: nothing to salvage, so the session is dropped.
        @Test func restoreLogsOutWhenRefreshAlsoFails() async throws {
            try TokenStore.save("caducado", for: .accessToken)
            try TokenStore.save("tambien-caducado", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.failure(APIError.unauthenticated)])
            await api.setRefreshResult(.failure(APIError.unauthenticated))
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()

            #expect(session.isAuthenticated == false)
            #expect(try TokenStore.load(for: .accessToken) == nil)
        }

        /// A flaky network is not an expired session: keep the tokens.
        @Test func restoreKeepsTokensOnTransportFailure() async throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.failure(APIError.transport(URLError(.timedOut)))])
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()

            #expect(session.user == nil)
            #expect(try TokenStore.load(for: .accessToken) == "acc")
        }

        @Test func restoreRunsOnlyOnce() async throws {
            try TokenStore.save("acc", for: .accessToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.success(.stub()), .success(.stub())])
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()
            await session.restoreFromKeychain()

            #expect(await api.meTokens.count == 1)
        }

        // MARK: - Refresco durante el uso (el hueco que cerró la fase 2)

        @Test func authorizedPassesTheCurrentToken() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            let seen = try await session.authorized { $0 }

            #expect(seen == "acc")
        }

        @Test func authorizedRefreshesAndRetriesAfter401() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "viejo", refresh: "ref")))
            await api.setRefreshResult(.success(.stub(access: "nuevo")))
            await api.setStandingResults([.failure(APIError.unauthenticated), .success(.stub())])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            let standing = try await session.authorized { token in
                try await api.standing(convocatoriaId: "conv-1", accessToken: token)
            }

            #expect(standing.position == 3)
            #expect(await api.standingTokens == ["viejo", "nuevo"])
            #expect(session.accessToken == "nuevo")
            #expect(session.isAuthenticated == true)
        }

        /// The refreshed token is persisted, so the next launch starts from it.
        @Test func refreshedTokenReachesTheKeychain() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "viejo", refresh: "ref")))
            await api.setRefreshResult(.success(.stub(access: "nuevo")))
            await api.setStandingResults([.failure(APIError.unauthenticated), .success(.stub())])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            _ = try await session.authorized { token in
                try await api.standing(convocatoriaId: "conv-1", accessToken: token)
            }

            #expect(try TokenStore.load(for: .accessToken) == "nuevo")
        }

        @Test func authorizedLogsOutWhenRefreshFails() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "viejo", refresh: "ref")))
            await api.setRefreshResult(.failure(APIError.unauthenticated))
            await api.setStandingResults([.failure(APIError.unauthenticated)])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(session.isAuthenticated == false)
        }

        /// One retry, not a loop: a token the backend keeps rejecting ends the session.
        @Test func authorizedRetriesOnlyOnce() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "viejo", refresh: "ref")))
            await api.setRefreshResult(.success(.stub(access: "nuevo")))
            await api.setStandingResults([
                .failure(APIError.unauthenticated),
                .failure(APIError.unauthenticated),
            ])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(await api.standingTokens.count == 2)
            #expect(await api.refreshCalls.count == 1)
            #expect(session.isAuthenticated == false)
        }

        /// Errors other than 401 travel untouched: a 429 must not trigger a refresh.
        @Test func authorizedDoesNotRefreshOnOtherErrors() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            await api.setStandingResults([.failure(APIError.rateLimited(retryAfter: 20))])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(await api.refreshCalls.isEmpty)
            #expect(session.isAuthenticated == true)
        }

        /// A tunnel is not a revoked session.
        ///
        /// The refresh used to collapse every failure into nil, and the caller
        /// read nil as "the backend rejected us" and logged out. A firefighter
        /// losing coverage for a moment was signed out and had to type their
        /// credentials again.
        @Test func transportFailureDuringRefreshKeepsTheSession() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            await api.setRefreshResult(.failure(APIError.transport(URLError(.notConnectedToInternet))))
            await api.setStandingResults([.failure(APIError.unauthenticated)])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(session.isAuthenticated == true)
            #expect(session.accessToken == "acc")
            #expect(try TokenStore.load(for: .refreshToken) == "ref")
        }

        /// The backend actively rejecting the refresh token IS a dead session.
        @Test func rejectedRefreshDoesEndTheSession() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            await api.setRefreshResult(.failure(APIError.unauthenticated))
            await api.setStandingResults([.failure(APIError.unauthenticated)])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(session.isAuthenticated == false)
        }

        /// A server-side failure is not a verdict on the credentials either.
        @Test func serverErrorDuringRefreshKeepsTheSession() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            await api.setRefreshResult(.failure(APIError.server(message: "boom", status: 503)))
            await api.setStandingResults([.failure(APIError.unauthenticated)])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(session.isAuthenticated == true)
        }

        @Test func authorizedFailsFastWithoutSession() async {
            let session = AuthSession(api: FakeTrainingAPI())

            await #expect(throws: APIError.self) {
                try await session.authorized { $0 }
            }
        }

        // MARK: - Lo que la sesión le cuenta a la persona

        // The state transitions above were already right; what they never did
        // was say anything. Both endings — «no hay red» and «tus credenciales
        // caducaron» — dropped the candidate on an empty login form, and the
        // two need opposite messages: one says the session is intact, the other
        // asks for the password again.

        /// A transport failure during restore records the reason.
        ///
        /// `restoreKeepsTokensOnTransportFailure` above proves the tokens
        /// survive. This proves the app can now say so: without the recorded
        /// failure, `RootView` cannot tell «sin conexión, su sesión sigue
        /// activa» apart from «no ha iniciado sesión».
        @Test func restoreTransportFailureIsRecordedWithTheTokensIntact() async throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.failure(APIError.transport(URLError(.notConnectedToInternet)))])
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()

            #expect(session.restoreFailure != nil)
            #expect(session.user == nil)
            #expect(session.refreshToken == "ref")
            #expect(session.logoutReason == nil, "no se ha cerrado la sesión: no hay motivo de cierre")
            #expect(session.canRetryRestore, "hay refresh token guardado, así que se puede reintentar")
        }

        /// A rejected refresh token is the one case that really ends the
        /// session, and the candidate has to read why.
        @Test func rejectedRefreshRecordsSessionExpired() async throws {
            try TokenStore.save("caducado", for: .accessToken)
            try TokenStore.save("tambien-caducado", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.failure(APIError.unauthenticated)])
            await api.setRefreshResult(.failure(APIError.unauthenticated))
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()

            #expect(session.logoutReason == .sessionExpired)
            #expect(session.restoreFailure == nil, "no es un fallo de red: es una credencial rechazada")
            #expect(session.isAuthenticated == false)
            #expect(session.canRetryRestore == false, "sin tokens no hay nada que reintentar")
        }

        /// A 401 mid-session ends it the same way, and must say so too: the
        /// candidate was reading their position, not sitting on a login form.
        @Test func aRejectedRefreshMidSessionAlsoRecordsSessionExpired() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "viejo", refresh: "ref")))
            await api.setRefreshResult(.failure(APIError.unauthenticated))
            await api.setStandingResults([.failure(APIError.unauthenticated)])
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await #expect(throws: APIError.self) {
                try await session.authorized { token in
                    try await api.standing(convocatoriaId: "conv-1", accessToken: token)
                }
            }

            #expect(session.logoutReason == .sessionExpired)
        }

        /// Pressing «Cerrar sesión» is not a failure and must not be dressed as
        /// one: nothing to explain, nothing to retry.
        @Test func explicitLogoutIsNotReportedAsAnExpiry() async throws {
            let api = FakeTrainingAPI()
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")

            await session.logout(reason: .userInitiated)

            #expect(session.logoutReason == .userInitiated)
            #expect(session.isAuthenticated == false)
        }

        /// Signing in clears both signals: a banner about the previous attempt
        /// on top of a session that already works is a lie.
        @Test func signingInClearsEveryPreviousSignal() async throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([.failure(APIError.transport(URLError(.timedOut)))])
            await api.setLoginResult(.success(.stub(access: "nuevo", refresh: "nuevo-ref")))
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()
            #expect(session.restoreFailure != nil)

            try await session.login(email: "a@b.example", password: "x")

            #expect(session.restoreFailure == nil)
            #expect(session.logoutReason == nil)
        }

        /// A restore that succeeds after a failed one leaves no trace either.
        @Test func aSuccessfulRetryClearsTheRecordedFailure() async throws {
            try TokenStore.save("acc", for: .accessToken)
            try TokenStore.save("ref", for: .refreshToken)
            let api = FakeTrainingAPI()
            await api.setMeResults([
                .failure(APIError.transport(URLError(.timedOut))),
                .success(.stub()),
            ])
            let session = AuthSession(api: api)

            await session.restoreFromKeychain()
            #expect(session.restoreFailure != nil)

            await session.retryRestore()

            #expect(session.restoreFailure == nil)
            #expect(session.isAuthenticated == true)
        }
    }
}
