import Testing
import Foundation

@testable import Dobacksoft_Training

/// The frozen REAL response of `GET /api/v1/me/progress`, copied from
/// `docs/api-fixtures/me_progress.json` on the backend's `main`.
///
/// Written because the DTOs were built from the schema, and a schema is what the
/// server promises while a fixture is what it sent. That difference already cost
/// four renames today: every one of them came from reading prose instead of
/// data.
///
/// It paid for itself immediately — the fixture carries a field no schema
/// comment had mentioned to us, `convocatoria.finalScorePublished`, which the
/// client had been silently dropping.
struct ProgressRealFixtureTests {
    private func real() throws -> ProgressDTO {
        try JSONFixture.decode("me-progress-real")
    }

    @Test func theRealResponseDecodes() throws {
        let p = try real()

        #expect(p.presented != nil, "`presented` es obligatorio en el contrato")
        #expect(p.attempts.isEmpty == false)
        #expect(p.activeEnrollments.isEmpty == false)
    }

    /// The three states all appear in the same real response, which is what
    /// makes it worth freezing: an attempt with no grade because it is waiting
    /// and one with no grade because it never will be are both here, and the
    /// screen has to tell them apart.
    @Test func theRealResponseCarriesAttemptsInDifferentStates() throws {
        let estados = Set(try real().attempts.compactMap(\.state))

        #expect(estados.contains(.esperando))
        #expect(estados.contains(.noEvaluable))
    }

    /// `distanceKm` and `durationMin` arrive `null` in the real answer even on
    /// graded attempts: they belong to the ROUTE and this catalogue does not
    /// declare them. A zero would say the route measures zero.
    @Test func routeMetadataIsAllowedToBeAbsentInReality() throws {
        let p = try real()

        #expect(p.attempts.contains { $0.distanceKm == nil })
    }

    /// The sentinel work holds against real data: every route in the fixture
    /// carries a code, so nothing collapses into a phantom route.
    @Test func everyRealRouteCarriesItsCode() throws {
        for intento in try real().attempts {
            #expect(intento.route?.id != nil, "un intento sin código agruparía como recorrido fantasma")
        }
    }

    // MARK: - El campo que el cruce encontró

    /// `finalScorePublished` was in the real response and in none of the notes
    /// we were given. It is now decoded rather than dropped.
    @Test func theFinalScoreFlagIsNoLongerDropped() throws {
        let convocatoria = try #require(try real().convocatoria)

        #expect(convocatoria.finalScorePublished != nil)
    }

    /// **And it must NOT drive what the screen says.** This is the important
    /// case, and it exists so nobody «simplifies» `GradeFinality` into this
    /// field later.
    ///
    /// The backend computes it as `status in {CLOSED, LOCKED}`. The client
    /// deliberately splits those two, and its reason is written in
    /// `GradeFinality`: `LOCKED` is the only state where the grade is truly
    /// immovable, because on `CLOSED` an administrator still has 24 hours to
    /// reverse the close. Calling a grade that can still move «definitiva» is
    /// asserting too much about a person in a public examination.
    ///
    /// So this flag is strictly LESS precise than what the client already
    /// derives, and wiring it into the label would be a downgrade dressed as a
    /// simplification.
    @Test func theFinalScoreFlagIsLessPreciseThanWhatTheClientDerives() {
        // Los dos estados que el backend colapsa en `true`.
        let cerrada = GradeFinality(convocatoriaStatus: "CLOSED")
        let bloqueada = GradeFinality(convocatoriaStatus: "LOCKED")

        #expect(cerrada != bloqueada, "el cliente los distingue y el flag no")
        #expect(bloqueada == .definitive)
        #expect(cerrada == .pendingConfirmation)
        #expect(cerrada.note?.contains("24 horas") == true,
                "la ventana de revocación es la razón de la distinción")
    }

    /// What the flag IS good for: `false` is a hard statement that nothing has
    /// been published, and it agrees with the client's own reading.
    @Test func aFalseFlagAgreesWithTheClientCallingItProvisional() throws {
        let convocatoria = try #require(try real().convocatoria)

        if convocatoria.finalScorePublished == false {
            #expect(convocatoria.closedAt == nil, "sin acta emitida no hay cierre")
        }
    }
}
