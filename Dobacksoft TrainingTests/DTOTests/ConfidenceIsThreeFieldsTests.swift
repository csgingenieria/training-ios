import Testing
import Foundation

@testable import Dobacksoft_Training

/// Three fields called `confidence`, three different things.
///
/// **They are not one field with three shapes.** They are three fields that
/// share a name, in different objects, across two endpoints:
///
/// | dónde | tipo |
/// |---|---|
/// | `/attempts/<id>/gps` → `points[].confidence` | número o `null` |
/// | `/attempts/<id>/gps` → `track.confidence` | número o `null` |
/// | `/attempts/<id>` → `events[].confidence` | texto, `"HIGH"` / `"LOW"` |
///
/// This matters because a shared DTO, a generic decoder, or a well-meaning
/// «let's unify these» refactor joins them — and then one of the three is
/// wrong. It is the third defect in two days born of a reused name: first
/// `severity` (the map sent the label under the number's name), then the `401`
/// (two meanings under one status), now this.
///
/// It also explains why a type sweep did not catch it: a sweep compares the
/// same field between endpoints. These are not the same field.
struct ConfidenceIsThreeFieldsTests {
    private func mapa(_ json: String) throws -> GpsPayloadDTO {
        try JSONDecoder().decode(GpsPayloadDTO.self, from: Data(json.utf8))
    }

    private func ficha(_ json: String) throws -> AttemptDetailDTO {
        try JSONDecoder().decode(AttemptDetailDTO.self, from: Data(json.utf8))
    }

    /// The three at once, each with the shape its own endpoint sends.
    ///
    /// If someone unifies them, exactly one of these three lines stops
    /// compiling or stops passing.
    @Test func theThreeAreDecodedWithTheirOwnTypes() throws {
        let m = try mapa("""
        {
          "points": [ { "lat": 40.4, "lng": -3.7, "confidence": 0.9 } ],
          "track":  { "segments": [], "matched": true, "confidence": 0.7, "source": "OSRM" }
        }
        """)
        let f = try ficha("""
        { "id": "a1", "scoreBreakdown": [],
          "events": [ { "id": "e1", "confidence": "HIGH" } ] }
        """)

        #expect(m.points.first?.confidence == 0.9, "el punto: número")
        #expect(m.track?.confidence == 0.7, "la traza: número")
        #expect(f.events.first?.confidence == "HIGH", "el evento de la ficha: texto")
    }

    /// **The common case for a raw point is `null`.**
    ///
    /// Measured against the VPS database over 23.644 points of closed
    /// attempts: 23.209 null, 435 with a value. A non-optional `Double` here
    /// would not fail in a rare case — it would fail in 98,2 % of them.
    @Test func aRawPointWithoutConfidenceIsTheNormalCase() throws {
        let m = try mapa("""
        { "points": [
            { "lat": 40.4, "lng": -3.7, "confidence": null },
            { "lat": 40.5, "lng": -3.8 }
          ] }
        """)
        #expect(m.points.count == 2)
        #expect(m.points.allSatisfy { $0.confidence == nil })
        #expect(m.points.allSatisfy { $0.coordinate != nil }, "y los dos se colocan igual")
    }

    /// **A lap with no trace sends `{"confidence": null, "source": "empty"}`.**
    /// Twelve of twelve closed attempts have a real value today (0,6555–0,963),
    /// so the null case only appears where there is nothing to draw — exactly
    /// where a crash would be least excusable.
    @Test func aLapWithNoTraceStillDecodes() throws {
        let m = try mapa("""
        { "track": { "segments": [], "confidence": null, "source": "empty" } }
        """)
        #expect(m.track?.confidence == nil)
        #expect(m.track?.source == "empty")
        #expect(m.hasSomethingToDraw == false, "y la pantalla lo sabe decir")
    }

    /// **Each one tolerates the other's shape without sinking its response.**
    ///
    /// This is the test that actually guards the collision: send the text to
    /// the numeric fields and the number to the textual one. Each loses its
    /// own field and nothing else.
    @Test func eachSurvivesBeingSentTheOthersShape() throws {
        let m = try mapa("""
        {
          "points": [ { "lat": 40.4, "lng": -3.7, "confidence": "HIGH" } ],
          "track":  { "segments": [], "confidence": "HIGH", "source": "OSRM" },
          "events": [ { "id": "e1", "lat": 40.4, "lng": -3.7 } ]
        }
        """)
        #expect(m.points.first?.confidence == nil)
        #expect(m.points.first?.coordinate != nil, "el punto se sigue colocando")
        #expect(m.events.count == 1, "y el mapa sobrevive entero")

        let f = try ficha("""
        { "id": "a1", "scoreBreakdown": [],
          "events": [ { "id": "e1", "confidence": 0.9, "description": "Frenada." } ] }
        """)
        // **`nil`, no `"0.9"`.** Escribir este test descubrió que
        // `lenientString` convierte un número en texto, que para una
        // descripción o un `source` está bien y para un dominio cerrado
        // fabrica una etiqueta que el detector nunca puso. De ahí salió
        // `lenientLabel`, el espejo de la regla que `lenientDouble` ya tenía.
        #expect(f.events.first?.confidence == nil,
                "«0.9» no es «HIGH» ni «LOW»: no se inventa una etiqueta")
        #expect(f.events.first?.description == "Frenada.", "la ficha entera sobrevive")
        #expect(f.id == "a1")
    }

    /// **The `0.9` is not a measurement.** A single distinct value across every
    /// point that carries one: a constant somebody set. Nothing may branch on
    /// it, so nothing reads it — it is decoded to keep the DTO faithful to the
    /// contract and for no other reason.
    @Test func theRawPointConfidenceDrivesNothing() throws {
        let alto = try mapa("""
        { "points": [ { "lat": 40.4, "lng": -3.7, "confidence": 0.9 } ] }
        """)
        let sin = try mapa("""
        { "points": [ { "lat": 40.4, "lng": -3.7 } ] }
        """)

        #expect(alto.drawableSegments == sin.drawableSegments,
                "un punto no se dibuja distinto por traer la constante")
        #expect(alto.isFallback == sin.isFallback)
        #expect(alto.hasSomethingToDraw == sin.hasSomethingToDraw)
    }
}
