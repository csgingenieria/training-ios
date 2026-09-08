import Testing
import Foundation

@testable import Dobacksoft_Training

/// Fixed instants: `Date()` in a test makes the outcome depend on when it runs.
private let t0 = Date(timeIntervalSince1970: 1_757_000_000) // 2025-09-04 aprox.

private func snapshot(
    capturedAt: Date = t0,
    generation: Int = 1,
    content: StandingSnapshot.Content = .posicion(
        .init(
            convocatoriaName: "Oposición de prueba",
            position: 3,
            totalCandidates: 42,
            score: 7.5,
            attemptsTotal: 5,
            finality: .provisional
        )
    )
) -> StandingSnapshot {
    StandingSnapshot(generation: generation, capturedAt: capturedAt, content: content)
}

struct StandingSnapshotTests {
    @Test func everyContentCaseSurvivesARoundTrip() throws {
        let cases: [StandingSnapshot.Content] = [
            .desactivado,
            .sinPosicionPropia,
            .sinDatosAun,
            .sinConvocatoria,
            .sinPosicion(convocatoriaName: "Oposición de prueba"),
            .posicion(.init(
                convocatoriaName: "Oposición de prueba",
                position: 3,
                totalCandidates: 42,
                score: 7.5,
                attemptsTotal: 5,
                finality: .definitiva
            )),
        ]

        for content in cases {
            let original = snapshot(content: content)
            let data = try StandingSnapshot.encoder.encode(original)
            let restored = try StandingSnapshot.decoder.decode(StandingSnapshot.self, from: data)
            #expect(restored == original)
        }
    }

    /// Writer and reader must agree on date format. A mismatched strategy would
    /// break reads silently, which is why both live on the type.
    @Test func datesRoundTripThroughTheSharedCoders() throws {
        let original = snapshot(capturedAt: t0)
        let data = try StandingSnapshot.encoder.encode(original)
        let restored = try StandingSnapshot.decoder.decode(StandingSnapshot.self, from: data)
        #expect(restored.capturedAt.timeIntervalSince1970 == t0.timeIntervalSince1970)
    }

    /// A snapshot without `capturedAt` cannot be trusted at all: there is no way
    /// to tell whether what it says is still true.
    @Test func missingCapturedAtFailsToDecode() {
        let json = Data(#"{"schemaVersion":1,"generation":1,"content":{"desactivado":{}}}"#.utf8)
        #expect(throws: (any Error).self) {
            try StandingSnapshot.decoder.decode(StandingSnapshot.self, from: json)
        }
    }

    /// The score can be absent, and absence must not become a zero.
    @Test func absentScoreStaysAbsent() throws {
        let original = snapshot(content: .posicion(.init(
            convocatoriaName: "C",
            position: 1,
            totalCandidates: 10,
            score: nil,
            attemptsTotal: 2,
            finality: .desconocida
        )))

        let data = try StandingSnapshot.encoder.encode(original)
        let restored = try StandingSnapshot.decoder.decode(StandingSnapshot.self, from: data)

        guard case let .posicion(standing) = restored.content else {
            Issue.record("se esperaba .posicion")
            return
        }
        #expect(standing.score == nil)
    }
}

struct SnapshotFreshnessTests {
    @Test func recentDataIsFresh() {
        #expect(SnapshotFreshness.evaluate(capturedAt: t0, at: t0) == .fresco)
        #expect(SnapshotFreshness.evaluate(capturedAt: t0, at: t0.addingTimeInterval(3600)) == .fresco)
    }

    /// Exact boundaries, because off-by-one here means showing a stale figure
    /// as current.
    @Test func theSixHourBoundaryStartsAging() {
        let justBefore = t0.addingTimeInterval(SnapshotFreshness.agingThreshold - 1)
        let exactly = t0.addingTimeInterval(SnapshotFreshness.agingThreshold)
        #expect(SnapshotFreshness.evaluate(capturedAt: t0, at: justBefore) == .fresco)
        #expect(SnapshotFreshness.evaluate(capturedAt: t0, at: exactly) == .envejecido)
    }

    @Test func theFortyEightHourBoundaryExpires() {
        let justBefore = t0.addingTimeInterval(SnapshotFreshness.expiryThreshold - 1)
        let exactly = t0.addingTimeInterval(SnapshotFreshness.expiryThreshold)
        #expect(SnapshotFreshness.evaluate(capturedAt: t0, at: justBefore) == .envejecido)
        #expect(SnapshotFreshness.evaluate(capturedAt: t0, at: exactly) == .caducado)
    }

    /// Freshness is anchored to capture, not to when it was read: data captured
    /// 20 h ago and read 30 h later is expired, not merely aging.
    @Test func agingIsAnchoredToCaptureNotToReading() {
        let captured = t0
        let readAt = t0.addingTimeInterval(50 * 3600)
        #expect(SnapshotFreshness.evaluate(capturedAt: captured, at: readAt) == .caducado)
    }

    @Test func freshDataHasBothCrossingsAhead() {
        let crossings = SnapshotFreshness.futureThresholdCrossings(capturedAt: t0, after: t0)
        #expect(crossings.count == 2)
        #expect(crossings[0] < crossings[1])
    }

    @Test func agingDataHasOnlyTheExpiryAhead() {
        let now = t0.addingTimeInterval(10 * 3600)
        let crossings = SnapshotFreshness.futureThresholdCrossings(capturedAt: t0, after: now)
        #expect(crossings == [t0.addingTimeInterval(SnapshotFreshness.expiryThreshold)])
    }

    /// No crossings left. The timeline provider must still emit one entry — an
    /// empty timeline would freeze the widget on whatever it last showed.
    @Test func expiredDataHasNoCrossingsAhead() {
        let now = t0.addingTimeInterval(100 * 3600)
        #expect(SnapshotFreshness.futureThresholdCrossings(capturedAt: t0, after: now).isEmpty)
    }
}

struct SnapshotStoreTests {
    private func temporaryStore() throws -> (SnapshotStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snapshot-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (SnapshotStore(directory: dir), dir)
    }

    @Test func writtenSnapshotComesBack() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(store.write(snapshot()) == true)

        guard case let .presente(restored) = store.read() else {
            Issue.record("se esperaba .presente")
            return
        }
        #expect(restored.generation == 1)
    }

    /// Nothing stored means no session. This is the only case allowed to say so.
    @Test func emptyContainerReadsAsAbsent() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(store.read() == .ausente)
    }

    /// No container is NOT the same as no session: the App Group may be
    /// unregistered or the entitlement missing.
    @Test func missingContainerIsUnreadableNotAbsent() {
        let store = SnapshotStore(directory: nil)
        #expect(store.read() == .ilegible(.sinContenedor))
    }

    /// Corruption must never be reported as "you are not signed in".
    @Test func corruptFileIsUnreadableNotAbsent() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("no soy json".utf8).write(to: dir.appendingPathComponent("standing-snapshot.json"))

        #expect(store.read() == .ilegible(.corrupto))
    }

    /// Written by a newer build: guessing the format would be inventing.
    @Test func futureSchemaVersionIsUnreadable() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let json = """
        {"schemaVersion":99,"generation":1,"capturedAt":"2025-09-04T00:00:00Z","content":{"desactivado":{}}}
        """
        try Data(json.utf8).write(to: dir.appendingPathComponent("standing-snapshot.json"))

        #expect(store.read() == .ilegible(.versionDesconocida))
    }

    @Test func clearRemovesTheSnapshot() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(snapshot())
        #expect(store.clear() == true)
        #expect(store.read() == .ausente)
    }

    /// Signing out with nothing stored is a no-op, not a failure.
    @Test func clearingNothingSucceeds() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(store.clear() == true)
    }

    @Test func writingTwiceKeepsTheLatest() throws {
        let (store, dir) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        store.write(snapshot(generation: 1))
        store.write(snapshot(generation: 2, content: .sinConvocatoria))

        guard case let .presente(restored) = store.read() else {
            Issue.record("se esperaba .presente")
            return
        }
        #expect(restored.generation == 2)
        #expect(restored.content == .sinConvocatoria)
    }

    /// A reader with no container must degrade, never crash.
    @Test func writingWithoutContainerFailsQuietly() {
        let store = SnapshotStore(directory: nil)
        #expect(store.write(snapshot()) == false)
        #expect(store.clear() == false)
    }

    // MARK: - Los textos que mandan a alguien a algún sitio

    /// The expiry message names the SCREEN, not «the app».
    ///
    /// Only «Mi posición» republishes the snapshot, so opening the app and
    /// staying on Convocatorias leaves the widget exactly as expired — and the
    /// candidate concluding it does not work. `sinDatosAun` already got this
    /// right; `caducado` said «Abra la aplicación».
    @Test func theExpiryMessageNamesTheScreenThatFixesIt() {
        #expect(SnapshotCopy.caducado.contains("«Mi posición»"))
        #expect(SnapshotCopy.sinDatosAun.contains("«Mi posición»"))
    }

    /// Every message that asks the person to do something says WHERE.
    ///
    /// The control half matters: `sinPosicionDetalle` explains and asks for
    /// nothing, so it needs no destination. Without that split this test would
    /// pass by demanding a screen name from sentences that have no action.
    @Test func aMessageThatAsksForSomethingSaysWhere() {
        for message in [SnapshotCopy.caducado, SnapshotCopy.sinDatosAun, SnapshotCopy.desactivado] {
            #expect(message.contains("aplicación") || message.contains("perfil"),
                    "pide algo y no dice dónde: \(message)")
        }
        #expect(!SnapshotCopy.sinPosicionDetalle.contains("Abra"),
                "explica, no pide: no debe mandar a ninguna pantalla")
    }
}
