import Testing
import Foundation

@testable import Dobacksoft_Training

/// La lista de vueltas del aspirante.
///
/// Era el décimo modelo de vista, y el único que seguía llamando al cliente
/// compartido cuando la memoria ya decía que la costura estaba cerrada. Lo
/// encontró la revisión adversarial de la entrega: la afirmación «cuatro de
/// cuatro» era cierta para los cuatro que se contaron, y falsa para el que no.
extension KeychainBacked {
    @MainActor
    struct MyAttemptsViewModelTests {
        init() { try? TokenStore.clearAll() }

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")
            return session
        }

        @Test func conVueltasQuedaCargado() async throws {
            let api = FakeTrainingAPI()
            await api.setMyAttemptsResults([.success([
                AttemptSummaryDTO(id: "v1", score: 7.5),
                AttemptSummaryDTO(id: "v2")
            ])])
            let vm = MyAttemptsViewModel(api: api)

            await vm.load(convocatoriaId: "c1", auth: try await session(api))

            guard case .loaded(let items) = vm.state else {
                Issue.record("Se esperaba .loaded y llegó \(vm.state)"); return
            }
            #expect(items.map(\.id) == ["v1", "v2"])
        }

        /// Vacío no es error: alguien que aún no ha conducido no ha fallado.
        @Test func sinVueltasQuedaVacioNoEnError() async throws {
            let api = FakeTrainingAPI()
            await api.setMyAttemptsResults([.success([])])
            let vm = MyAttemptsViewModel(api: api)

            await vm.load(convocatoriaId: "c1", auth: try await session(api))

            guard case .empty = vm.state else {
                Issue.record("Se esperaba .empty y llegó \(vm.state)"); return
            }
        }

        /// Y el control del anterior: un fallo de red **sí** es error, con el
        /// texto para el usuario y no el del sistema.
        @Test func unFalloDeRedSiEsError() async throws {
            let api = FakeTrainingAPI()
            await api.setMyAttemptsResults([.failure(APIError.transport(URLError(.timedOut)))])
            let vm = MyAttemptsViewModel(api: api)

            await vm.load(convocatoriaId: "c1", auth: try await session(api))

            guard case .error(let mensaje) = vm.state else {
                Issue.record("Se esperaba .error y llegó \(vm.state)"); return
            }
            #expect(mensaje == APIError.transport(URLError(.timedOut)).userMessage)
        }
    }
}
