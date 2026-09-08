import Testing
import Foundation

@testable import Dobacksoft_Training

private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

/// The last good data, kept so an offline cold start has something to read.
///
/// Every screen was network-or-nothing: a candidate in a garage with no signal
/// opened the app and had nothing at all. Item #3 fixed the in-session case —
/// a failed refresh keeps what is on screen — but a cold start had nothing to
/// keep.
///
/// This writes a candidate's own position and mark to disk, so the design
/// follows the widget's doctrine rather than inventing one:
///
/// - «there is none» and «I could not read it» are different answers, and
///   collapsing them states something false about someone's account;
/// - it is namespaced per user, because a device is shared;
/// - it is cleared on logout;
/// - it never hands back figures older than the widget's own expiry threshold.
struct LastGoodStoreTests {
    private func store(_ directory: URL? = nil) -> LastGoodStore {
        LastGoodStore(directory: directory ?? temporaryDirectory())
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lastgood-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Una PROYECCIÓN, no el DTO. Los DTO son `Decodable` a propósito y
    /// guardarlos pediría hacerlos `Encodable` en toda la app; además guardarían
    /// más de lo necesario. Ver `StandingCache`.
    private func cache(_ nombre: String = "Oposición 2026", position: Int? = 12) -> StandingCache {
        StandingCache(
            convocatoriaName: nombre,
            position: position,
            totalParticipants: 256,
            score: 8.5,
            finality: .provisional
        )
    }

    // MARK: - Ida y vuelta

    @Test func whatIsWrittenComesBackWithItsAge() throws {
        let store = store()
        #expect(store.write(cache(), key: .convocatorias, userId: "u1", at: t0))

        let leido = store.read(StandingCache.self, key: .convocatorias, userId: "u1", now: t0)
        guard case let .presente(datos, capturedAt) = leido else {
            Issue.record("se esperaba .presente, y llegó \(leido)")
            return
        }
        #expect(datos == cache())
        #expect(capturedAt == t0)
    }

    /// Nothing written is «there is none» — not a failure. It is the state of
    /// every first launch.
    @Test func nothingWrittenIsAbsentAndNotAFailure() {
        #expect(store().read(StandingCache.self, key: .convocatorias, userId: "u1", now: t0) == .ausente)
    }

    /// A later write replaces the earlier one: this keeps the LAST good data,
    /// not a history.
    @Test func aLaterWriteReplacesTheEarlierOne() throws {
        let store = store()
        #expect(store.write(cache("Vieja"), key: .convocatorias, userId: "u1", at: t0))
        let despues = t0.addingTimeInterval(3600)
        #expect(store.write(cache("Nueva"), key: .convocatorias, userId: "u1", at: despues))

        guard case let .presente(datos, capturedAt) = store.read(
            StandingCache.self, key: .convocatorias, userId: "u1", now: despues
        ) else {
            Issue.record("se esperaba .presente")
            return
        }
        #expect(datos.convocatoriaName == "Nueva")
        #expect(capturedAt == despues)
    }

    // MARK: - Un dispositivo es compartido

    /// **The one that matters.** An instructor's iPad passes from hand to hand,
    /// and a candidate's position must never be readable from another
    /// candidate's session. Reading as user B must not find user A's data.
    @Test func oneUsersDataIsNeverReadableAsAnother() throws {
        let store = store()
        #expect(store.write(cache("De u1"), key: .convocatorias, userId: "u1", at: t0))

        let comoOtro = store.read(StandingCache.self, key: .convocatorias, userId: "u2", now: t0)
        #expect(comoOtro == .ausente, "los datos de u1 se han leído desde la sesión de u2")
    }

    /// And clearing one session leaves the other alone: a shared device where
    /// one person signing out wipes another's cache would be its own defect.
    @Test func clearingOneUserLeavesTheOtherAlone() throws {
        let store = store()
        #expect(store.write(cache("De u1"), key: .convocatorias, userId: "u1", at: t0))
        #expect(store.write(cache("De u2"), key: .convocatorias, userId: "u2", at: t0))

        store.clear(userId: "u1")

        #expect(store.read(StandingCache.self, key: .convocatorias, userId: "u1", now: t0) == .ausente)
        guard case .presente = store.read(
            StandingCache.self, key: .convocatorias, userId: "u2", now: t0
        ) else {
            Issue.record("borrar la sesión de u1 se llevó los datos de u2")
            return
        }
    }

    /// Different keys of the same user do not overwrite each other.
    @Test func differentKeysDoNotCollide() throws {
        let store = store()
        #expect(store.write(cache("Lista"), key: .convocatorias, userId: "u1", at: t0))
        #expect(store.write(cache("Otra"), key: .misConvocatorias, userId: "u1", at: t0))

        guard case let .presente(lista, _) = store.read(
            StandingCache.self, key: .convocatorias, userId: "u1", now: t0
        ) else {
            Issue.record("se esperaba .presente")
            return
        }
        #expect(lista.convocatoriaName == "Lista")
    }

    // MARK: - Vieja no es lo mismo que ausente

    /// Beyond the widget's own expiry threshold the figures are not handed
    /// back. The widget refuses to show a 48-hour-old position unlabelled; the
    /// app cannot be more permissive about the same number.
    ///
    /// And it comes back as `.caducada`, not `.ausente`: «no hay datos» and
    /// «los suyos son de anteanoche» are different things to tell someone.
    @Test func dataPastTheExpiryThresholdIsExpiredAndNotAbsent() throws {
        let store = store()
        #expect(store.write(cache(), key: .convocatorias, userId: "u1", at: t0))

        let mucho = t0.addingTimeInterval(SnapshotFreshness.expiryThreshold + 1)
        let leido = store.read(StandingCache.self, key: .convocatorias, userId: "u1", now: mucho)

        guard case let .caducada(capturedAt) = leido else {
            Issue.record("se esperaba .caducada, y llegó \(leido)")
            return
        }
        #expect(capturedAt == t0, "se dice CUÁNDO se leyó, aunque no se entreguen las cifras")
    }

    /// The control: just inside the threshold it is still handed back. Without
    /// this, the test above would pass for a store that never returns
    /// anything.
    @Test func dataJustInsideTheThresholdIsStillReturned() throws {
        let store = store()
        #expect(store.write(cache(), key: .convocatorias, userId: "u1", at: t0))

        let justo = t0.addingTimeInterval(SnapshotFreshness.expiryThreshold - 1)
        guard case .presente = store.read(
            StandingCache.self, key: .convocatorias, userId: "u1", now: justo
        ) else {
            Issue.record("dentro del umbral y no se devolvió")
            return
        }
    }

    // MARK: - «No hay» no es «no pude leer»

    /// The widget's doctrine, applied here: a corrupt file is not an absence.
    /// Collapsing them would tell someone their data is gone when what
    /// happened is that this device could not read it.
    @Test func aCorruptFileIsIllegibleAndNotAbsent() throws {
        let directory = temporaryDirectory()
        let store = store(directory)
        #expect(store.write(cache(), key: .convocatorias, userId: "u1", at: t0))

        let file = try #require(store.fileURL(key: .convocatorias, userId: "u1"))
        try Data("esto no es json".utf8).write(to: file)

        let leido = store.read(StandingCache.self, key: .convocatorias, userId: "u1", now: t0)
        #expect(leido == .ilegible, "un fichero corrupto se ha presentado como ausencia")
    }

    /// A store with nowhere to write degrades and says so — it never crashes
    /// and never breaks the load that was otherwise fine.
    @Test func aStoreWithNoDirectoryFailsQuietly() {
        let store = LastGoodStore(directory: nil)
        #expect(store.write(cache(), key: .convocatorias, userId: "u1", at: t0) == false)
        #expect(store.read(StandingCache.self, key: .convocatorias, userId: "u1", now: t0) == .ilegible)
    }

    /// An empty user id is not a user. Writing under it would put data in a
    /// shared bucket that any session could read.
    @Test func anEmptyUserIdIsRefused() {
        let store = store()
        #expect(store.write(cache(), key: .convocatorias, userId: "", at: t0) == false)
        #expect(store.write(cache(), key: .convocatorias, userId: "   ", at: t0) == false)
    }

    /// **Signing out takes the cache with it.**
    ///
    /// Wired now, before anything writes to the store. A cache that outlives
    /// its session is a silent defect: nobody sees it until another person on
    /// the same device reads it, and by then it has been there for weeks. If the
    /// hook is added after the writing, the window exists.
    ///
    /// Note the order this pins: the clear happens BEFORE `user` is set to nil,
    /// because the user's own id is the key it is stored under. The other way
    /// round there would be nobody to clear.
    @MainActor
    @Test func signingOutClearsTheCache() async throws {
        try? TokenStore.clearAll()
        let directory = temporaryDirectory()
        let store = store(directory)

        let api = FakeTrainingAPI()
        await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
        let session = AuthSession(api: api, lastGood: store)
        try await session.login(email: "a@b.example", password: "x")

        let userId = try #require(session.user?.id)
        #expect(store.write(cache(), key: .standing, userId: userId, at: t0))
        guard case .presente = store.read(StandingCache.self, key: .standing, userId: userId, now: t0) else {
            Issue.record("la caché no llegó a escribirse, así que este test no prueba el borrado")
            return
        }

        await session.logout(reason: .userInitiated)

        #expect(
            store.read(StandingCache.self, key: .standing, userId: userId, now: t0) == .ausente,
            "la caché sobrevivió al cierre de sesión"
        )
    }

    /// A user id that looks like a path cannot escape the directory. It comes
    /// from the backend, and a store that concatenates it into a filename
    /// would let a crafted id write outside its own folder.
    @Test func aUserIdCannotEscapeTheDirectory() throws {
        let store = store()
        #expect(store.write(cache(), key: .convocatorias, userId: "../../fuera", at: t0) == false)
        #expect(store.write(cache(), key: .convocatorias, userId: "a/b", at: t0) == false)
    }
}
