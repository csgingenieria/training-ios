import Testing
import Foundation

@testable import Dobacksoft_Training

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// The progress screen's view model.
///
/// Same discipline as `StandingViewModel`: a failed refresh keeps the data
/// already on screen, `notFound` is not data worth preserving, and the
/// timestamp is the data's and not the attempt's to refresh it. Written that way
/// from the start rather than fixed later, which is the whole point of having
/// found it once.
extension KeychainBacked {
    @MainActor
    struct ProgressViewModelTests {
        init() { try? TokenStore.clearAll() }

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")
            return session
        }

        private func progreso(score: Double = 6.0, presented: Bool = true) -> ProgressDTO {
            ProgressDTO(
                candidate: nil, convocatoria: nil, activeEnrollments: [],
                score: score, presented: presented,
                requiredRoutes: ["1A", "1B"], completedRequired: 1, pendingRequired: 1,
                scoreOfCompleted: 9.0, attempts: [], evolution: [],
                bestRoute: nil, worstRoute: nil
            )
        }

        // MARK: - Carga

        @Test func aLoadedProgressReachesTheScreen() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([.success(progreso(score: 7.5))])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: "c-1", auth: auth)

            guard case let .loaded(p) = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
            #expect(p.score == 7.5)
            #expect(vm.lastUpdated == t0)
        }

        /// The 404 the backend documents: no `ACTIVE` enrolment. It is an
        /// answer, not a failure, and it must not read as one.
        @Test func notEnrolledIsAnAnswerAndNotAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([.failure(APIError.notFound(.notEnrolled))])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: "c-1", auth: auth)

            guard case let .notFound(reason) = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
            #expect(reason == .notEnrolled)
        }

        // MARK: - Refresco, con la lección ya aprendida

        @Test func aFailedRefreshKeepsTheProgressOnScreen() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([
                .success(progreso(score: 7.5)),
                .failure(APIError.transport(URLError(.notConnectedToInternet))),
            ])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: "c-1", auth: auth)
            await vm.load(convocatoriaId: "c-1", auth: auth)

            guard case let .loaded(p) = vm.state else {
                Issue.record("el refresco fallido se llevó los datos: \(vm.state)")
                return
            }
            #expect(p.score == 7.5)
            #expect(vm.refreshError != nil)
        }

        @Test func aFailedRefreshDoesNotAgeTheDataForward() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([
                .success(progreso()),
                .failure(APIError.transport(URLError(.timedOut))),
            ])
            let auth = try await session(api)
            let reloj = TestClock(t0)
            let vm = ProgressViewModel(api: api, now: reloj.now)

            await vm.load(convocatoriaId: "c-1", auth: auth)
            reloj.advance(to: t0.addingTimeInterval(900))
            await vm.load(convocatoriaId: "c-1", auth: auth)

            #expect(vm.lastUpdated == t0, "la hora es la del dato, no la del intento")
        }

        @Test func theFirstFailureIsStillAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([.failure(APIError.transport(URLError(.timedOut)))])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: "c-1", auth: auth)

            guard case .error = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
            #expect(vm.refreshError == nil)
        }

        /// `notFound` is not data: a later network failure must not dress up an
        /// absence as a progress that exists.
        @Test func notFoundIsNotDataToPreserve() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([
                .failure(APIError.notFound(.notEnrolled)),
                .failure(APIError.transport(URLError(.timedOut))),
            ])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: "c-1", auth: auth)
            await vm.load(convocatoriaId: "c-1", auth: auth)

            guard case .error = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
        }

        // MARK: - El parámetro que no puede viajar vacío

        /// The client must never send `?conv_id=` empty — the backend answers
        /// 400 and, worse, its own fallback would answer about another
        /// convocatoria. Here the view model simply must not invent one.
        @Test func noConvocatoriaIsPassedThroughAsNothing() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([.success(progreso())])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: nil, auth: auth)

            #expect(await api.progressConvocatoriaIds == [nil])
        }

        @Test func aBlankConvocatoriaIsNotForwardedEither() async throws {
            let api = FakeTrainingAPI()
            await api.setProgressResults([.success(progreso())])
            let auth = try await session(api)
            let vm = ProgressViewModel(api: api, now: { t0 })

            await vm.load(convocatoriaId: "   ", auth: auth)

            #expect(await api.progressConvocatoriaIds == [nil], "en blanco es lo mismo que nada")
        }
    }
}
