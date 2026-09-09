import Testing
import Foundation

@testable import Dobacksoft_Training

/// El detalle del intento cuando se refresca y falla.
///
/// Era la ÚLTIMA pantalla de datos que seguía vaciándose a un spinner en cada
/// recarga y volviendo como error. Y es una a la que se entra a tirar hacia
/// abajo a propósito: se llega para ver si ya llegó la nota. Con cobertura mala
/// en un parque, el intento que se estaba leyendo desaparecía.
///
/// Fue la última en arreglarse por una razón concreta: su view model usaba
/// `APIClient.shared` directo y no tenía costura, así que el arreglo no se
/// podía probar. Añadirla fue la mitad del trabajo.
extension KeychainBacked {
    @MainActor
    struct AttemptDetailRefreshTests {
        init() { try? TokenStore.clearAll() }

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")
            return session
        }

        /// Se decodifica de un JSON mínimo en vez de construirse a mano: el
        /// DTO tiene veintitantos campos y nombrarlos todos en cada test los
        /// haría ilegibles sin probar nada más.
        ///
        /// `scoreBreakdown` y `events` van aquí porque **no son opcionales** en
        /// `AttemptDetailDTO`: sin esas claves la respuesta entera no decodifica
        /// y la pantalla más visitada del aspirante se cae. `RouteDetailDTO`
        /// hace lo contrario con las suyas (`decodeIfPresent … ?? []`).
        ///
        /// No se cambia aquí: staging las manda siempre —el recorrido pasa— y
        /// añadir tolerancia sin evidencia de que falten sería especular. Queda
        /// anotado como asimetría real entre dos DTO hermanos.
        private func attempt(score: Double = 8.5) throws -> AttemptDetailDTO {
            try JSONDecoder().decode(
                AttemptDetailDTO.self,
                from: Data(#"{"id": "a-1", "score": \#(score), "scoreBreakdown": [], "events": []}"#.utf8)
            )
        }

        /// **El caso que importa.** Datos en pantalla, refresco que falla,
        /// datos que se quedan.
        @Test func aFailedRefreshKeepsTheAttemptOnScreen() async throws {
            let api = FakeTrainingAPI()
            await api.setAttemptResults([
                .success(try attempt()),
                .failure(APIError.transport(URLError(.notConnectedToInternet)))
            ])
            let auth = try await session(api)
            let vm = AttemptDetailViewModel(api: api)

            await vm.load(attemptId: "a-1", auth: auth)
            await vm.load(attemptId: "a-1", auth: auth)

            guard case .loaded = vm.state else {
                Issue.record("el refresco fallido se llevó el intento: \(vm.state)")
                return
            }
            let nota = try #require(vm.refreshError)
            #expect(nota.contains("último dato consultado"))
            #expect(vm.isRefreshing == false)
        }

        /// El control: sin datos en pantalla, el fallo SÍ es el estado. Sin él
        /// el test de arriba pasaría para un view model que nunca informa de un
        /// error.
        @Test func aFirstLoadThatFailsIsStillAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setAttemptResults([.failure(APIError.transport(URLError(.timedOut)))])
            let auth = try await session(api)
            let vm = AttemptDetailViewModel(api: api)

            await vm.load(attemptId: "a-1", auth: auth)

            guard case .error = vm.state else {
                Issue.record("se esperaba .error, y llegó \(vm.state)")
                return
            }
            #expect(vm.refreshError == nil, "no es un refresco fallido, es una carga fallida")
        }

        /// Un intento que ya no consta **no** se conserva. Es una respuesta del
        /// backend, no una ausencia de red: enseñar el de antes diría que sigue
        /// existiendo.
        @Test func anAttemptThatNoLongerExistsIsNotKept() async throws {
            let api = FakeTrainingAPI()
            await api.setAttemptResults([
                .success(try attempt()),
                .failure(APIError.notFound(.resourceMissing))
            ])
            let auth = try await session(api)
            let vm = AttemptDetailViewModel(api: api)

            await vm.load(attemptId: "a-1", auth: auth)
            await vm.load(attemptId: "a-1", auth: auth)

            guard case .notFound = vm.state else {
                Issue.record("una respuesta del backend se tapó con el dato viejo: \(vm.state)")
                return
            }
        }

        /// Y un refresco que va bien limpia la nota: un aviso que sobrevive a
        /// su causa enseña a ignorar los avisos.
        @Test func aSuccessfulRefreshClearsTheNote() async throws {
            let api = FakeTrainingAPI()
            await api.setAttemptResults([
                .success(try attempt(score: 8.5)),
                .failure(APIError.transport(URLError(.timedOut))),
                .success(try attempt(score: 9.0))
            ])
            let auth = try await session(api)
            let vm = AttemptDetailViewModel(api: api)

            await vm.load(attemptId: "a-1", auth: auth)
            await vm.load(attemptId: "a-1", auth: auth)
            await vm.load(attemptId: "a-1", auth: auth)

            #expect(vm.refreshError == nil)
            guard case let .loaded(cargado) = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
            #expect(cargado.score == 9.0)
        }
    }
}
