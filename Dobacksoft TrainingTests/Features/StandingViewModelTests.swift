import Testing
import Foundation

@testable import Dobacksoft_Training

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// What the screen does with a refresh that fails.
///
/// Until now every reload began with `state = .loading` and ended, on failure,
/// with `state = .error`. So a pull-to-refresh on a weak signal wiped the
/// position card the candidate was reading and replaced it with an error — the
/// grade they already had, gone, because the network hiccuped while they looked
/// at it.
///
/// The widget this same view model feeds already got this right, and said so:
/// «un fallo de red pasajero no debe borrar el último dato bueno». The screen
/// did not follow its own rule.
extension KeychainBacked {
    @MainActor
    struct StandingViewModelTests {
        init() { try? TokenStore.clearAll() }

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")
            return session
        }

        /// El almacén se inyecta AISLADO, como el reloj y el API.
        ///
        /// Por defecto `StandingViewModel` usa el contenedor real de la app, y
        /// sin esto estos tests dependían de lo que otro test hubiera dejado en
        /// disco: dos de ellos empezaron a fallar en cuanto la caché se
        /// conectó, no por su expectativa —que es correcta, una primera carga
        /// fallida SIN caché es un error— sino porque encontraban una.
        ///
        /// Un test cuyo resultado depende de un fichero compartido es de la
        /// clase que solo falla acompañada: verde en la máquina de quien lo
        /// escribe, rojo en el CI. Cada uno con su directorio.
        private func viewModel(_ api: FakeTrainingAPI, now: Date = t0) -> StandingViewModel {
            StandingViewModel(api: api, now: { now }, lastGood: isolatedStore())
        }

        private func isolatedStore() -> LastGoodStore {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("standing-vm-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return LastGoodStore(directory: url)
        }

        // MARK: - Conservar el dato bueno

        /// The case that matters: data on screen, refresh fails, data stays.
        @Test func aFailedRefreshKeepsTheDataAlreadyOnScreen() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([
                .success(.stub(position: 3)),
                .failure(APIError.transport(URLError(.notConnectedToInternet))),
            ])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)
            await vm.load(convocatoriaId: "conv-1", auth: auth)

            guard case let .loaded(standing) = vm.state else {
                Issue.record("el refresco fallido se llevó por delante los datos: \(vm.state)")
                return
            }
            #expect(standing.position == 3)
            #expect(vm.refreshError != nil, "el fallo se cuenta, pero aparte")
        }

        /// …and the message says what happened without blaming the candidate
        /// or implying the number on screen is wrong.
        @Test func theRefreshErrorSaysTheDataIsTheLastOneRead() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([
                .success(.stub()),
                .failure(APIError.transport(URLError(.timedOut))),
            ])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)
            await vm.load(convocatoriaId: "conv-1", auth: auth)

            let mensaje = try #require(vm.refreshError)
            #expect(mensaje.contains("último dato"), "«\(mensaje)» no dice que lo mostrado es lo último leído")
        }

        /// With nothing on screen there is nothing to protect: the first
        /// failure is still a full error state.
        @Test func theFirstFailureIsStillAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(APIError.transport(URLError(.timedOut)))])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)

            guard case .error = vm.state else {
                Issue.record("sin datos previos el fallo tiene que verse: \(vm.state)")
                return
            }
            #expect(vm.refreshError == nil, "no es un refresco fallido, es una carga fallida")
        }

        @Test func aRecoveredRefreshClearsTheWarning() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([
                .success(.stub(position: 3)),
                .failure(APIError.transport(URLError(.timedOut))),
                .success(.stub(position: 2)),
            ])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)
            await vm.load(convocatoriaId: "conv-1", auth: auth)
            await vm.load(convocatoriaId: "conv-1", auth: auth)

            #expect(vm.refreshError == nil)
            guard case let .loaded(standing) = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
            #expect(standing.position == 2, "el dato nuevo sustituye al viejo")
        }

        /// `notFound` is a legitimate answer, not data worth protecting: a
        /// later failure must not dress it up as a position that exists.
        @Test func notFoundIsNotDataToPreserve() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([
                .failure(APIError.notFound(.noStandingYet)),
                .failure(APIError.transport(URLError(.timedOut))),
            ])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)
            await vm.load(convocatoriaId: "conv-1", auth: auth)

            guard case .error = vm.state else {
                Issue.record("estado inesperado: \(vm.state)")
                return
            }
            #expect(vm.refreshError == nil)
        }

        // MARK: - Edad del dato

        @Test func theTimeOfTheDataIsRecorded() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.success(.stub())])
            let auth = try await session(api)
            let vm = viewModel(api, now: t0)

            await vm.load(convocatoriaId: "conv-1", auth: auth)

            #expect(vm.lastUpdated == t0)
        }

        /// A failed refresh must not move the timestamp: the data on screen is
        /// still the old data, and saying otherwise is the lie the whole change
        /// exists to prevent.
        @Test func aFailedRefreshDoesNotAgeTheDataForward() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([
                .success(.stub()),
                .failure(APIError.transport(URLError(.timedOut))),
            ])
            let auth = try await session(api)
            let despues = t0.addingTimeInterval(600)
            let reloj = TestClock(t0)
            let vm = StandingViewModel(api: api, now: reloj.now)

            await vm.load(convocatoriaId: "conv-1", auth: auth)
            reloj.advance(to: despues)
            await vm.load(convocatoriaId: "conv-1", auth: auth)

            #expect(vm.lastUpdated == t0, "la hora es la del dato, no la del intento de refrescarlo")
        }

        // MARK: - Una cancelación no es un fallo

        /// **Cambiar de convocatoria a media carga no pinta un error de red.**
        ///
        /// Cancela la petición anterior, y envuelta como `.transport` la
        /// pantalla decía «No se ha podido conectar. Compruebe su conexión a la
        /// red» con la red perfecta: culpando al aspirante de algo que hizo la
        /// app.
        @Test func aCancelledLoadDoesNotShowANetworkError() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(CancellationError())])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)

            if case .error = vm.state {
                Issue.record("una cancelación se ha presentado como fallo de red")
            }
        }

        /// La otra forma en que llega: `URLSession` cancelada con la petición en
        /// vuelo. Tratar solo una de las dos deja el defecto a medias.
        @Test func aCancelledURLRequestDoesNotShowANetworkError() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(URLError(.cancelled))])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)

            if case .error = vm.state {
                Issue.record("una petición cancelada se ha presentado como fallo de red")
            }
        }

        /// El control: un fallo de red DE VERDAD sí se cuenta. Sin él, los dos
        /// tests de arriba pasarían para un view model que se traga todos los
        /// errores y deja la pantalla girando para siempre.
        @Test func arealNetworkFailureIsStillReported() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(URLError(.notConnectedToInternet))])
            let auth = try await session(api)
            let vm = viewModel(api)

            await vm.load(convocatoriaId: "conv-1", auth: auth)

            guard case .error = vm.state else {
                Issue.record("un fallo de red real tiene que verse: \(vm.state)")
                return
            }
        }
    }
}
