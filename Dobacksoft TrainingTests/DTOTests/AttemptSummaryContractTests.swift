import Testing
import Foundation

@testable import Dobacksoft_Training

/// The five fields the shared attempt list gained on 2026-09-07, read from
/// `mobile_api/services.py:186-215` and `schemas.py` — not from prose.
///
/// `/me/progress` and `/me/convocatorias/<id>/attempts` share one query, one
/// filter, one order and one constructor, so these fields arrive on BOTH. The
/// existing endpoint also started returning `PROCESSING` attempts, which is why
/// `state` exists: an attempt with no grade may be waiting for the truck's data
/// (it will come) or have fallen outside the validity minimums (it never will),
/// and saying the same thing for both leaves the candidate waiting for
/// something that is not going to happen.
struct AttemptSummaryContractTests {
    private func decode(_ json: String) throws -> AttemptSummaryDTO {
        try JSONDecoder().decode(AttemptSummaryDTO.self, from: Data(json.utf8))
    }

    /// The whole item as the backend builds it.
    private let completo = #"""
    {
      "id": "a-1",
      "route": {"id": "2A1", "label": "2A1", "name": "Parque → Hoyo", "categoria": "EXAMEN", "active": true},
      "score": 8.5,
      "dataQuality": "HIGH",
      "createdAt": "2026-09-07T08:00:00Z",
      "state": "CON_NOTA",
      "isCurrentBest": true,
      "endedAt": "2026-09-07T08:45:00Z",
      "distanceKm": 12.4,
      "durationMin": 45
    }
    """#

    @Test func theWholeItemDecodes() throws {
        let a = try decode(completo)

        #expect(a.id == "a-1")
        #expect(a.score == 8.5)
        #expect(a.state == .conNota)
        #expect(a.isCurrentBest == true)
        #expect(a.endedAt == "2026-09-07T08:45:00Z")
        #expect(a.distanceKm == 12.4)
        #expect(a.durationMin == 45)
    }

    /// Everything added is optional on the client side even where the backend
    /// promises it: the deployed app must survive an older server, and a
    /// non-optional field would fail the WHOLE list, not the field.
    @Test func theOldShapeStillDecodes() throws {
        let viejo = #"{"id": "a-1", "route": {"id": "2A1"}, "score": 7.0, "dataQuality": "HIGH", "createdAt": "2026-09-07T08:00:00Z"}"#

        let a = try decode(viejo)

        #expect(a.id == "a-1")
        #expect(a.state == nil)
        #expect(a.isCurrentBest == nil)
        #expect(a.distanceKm == nil)
    }

    // MARK: - state

    /// The closed set from `_estado_intento`. The backend states it is never
    /// null; the client still models it as optional, because «this server does
    /// not send it» and «this attempt has no state» are different facts and only
    /// the first one is real.
    @Test func theThreeStatesAreUnderstood() throws {
        #expect(try decode(item(state: "CON_NOTA")).state == .conNota)
        #expect(try decode(item(state: "ESPERANDO")).state == .esperando)
        #expect(try decode(item(state: "NO_EVALUABLE")).state == .noEvaluable)
    }

    /// The distinction the whole field exists for: one grade is coming, the
    /// other never will, and telling the candidate the same thing for both
    /// leaves them waiting for nothing.
    @Test func waitingAndUnevaluableDoNotSayTheSameThing() throws {
        let esperando = try #require(try decode(item(state: "ESPERANDO")).state)
        let noEvaluable = try #require(try decode(item(state: "NO_EVALUABLE")).state)

        #expect(esperando.detail != noEvaluable.detail)
        #expect(esperando.gradeMayStillArrive)
        #expect(noEvaluable.gradeMayStillArrive == false)
    }

    @Test func anUnknownStateIsNotInvented() throws {
        #expect(try decode(item(state: "UN_ESTADO_DE_MAÑANA")).state == nil)
    }

    // MARK: - route.active, que es tri-estado

    /// `null` is not `false`. Without a `Route` row the backend does not know
    /// whether the route was withdrawn or never existed — «false afirmaría que
    /// se retiró y true que sigue ofreciéndose, y lo que pasa es que no se
    /// sabe». So the client does not offer the link and does not claim either.
    @Test func aRouteWithoutARowClaimsNothing() throws {
        let a = try decode(#"{"id": "a-1", "route": {"id": "—", "label": "—", "active": null}}"#)

        #expect(a.route?.active == nil)
        #expect(a.route?.offersDetail == false, "sin saberlo no se ofrece el enlace")
    }

    @Test func aWithdrawnRouteDoesNotOfferItsSheet() throws {
        let a = try decode(#"{"id": "a-1", "route": {"id": "2A1", "active": false}}"#)

        #expect(a.route?.active == false)
        #expect(a.route?.offersDetail == false)
    }

    @Test func aLiveRouteOffersItsSheet() throws {
        let a = try decode(#"{"id": "a-1", "route": {"id": "2A1", "active": true}}"#)

        #expect(a.route?.offersDetail == true)
    }

    /// The sentinel still ships in this endpoint too — `route.id` is
    /// `attempt.routeId or "—"` in the very code that added these fields — so
    /// the tolerance shipped earlier is what keeps a route-less attempt from
    /// becoming a phantom route when the progress screen groups by code.
    @Test func aRoutelessAttemptStillCarriesNoCode() throws {
        let a = try decode(#"{"id": "a-1", "route": {"id": "—", "label": "—", "name": null, "active": null}}"#)

        #expect(a.route?.id == nil)
        #expect(a.route?.displayName == nil)
    }

    // MARK: - isCurrentBest

    /// `false` when the attempt has no enrolment — created by hand, without a
    /// tablet. Marking the only one there as «the best» would be inventing it.
    @Test func notTheCurrentBestIsAStatement() throws {
        #expect(try decode(item(isCurrentBest: "false")).isCurrentBest == false)
        #expect(try decode(item()).isCurrentBest == nil, "ausente no es lo mismo que false")
    }

    // MARK: - Helper

    private func item(state: String? = nil, isCurrentBest: String? = nil) -> String {
        var campos = [#""id": "a-1""#, #""route": {"id": "2A1"}"#]
        if let state { campos.append(#""state": "\#(state)""#) }
        if let isCurrentBest { campos.append(#""isCurrentBest": \#(isCurrentBest)"#) }
        return "{\(campos.joined(separator: ", "))}"
    }
}
