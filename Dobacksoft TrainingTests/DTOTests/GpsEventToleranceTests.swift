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

    // MARK: - Las dos formas de la gravedad

    /// **The map sends the number AND the label, and the client kept only one.**
    ///
    /// The original defect was loud: the map called `severity` what the ficha
    /// calls `sensorSeverity`, sent the label under the number's name, and sank
    /// the whole payload. Fixing it upstream made the map send both, with the
    /// ficha's own names — and this client went on decoding one of the two, in
    /// silence.
    ///
    /// Evidence, captured from the endpoint itself and not from a fixture in
    /// this repository: 125 events across six laps of the staging candidate,
    /// `GET /api/v1/attempts/<id>/gps`. In every one of the 125, `severity` is
    /// a number and `sensorSeverity` is a string, paired as `0.3/LEVE`,
    /// `0.6/MODERADO`, `0.95/CRITICO`.
    @Test func theMapSendsBothTheNumberAndTheLabelAndBothAreKept() throws {
        let payload = try decode("""
        { "events": [
            { "id": "e1", "severity": 0.95, "sensorSeverity": "CRITICO", "lat": 40.4, "lng": -3.7 }
        ] }
        """)
        let evento = try #require(payload.events.first)
        #expect(evento.severity == 0.95)
        #expect(evento.sensorSeverity == "CRITICO", "la etiqueta del sensor llegaba y se tiraba")
    }

    /// **The label is never turned into a number here.**
    ///
    /// A `Double(...)` on `"CRITICO"` yields nothing, but a helpful mapping —
    /// `CRITICO` → `1.0` — would invent a severity the detector never assigned
    /// and print it as if the server had said it. The number comes from the
    /// server or it does not exist.
    @Test func theLabelIsNeverConvertedIntoASeverityClientSide() throws {
        let payload = try decode("""
        { "events": [
            { "id": "e1", "sensorSeverity": "CRITICO", "lat": 40.4, "lng": -3.7 }
        ] }
        """)
        let evento = try #require(payload.events.first)
        #expect(evento.sensorSeverity == "CRITICO")
        #expect(evento.severity == nil, "sin número del servidor no hay número, y la etiqueta no lo sustituye")
    }

    /// The old shape still decodes, because a server can be older than a
    /// client: the label arriving under the number's name costs that number and
    /// nothing else, and it must not be read as a label either.
    @Test func theOldShapeStillCostsOnlyItsOwnField() throws {
        let payload = try decode("""
        { "events": [
            { "id": "e1", "severity": "CRITICO", "lat": 40.4, "lng": -3.7 }
        ] }
        """)
        let evento = try #require(payload.events.first)
        #expect(evento.severity == nil)
        #expect(evento.sensorSeverity == nil, "no se rescata de la otra clave: sería adivinar")
        #expect(evento.coordinate != nil, "y el evento sigue colocado en el mapa")
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

    // MARK: - Los puntos crudos, que se habían quedado fuera de la regla

    /// **`confidence` is a number, and the DTO said it was a String.**
    ///
    /// Not «sometimes a number»: never a string. Across the eleven laps of the
    /// staging candidate there are 4.685 points with `null` and 381 with
    /// `0.9`, and not one with text. `decodeIfPresent(String.self)` throws on
    /// `0.9`, `GpsPointDTO` decoded strictly, and one point in five thousand
    /// sank the whole map — eleven maps out of eleven.
    ///
    /// The same field with the same meaning is already `Double` on
    /// `GpsTrackDTO.confidence`. Two declarations of one datum and only one of
    /// them right.
    @Test func theConfidenceOfARawPointIsANumber() throws {
        let payload = try decode("""
        { "points": [
            { "lat": 40.4, "lng": -3.7, "speed": 31.2, "confidence": 0.9, "source": "WEBFLEET" }
        ] }
        """)
        let punto = try #require(payload.points.first)
        #expect(punto.confidence == 0.9)
        #expect(punto.coordinate != nil)
    }

    /// Most points carry no confidence at all, and that is not a failure.
    @Test func aPointWithoutConfidenceIsStillAPoint() throws {
        let payload = try decode("""
        { "points": [ { "lat": 40.4, "lng": -3.7, "speed": 31.2, "confidence": null } ] }
        """)
        #expect(payload.points.first?.confidence == nil)
        #expect(payload.points.first?.coordinate != nil)
    }

    /// **And now a wrong type on a point costs that point's field, not the
    /// map.**
    ///
    /// This is the load-bearing one. The rule «an unexpected type must not sink
    /// the response» was already written, tested and honoured — for `events`.
    /// `points` was left out of it, and that omission is the whole defect: the
    /// discipline existed, applied to one of the four arrays.
    @Test func aWrongTypeOnARawPointDoesNotSinkTheMap() throws {
        let payload = try decode("""
        {
          "points": [
            { "lat": 40.4, "lng": -3.7, "confidence": "alta" },
            { "lat": 40.5, "lng": -3.8, "confidence": 0.9 }
          ],
          "events": [ { "id": "e1", "lat": 40.4, "lng": -3.7 } ]
        }
        """)

        #expect(payload.points.count == 2, "los dos puntos siguen ahí")
        #expect(payload.points.first?.confidence == nil, "solo se pierde el campo raro")
        #expect(payload.points.first?.coordinate != nil, "y el punto se sigue colocando")
        #expect(payload.points.last?.confidence == 0.9)
        #expect(payload.events.count == 1, "y el resto del mapa sobrevive")
    }

    /// **The speeds arrive as integers sometimes.** Not a hypothesis: in the
    /// same capture of 125 events, `speedKmh` and `limitKmh` come as `Int` on
    /// some events and `Double` on others — JSON has one number type and the
    /// backend serialises `60` without a decimal point.
    ///
    /// A plain `decodeIfPresent(Double.self)` throws on `60`. Lenient reading
    /// already covers it; this pins it, because it is the kind of thing someone
    /// "tightens up" later.
    @Test func anIntegerSpeedIsStillASpeed() throws {
        let payload = try decode("""
        { "events": [
            { "id": "e1", "speedKmh": 60, "limitKmh": 50, "lat": 40.4, "lng": -3.7 }
        ] }
        """)
        let evento = try #require(payload.events.first)
        #expect(evento.speedKmh == 60)
        #expect(evento.limitKmh == 50)
    }
}
