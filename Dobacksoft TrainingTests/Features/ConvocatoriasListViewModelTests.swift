import Testing
import Foundation

@testable import Dobacksoft_Training

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// The convocatorias list — the screen every role lands on.
///
/// It was the last data screen still blanking to a spinner on every reload and
/// replacing loaded content with an error, the discipline `StandingViewModel`
/// and `ProgressViewModel` already have. That was survivable while data loaded
/// once per launch. It is not survivable now that returning to the app after
/// five minutes reloads on its own: a weak signal in the corridor would wipe
/// the list the candidate was reading, unprompted.
extension KeychainBacked {
    @MainActor
    struct ConvocatoriasListViewModelTests {
        init() { try? TokenStore.clearAll() }

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")
            return session
        }

        private func convocatoria(id: String = "c1", name: String = "Oposición 2026") -> ConvocatoriaSummaryDTO {
            ConvocatoriaSummaryDTO(
                id: id, name: name, description: nil, status: "OPEN",
                totalCandidates: 0, closedAt: nil, updatedAt: nil
            )
        }

        // MARK: - Qué endpoint según el rol

        /// The candidate asks for their own enrolments; the instructor for the
        /// catalogue. They are different endpoints with different permissions,
        /// and the queues are separate so a mix-up fails instead of passing.
        @Test func theCandidateAsksForTheirOwnEnrolments() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([convocatoria()])])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: true)

            #expect(await api.myConvocatoriasCalls == 1)
            #expect(await api.convocatoriasCalls == 0)
        }

        @Test func theInstructorAsksForTheCatalogue() async throws {
            let api = FakeTrainingAPI()
            await api.setConvocatoriasResults([.success([convocatoria()])])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: false)

            #expect(await api.convocatoriasCalls == 1)
            #expect(await api.myConvocatoriasCalls == 0)
        }

        // MARK: - Carga y vacío

        @Test func aLoadedListReachesTheScreen() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([convocatoria()])])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: true)

            #expect(vm.state == .loaded([convocatoria()]))
            #expect(vm.lastUpdated == t0)
            #expect(vm.refreshError == nil)
        }

        /// No enrolments is a legitimate answer, not a failure, and it must not
        /// carry a timestamp claiming data was read — there was none.
        @Test func anEmptyListIsItsOwnStateAndNotAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([])])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: true)

            #expect(vm.state == .empty)
        }

        // MARK: - Un refresco que falla no borra lo que había

        /// The defect this closes: a second load that fails used to replace the
        /// list with «No se ha podido conectar». Now the list stays and the
        /// failure is a note beside it.
        @Test func aFailedRefreshKeepsTheListAndExplainsItself() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .success([convocatoria()]),
                .failure(APIError.transport(URLError(.notConnectedToInternet)))
            ])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: true)
            await vm.load(auth: auth, isStudent: true)

            #expect(vm.state == .loaded([convocatoria()]), "la lista sigue en pantalla")
            let note = try #require(vm.refreshError)
            #expect(note.contains("último dato consultado"))
            #expect(vm.isRefreshing == false)
        }

        /// And the timestamp belongs to the DATA, not to the attempt to refresh
        /// it. Moving it forward on a failure would date stale figures as fresh,
        /// which is worse than not dating them at all.
        @Test func aFailedRefreshDoesNotMoveTheTimestamp() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .success([convocatoria()]),
                .failure(APIError.transport(URLError(.timedOut)))
            ])
            let auth = try await session(api)
            var clock = t0
            let vm = ConvocatoriasListViewModel(api: api, now: { clock })

            await vm.load(auth: auth, isStudent: true)
            clock = t0.addingTimeInterval(3600)
            await vm.load(auth: auth, isStudent: true)

            #expect(vm.lastUpdated == t0, "la hora es la del dato que se está viendo")
        }

        /// The control case: without data on screen there is nothing to keep,
        /// so a failure IS the state. Otherwise the two tests above would pass
        /// for a view model that simply never reports errors.
        @Test func aFirstLoadThatFailsIsAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .failure(APIError.transport(URLError(.notConnectedToInternet)))
            ])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: true)

            if case .error = vm.state {} else {
                Issue.record("se esperaba .error, y llegó \(vm.state)")
            }
            #expect(vm.refreshError == nil, "sin datos que conservar no hay nota al margen")
            #expect(vm.lastUpdated == nil)
        }

        /// A successful refresh after a failed one clears the note. A warning
        /// that outlives its cause teaches people to ignore warnings.
        @Test func aSuccessfulRefreshClearsTheNote() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .success([convocatoria()]),
                .failure(APIError.transport(URLError(.timedOut))),
                .success([convocatoria(id: "c2", name: "Oposición 2027")])
            ])
            let auth = try await session(api)
            var clock = t0
            let vm = ConvocatoriasListViewModel(api: api, now: { clock })

            await vm.load(auth: auth, isStudent: true)
            await vm.load(auth: auth, isStudent: true)
            clock = t0.addingTimeInterval(7200)
            await vm.load(auth: auth, isStudent: true)

            #expect(vm.refreshError == nil)
            #expect(vm.state == .loaded([convocatoria(id: "c2", name: "Oposición 2027")]))
            #expect(vm.lastUpdated == t0.addingTimeInterval(7200))
        }

        /// An empty answer on a REFRESH is real: someone whose enrolment was
        /// withdrawn must see it. It is not treated as «keep the old list».
        @Test func aRefreshThatComesBackEmptyIsBelieved() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([convocatoria()]), .success([])])
            let auth = try await session(api)
            let vm = ConvocatoriasListViewModel(api: api, now: { t0 })

            await vm.load(auth: auth, isStudent: true)
            await vm.load(auth: auth, isStudent: true)

            #expect(vm.state == .empty)
        }
    }
}
