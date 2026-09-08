import Testing
import Foundation

@testable import Dobacksoft_Training

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// El puesto del aspirante cuando arranca sin cobertura.
///
/// La otra mitad del punto #27. `LastGoodStore` existía y nadie escribía en él.
///
/// La duda que dejé anotada —«qué hace una fila cacheada al tocarla»— era de la
/// LISTA de convocatorias, no de aquí: la tarjeta del puesto es un dato, no una
/// lista de enlaces. Sobre-escopé la duda y con ella me bloqueé la mitad
/// entregable.
extension KeychainBacked {
    @MainActor
    struct StandingCacheWiringTests {
        init() { try? TokenStore.clearAll() }

        private func temporaryStore() -> LastGoodStore {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("wiring-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return LastGoodStore(directory: url)
        }

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "a@b.example", password: "x")
            return session
        }

        private func standing(position: Int = 12, score: Double = 8.5) -> StandingDTO {
            StandingDTO(
                convocatoriaId: "c1", position: position, totalCandidates: 256,
                score: score, attemptsCompleted: 3, attemptsTotal: 4,
                status: "ACTIVE", requiredRoutes: nil,
                completedRequired: nil, pendingRequired: nil, scoreOfCompleted: nil
            )
        }

        // MARK: - Se escribe al cargar bien

        @Test func aSuccessfulLoadWritesTheCache() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.success(standing())])
            let auth = try await session(api)
            let store = temporaryStore()
            let vm = StandingViewModel(api: api, now: { t0 }, lastGood: store)

            await vm.load(convocatoriaId: "c1", auth: auth, convocatoriaName: "Oposición 2026")

            let userId = try #require(auth.user?.id)
            guard case let .presente(cache, capturedAt) = store.read(
                StandingCache.self, key: .standing, userId: userId, now: t0
            ) else {
                Issue.record("una carga correcta no escribió la caché")
                return
            }
            #expect(cache.position == 12)
            #expect(cache.score == 8.5)
            #expect(cache.convocatoriaName == "Oposición 2026")
            #expect(capturedAt == t0)
        }

        // MARK: - Se lee en un arranque en frío sin red

        /// **Lo que este punto viene a arreglar.** Sin datos en pantalla y sin
        /// red, se enseña lo último que se leyó, con su fecha.
        @Test func aColdStartWithoutNetworkShowsTheCache() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(APIError.transport(URLError(.notConnectedToInternet)))])
            let auth = try await session(api)
            let store = temporaryStore()
            let userId = try #require(auth.user?.id)

            #expect(store.write(
                StandingCache(
                    convocatoriaName: "Oposición 2026", position: 7,
                    totalParticipants: 256, score: 9.1, finality: .provisional
                ),
                key: .standing, userId: userId, at: t0
            ))

            let vm = StandingViewModel(api: api, now: { t0 }, lastGood: store)
            await vm.load(convocatoriaId: "c1", auth: auth)

            guard case let .cached(cache, capturedAt) = vm.state else {
                Issue.record("se esperaba .cached, y llegó \(vm.state)")
                return
            }
            #expect(cache.position == 7)
            #expect(capturedAt == t0)
        }

        /// El control: sin caché, un arranque sin red sigue siendo un error. Sin
        /// esto, el test de arriba pasaría para un view model que enseñe una
        /// caché vacía en lugar de decir que no pudo.
        @Test func aColdStartWithoutNetworkAndWithoutCacheIsAnError() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(APIError.transport(URLError(.timedOut)))])
            let auth = try await session(api)
            let vm = StandingViewModel(api: api, now: { t0 }, lastGood: temporaryStore())

            await vm.load(convocatoriaId: "c1", auth: auth)

            if case .error = vm.state {} else {
                Issue.record("se esperaba .error, y llegó \(vm.state)")
            }
        }

        /// **Una respuesta no es una ausencia.** «No está inscrito» llega como
        /// 404 y es un hecho del backend: enseñar una caché encima diría que
        /// sigue inscrito cuando ya no lo está.
        @Test func anAnswerFromTheBackendIsNeverReplacedByTheCache() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(APIError.notFound(.notEnrolled))])
            let auth = try await session(api)
            let store = temporaryStore()
            let userId = try #require(auth.user?.id)
            #expect(store.write(
                StandingCache(
                    convocatoriaName: "Vieja", position: 7,
                    totalParticipants: 256, score: 9.1, finality: .provisional
                ),
                key: .standing, userId: userId, at: t0
            ))

            let vm = StandingViewModel(api: api, now: { t0 }, lastGood: store)
            await vm.load(convocatoriaId: "c1", auth: auth)

            guard case .notFound = vm.state else {
                Issue.record("una respuesta del backend se tapó con la caché: \(vm.state)")
                return
            }
        }

        /// Una caché demasiado vieja no se enseña como si fuera de ahora: se
        /// cae al error, con el mismo umbral que el widget.
        @Test func aCacheTooOldIsNotShown() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([.failure(APIError.transport(URLError(.notConnectedToInternet)))])
            let auth = try await session(api)
            let store = temporaryStore()
            let userId = try #require(auth.user?.id)
            #expect(store.write(
                StandingCache(
                    convocatoriaName: "Antigua", position: 7,
                    totalParticipants: 256, score: 9.1, finality: .provisional
                ),
                key: .standing, userId: userId, at: t0
            ))

            let muyDespues = t0.addingTimeInterval(SnapshotFreshness.expiryThreshold + 1)
            let vm = StandingViewModel(api: api, now: { muyDespues }, lastGood: store)
            await vm.load(convocatoriaId: "c1", auth: auth)

            if case .cached = vm.state {
                Issue.record("se enseñó una caché caducada como dato vigente")
            }
        }

        /// **El estado cacheado no publica al widget.**
        ///
        /// La decisión que más importa de todo este punto. El widget ya tiene su
        /// propia última instantánea con SU fecha, y republicar desde nuestra
        /// caché reescribiría ese `capturedAt` a ahora: una cifra de anteayer
        /// pasaría a verse recién consultada en la pantalla de inicio, donde la
        /// ve cualquiera que pase. Es la mentira exacta que el diseño del widget
        /// existe para evitar.
        @Test func theCachedStateNeverPublishesToTheWidget() {
            let cache = StandingCache(
                convocatoriaName: "Oposición 2026", position: 7,
                totalParticipants: 256, score: 9.1, finality: .provisional
            )
            let publicado = SnapshotPublisher.content(
                for: .cached(cache, capturedAt: t0),
                convocatoriaName: "Oposición 2026",
                finality: .provisional
            )
            #expect(publicado == nil)
        }

        /// El control: un estado cargado SÍ publica. Sin él, el test de arriba
        /// pasaría para un publicador que no publica nunca.
        @Test func aLoadedStateStillPublishes() {
            let publicado = SnapshotPublisher.content(
                for: .loaded(standing()),
                convocatoriaName: "Oposición 2026",
                finality: .provisional
            )
            #expect(publicado != nil)
        }

        /// Y con datos ya en pantalla no se toca la caché: eso ya lo cubre
        /// `refreshError`, que conserva lo que se está leyendo.
        @Test func withDataOnScreenTheCacheIsNotUsed() async throws {
            let api = FakeTrainingAPI()
            await api.setStandingResults([
                .success(standing()),
                .failure(APIError.transport(URLError(.notConnectedToInternet)))
            ])
            let auth = try await session(api)
            let vm = StandingViewModel(api: api, now: { t0 }, lastGood: temporaryStore())

            await vm.load(convocatoriaId: "c1", auth: auth)
            await vm.load(convocatoriaId: "c1", auth: auth)

            guard case .loaded = vm.state else {
                Issue.record("el refresco fallido se llevó los datos: \(vm.state)")
                return
            }
            #expect(vm.refreshError != nil)
        }
    }
}
