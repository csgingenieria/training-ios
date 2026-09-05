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

            await session.logout()

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
    }
}
