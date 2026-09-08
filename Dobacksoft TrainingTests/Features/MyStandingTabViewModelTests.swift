import Testing
import Foundation

@testable import Dobacksoft_Training

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// The candidate's home screen — the list of their convocatorias.
///
/// **This was the audit's open blocker.** `load()` filled `convocatorias` and
/// never cleared `errorMessage`, and the body checked the error before the
/// content, so after ONE transient failure the main STUDENT screen showed
/// «Error … Reintentar» for ever. Tapping Reintentar fetched the data,
/// assigned it, and still rendered the error. The only way out was killing the
/// app.
///
/// It survived a whole day of work on top of it, and `RefreshTicker` made it
/// worse rather than better: the screen now reloads on return to the
/// foreground, so a lost signal in a corridor could strand it without the
/// candidate having touched anything.
///
/// The state lives in a view model with one mutually exclusive enum, which is
/// what makes the recovery expressible at all — inside the View it was three
/// independent flags that could contradict each other.
extension KeychainBacked {
    @MainActor
    struct MyStandingTabViewModelTests {
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

        // MARK: - El bloqueante

        /// **The test that was impossible to write before**, because the state
        /// lived in the View. One failure, then a retry that succeeds: the
        /// screen has to show the data.
        @Test func aRetryAfterOneFailureRecovers() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .failure(APIError.transport(URLError(.timedOut))),
                .success([convocatoria()])
            ])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)
            await vm.load(auth: auth)

            #expect(vm.state == .loaded([convocatoria()]), "el error se quedaba pegado para siempre")
        }

        /// The control half: the first failure IS an error. Without it the test
        /// above would pass for a view model that never reports failures.
        @Test func theFirstFailureIsAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.failure(APIError.transport(URLError(.timedOut)))])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)

            if case .error = vm.state {} else {
                Issue.record("se esperaba .error, y llegó \(vm.state)")
            }
        }

        /// And the states are mutually exclusive by construction. Three
        /// independent flags in a View could say «loading» and «error» and
        /// «here is your data» at the same time, and the branch order decided
        /// which lie won.
        @Test func theStatesCannotContradictEachOther() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([convocatoria()])])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)

            #expect(vm.state == .loaded([convocatoria()]))
            #expect(vm.state != .loading)
        }

        // MARK: - La convocatoria elegida

        @Test func theFirstConvocatoriaIsSelected() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([convocatoria(id: "a"), convocatoria(id: "b")])])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)

            #expect(vm.selectedId == "a")
        }

        /// A selection the candidate made survives a reload. Resetting it on
        /// every refresh would bounce them back to the first convocatoria every
        /// time they returned to the app.
        @Test func aChosenConvocatoriaSurvivesAReload() async throws {
            let api = FakeTrainingAPI()
            let two = [convocatoria(id: "a"), convocatoria(id: "b")]
            await api.setMyConvocatoriasResults([.success(two), .success(two)])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)
            vm.selectedId = "b"
            await vm.load(auth: auth)

            #expect(vm.selectedId == "b")
        }

        /// But a selection that no longer exists is replaced. An enrolment can
        /// be withdrawn, and pointing at a convocatoria that is gone renders
        /// nothing at all.
        @Test func aSelectionThatVanishedIsReplaced() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .success([convocatoria(id: "a"), convocatoria(id: "b")]),
                .success([convocatoria(id: "a")])
            ])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)
            vm.selectedId = "b"
            await vm.load(auth: auth)

            #expect(vm.selectedId == "a")
        }

        // MARK: - Vacío, y refresco que falla

        @Test func noEnrolmentsIsItsOwnState() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([.success([])])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)

            #expect(vm.state == .empty)
            #expect(vm.selectedId == nil)
        }

        /// Same discipline as the other screens: a failed refresh over visible
        /// data keeps the data and says so beside it.
        @Test func aFailedRefreshKeepsTheList() async throws {
            let api = FakeTrainingAPI()
            await api.setMyConvocatoriasResults([
                .success([convocatoria()]),
                .failure(APIError.transport(URLError(.notConnectedToInternet)))
            ])
            let auth = try await session(api)
            let vm = MyStandingTabViewModel(api: api, now: { t0 })

            await vm.load(auth: auth)
            await vm.load(auth: auth)

            #expect(vm.state == .loaded([convocatoria()]))
            #expect(vm.refreshError != nil)
        }
    }
}
