import Testing
import Foundation

@testable import Dobacksoft_Training

/// One malformed event must not take the whole map down.
///
/// **Found against staging, not by reading code.** The map showed «La respuesta
/// del servidor no tiene el formato esperado» for some attempts and not others,
/// and the log said why:
///
///     GpsPayloadDTO: events.Index 0.severity — no es Double
///
/// `severity` arrives as something other than a number on this endpoint. One
/// field, on one event, and the candidate lost the entire trace of their lap —
/// the route, the snapped path, every other event — over a value the map does
/// not draw anything with.
///
/// That is the rule this repository already wrote for `SyncResultDTO`: an
/// unexpected type must not sink the response. It was not applied here.
struct GpsEventToleranceTests {
    private func decode(_ json: String) throws -> GpsPayloadDTO {
        try JSONDecoder().decode(GpsPayloadDTO.self, from: Data(json.utf8))
    }

    // MARK: - La forma que rompía

    /// A textual severity — the detector's own label — decodes instead of
    /// throwing. Whether the number or the label is right is the backend's
    /// call; what is not acceptable is losing the map over it.
    @Test func aTextualSeverityDoesNotSinkThePayload() throws {
        let payload = try decode("""
        { "events": [
            { "id": "e1", "type": "EVT_01", "severity": "MODERADO", "lat": 40.4, "lng": -3.7 }
        ] }
        """)

        #expect(payload.events.count == 1)
        #expect(payload.events.first?.id == "e1")
        #expect(payload.events.first?.coordinate != nil, "el evento sigue colocándose en el mapa")
    }

    /// A number that arrives as a string is read as the number it is. «0.6» and
    /// 0.6 are the same measurement written two ways.
    @Test func aNumberWrittenAsTextIsStillTheNumber() throws {
        let payload = try decode("""
        { "events": [ { "id": "e1", "severity": "0.6" } ] }
        """)
        #expect(payload.events.first?.severity == 0.6)
    }

    /// A label is not a number, and no number is invented for it. `nil` means
    /// «no consta», which is what the screens already know how to show.
    @Test func aLabelYieldsNoNumber() throws {
        let payload = try decode("""
        { "events": [ { "id": "e1", "severity": "MODERADO" } ] }
        """)
        #expect(payload.events.first?.severity == nil, "nunca inventar una cifra a partir de una etiqueta")
    }

    /// A genuine number still decodes. The control case: without it, the tests
    /// above would pass for a decoder that ignores the field entirely.
    @Test func arealNumberStillDecodes() throws {
        let payload = try decode("""
        { "events": [ { "id": "e1", "severity": 0.95 } ] }
        """)
        #expect(payload.events.first?.severity == 0.95)
    }

    @Test func anIntegerIsANumberToo() throws {
        let payload = try decode("""
        { "events": [ { "id": "e1", "severity": 1 } ] }
        """)
        #expect(payload.events.first?.severity == 1.0)
    }

    @Test func anAbsentSeverityIsNil() throws {
        let payload = try decode("""
        { "events": [ { "id": "e1" } ] }
        """)
        #expect(payload.events.first?.severity == nil)
    }

    // MARK: - Y el resto del mapa sobrevive

    /// **The load-bearing case.** One bad event among good ones costs that
    /// event's severity and nothing else: the trace, the route and the other
    /// events all survive.
    @Test func oneBadEventCostsOnlyItsOwnField() throws {
        let payload = try decode("""
        {
          "route": [ {"lat": 40.4, "lng": -3.7}, {"lat": 40.5, "lng": -3.8} ],
          "events": [
            { "id": "malo", "severity": {"anidado": true}, "lat": 40.4, "lng": -3.7 },
            { "id": "bueno", "severity": 0.3, "lat": 40.5, "lng": -3.8 }
          ]
        }
        """)

        #expect(payload.route.count == 2, "el trazado del recorrido sobrevive")
        #expect(payload.events.count == 2, "los dos eventos siguen ahí")
        #expect(payload.events.first?.severity == nil)
        #expect(payload.events.last?.severity == 0.3)
        #expect(payload.pinnableEvents.count == 2)
    }

    /// An event whose OTHER fields are the wrong type also survives, for the
    /// same reason: the map is built from coordinates, and everything else is
    /// commentary.
    @Test func otherWrongTypesDoNotSinkThePayloadEither() throws {
        let payload = try decode("""
        { "events": [
            { "id": "e1", "penaltyPoints": "0.4", "speedKmh": "62", "lat": 40.4, "lng": -3.7 }
        ] }
        """)
        #expect(payload.events.count == 1)
        #expect(payload.events.first?.coordinate != nil)
    }
}
