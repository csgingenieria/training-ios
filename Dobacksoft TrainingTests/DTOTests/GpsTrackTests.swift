import Testing
import Foundation

@testable import Dobacksoft_Training

/// `GET /api/v1/attempts/<id>/gps` — the trace of the lap, block B.
///
/// Three things in this contract are places where a plausible client draws a
/// lie on a map, and all three are what these cases are for:
///
/// - `track` is a DICTIONARY with `segments`, not a list of points. More than
///   one segment means the GPS jumped somewhere impossible and the line was
///   cut on purpose. Joining them would draw the truck crossing terrain it
///   never crossed.
/// - Events carry no `affectsScore`, deliberately: the correct source is
///   `descuenta` and this builder does not have it. Deriving it here would make
///   the same event contradict itself between the map and the sheet.
/// - `matched` and `confidence` say WHAT is being looked at — a trace snapped
///   to the road, or raw points. A map that does not label it invites reading
///   an approximation as a measurement.
struct GpsTrackTests {
    private func decode(_ json: String) throws -> GpsPayloadDTO {
        try JSONDecoder().decode(GpsPayloadDTO.self, from: Data(json.utf8))
    }

    // MARK: - track: los segmentos son cortes, no ruido

    /// Two segments are two segments. The cut is the datum.
    @Test func severalSegmentsStayApart() throws {
        let p = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7], [40.2, -3.8]], [[41.0, -4.0], [41.1, -4.1]]],
                   "matched": true, "confidence": 0.9, "source": "osrm"},
         "points": [], "route": [], "events": []}
        """#)

        #expect(p.track?.segments.count == 2)
        #expect(p.track?.segments.first?.count == 2)
        #expect(p.track?.hasGaps == true, "más de un segmento es un salto cortado a propósito")
    }

    @Test func aSingleSegmentHasNoGaps() throws {
        let p = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7], [40.2, -3.8]]], "matched": true},
         "points": [], "route": [], "events": []}
        """#)

        #expect(p.track?.hasGaps == false)
    }

    /// A malformed coordinate does not bring the whole trace down: a pair that
    /// is not a pair is dropped, and the rest of the lap still draws.
    @Test func aMalformedCoordinateDoesNotSinkTheTrace() throws {
        let p = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7], [40.2], [40.3, -3.9]]], "matched": false},
         "points": [], "route": [], "events": []}
        """#)

        #expect(p.track?.segments.first?.count == 2, "se cae el par roto, no la traza")
    }

    // MARK: - Qué se está mirando

    /// `points` is the fallback, and only when there is nothing snapped. The
    /// order matters: drawing raw points over a matched trace would show a
    /// worse line than the one available.
    @Test func theSnappedTraceWinsAndPointsAreTheFallback() throws {
        let conTraza = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7], [40.2, -3.8]]], "matched": true},
         "points": [{"lat": 1.0, "lng": 2.0}], "route": [], "events": []}
        """#)
        let sinTraza = try decode(#"""
        {"track": {"segments": [], "matched": false},
         "points": [{"lat": 1.0, "lng": 2.0}, {"lat": 1.1, "lng": 2.1}], "route": [], "events": []}
        """#)

        #expect(conTraza.drawableSegments.count == 1)
        #expect(conTraza.drawableSegments.first?.count == 2)
        #expect(sinTraza.drawableSegments.count == 1, "el respaldo se dibuja como un solo tramo")
        #expect(sinTraza.drawableSegments.first?.count == 2)
        #expect(sinTraza.isFallback, "y la pantalla tiene que poder decir que lo es")
        #expect(conTraza.isFallback == false)
    }

    /// Nothing to draw is nothing to draw: no empty map pretending to be a lap.
    @Test func withNeitherTraceNorPointsThereIsNothingToDraw() throws {
        let p = try decode(#"{"track": {"segments": []}, "points": [], "route": [], "events": []}"#)

        #expect(p.drawableSegments.isEmpty)
        #expect(p.hasSomethingToDraw == false)
    }

    /// The label the screen owes the candidate: a trace snapped to the road at
    /// 40 % confidence is not the same claim as one at 95 %.
    @Test func theTraceSaysHowMuchOfItCouldBePlaced() throws {
        let p = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7]]], "matched": true, "confidence": 0.42, "source": "osrm"},
         "points": [], "route": [], "events": []}
        """#)
        let track = try #require(p.track)

        #expect(track.matched == true)
        #expect(track.confidence == 0.42)
        #expect(track.isReliable == false, "menos de la mitad ubicada no se presenta como medida")
    }

    @Test func aWellPlacedTraceIsPresentedAsReliable() throws {
        let p = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7]]], "matched": true, "confidence": 0.95},
         "points": [], "route": [], "events": []}
        """#)

        #expect(try #require(p.track).isReliable)
    }

    /// Raw points are never «reliable» in this sense: nothing was snapped, so
    /// there is no confidence to report.
    @Test func rawPointsAreNotPresentedAsASnappedTrace() throws {
        let p = try decode(#"""
        {"track": {"segments": [[[40.1, -3.7]]], "matched": false, "confidence": 0.99},
         "points": [], "route": [], "events": []}
        """#)

        #expect(try #require(p.track).isReliable == false, "sin pegar a la calzada no hay medida que afirmar")
    }

    // MARK: - Eventos sobre el mapa

    @Test func anEventOnTheMapCarriesItsPlaceAndItsIdentity() throws {
        let p = try decode(#"""
        {"track": {"segments": []}, "points": [], "route": [],
         "events": [{"id": "e-1", "type": "EVT_01", "lat": 40.1, "lng": -3.7,
                     "severity": 0.9, "penaltyPoints": 1.0, "narrative": "Frenada brusca.",
                     "advice": "Anticipe la frenada.", "speedKmh": 62.0, "limitKmh": 50.0,
                     "excessKmh": 12.0}]}
        """#)
        let evento = try #require(p.events.first)

        #expect(evento.id == "e-1", "sin id no hay cruce con la ficha")
        #expect(evento.coordinate != nil)
        #expect(evento.narrative == "Frenada brusca.")
        #expect(evento.excessKmh == 12.0)
    }

    /// An event with no coordinates cannot be pinned, and inventing a place for
    /// it would put an incident where it did not happen.
    @Test func anEventWithoutCoordinatesIsNotPinned() throws {
        let p = try decode(#"""
        {"track": {"segments": []}, "points": [], "route": [],
         "events": [{"id": "e-1", "type": "EVT_01", "lat": null, "lng": null}]}
        """#)

        #expect(p.events.first?.coordinate == nil)
        #expect(p.pinnableEvents.isEmpty, "no se clava en el mapa lo que no tiene sitio")
    }

    /// The deliberate absence: this endpoint does not say whether an event
    /// deducted, because it does not have the right source. The client crosses
    /// it by `id` with the sheet instead of guessing here.
    @Test func theMapNeverClaimsWhetherAnEventDeducted() throws {
        let json = #"""
        {"track": {"segments": []}, "points": [], "route": [],
         "events": [{"id": "e-1", "type": "EVT_01", "aplica_a_nota": true, "affectsScore": true}]}
        """#

        let p = try decode(json)

        // El DTO del mapa no tiene ese campo, y es a propósito: derivarlo aquí
        // haría que el mismo evento se contradijera entre el mapa y la ficha.
        #expect(p.events.first?.id == "e-1")
        #expect(p.crossReferenceIds == ["e-1"], "lo que el mapa aporta es la identidad para cruzar")
    }
}
