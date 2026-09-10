import Testing
import Foundation

@testable import Dobacksoft_Training

/// What the map claims in words.
///
/// A map asserts things with the shape of a line, so the label under it is not
/// decoration: it is the difference between a measurement and a drawing. These
/// cases pin the three claims the screen is allowed to make and the ones it is
/// not.
struct AttemptMapCopyTests {
    private func payload(
        segments: [[GpsCoordinateDTO]] = [[.init(lat: 40, lng: -3), .init(lat: 41, lng: -4)]],
        matched: Bool? = true,
        confidence: Double? = 0.95,
        points: [GpsPointDTO] = []
    ) -> GpsPayloadDTO {
        GpsPayloadDTO(
            points: points, route: [], events: [],
            track: GpsTrackDTO(segments: segments, matched: matched, confidence: confidence, source: "osrm")
        )
    }

    // MARK: - Qué se está mirando

    /// A trace snapped to the road, well placed, is allowed to be presented as
    /// the lap that was driven.
    @Test func aReliableTraceIsPresentedAsTheLap() {
        let copy = AttemptMapCopy.traceLabel(payload(matched: true, confidence: 0.95))

        #expect(copy.contains("calzada") || copy.contains("ajustad"))
        #expect(copy.contains("aproximad") == false, "una traza fiable no se rebaja")
    }

    /// Placed at 40 % is not a measurement, and the label has to say so rather
    /// than let the line speak for itself.
    @Test func aPoorlyPlacedTraceIsNotPresentedAsAMeasurement() {
        let copy = AttemptMapCopy.traceLabel(payload(matched: true, confidence: 0.4))

        #expect(copy.contains("aproximad") || copy.contains("parcial"),
                "«\(copy)» presenta una interpolación como si fuera medida")
    }

    /// Raw points are the fallback and the label says it: they are not a worse
    /// version of the trace, they are a different thing.
    @Test func rawPointsAreLabelledAsTheFallback() {
        let copy = AttemptMapCopy.traceLabel(
            payload(segments: [], matched: false, confidence: nil,
                    points: [.init(lat: 40, lng: -3, speed: nil, confidence: nil, source: nil)])
        )

        #expect(copy.contains("sin ajustar") || copy.contains("crudos") || copy.contains("puntos"))
        #expect(copy.contains("calzada") == false, "sin pegar a la calzada no se menciona la calzada")
    }

    /// Never a verdict on the driving: the label describes the DATA, and the
    /// quality of a GPS fix says nothing about how someone drove.
    @Test func theLabelNeverJudgesTheDriving() {
        for confianza in [0.1, 0.5, 0.95] {
            let copy = AttemptMapCopy.traceLabel(payload(confidence: confianza)).lowercased()
            for juicio in ["mal", "bien", "correcto", "incorrecto", "error"] {
                #expect(copy.contains(juicio) == false, "«\(juicio)» juzga en «\(copy)»")
            }
        }
    }

    // MARK: - Los cortes

    /// The cut is the datum, and the sentence has to say what it means: the GPS
    /// could not confirm that stretch, NOT that the truck stopped.
    @Test func theGapsSentenceExplainsWhatACutMeans() {
        let copy = AttemptMapCopy.gaps

        #expect(copy.contains("GPS") || copy.contains("señal"))
        #expect(copy.contains("paró") == false, "un corte no afirma que el camión se detuviera")
        #expect(copy.contains("detuvo") == false)
    }

    // MARK: - Lo que el mapa NO dice

    /// The map does not know whether an event deducted, and says where that
    /// answer lives instead of guessing. Guessing here is what would make the
    /// same event contradict itself between two screens.
    @Test func theSheetIsNamedAsWhereTheDeductionLives() {
        let copy = AttemptMapCopy.deductionLivesInTheSheet

        #expect(copy.contains("desglose") || copy.contains("ficha"))
        for afirmacion in ["restó", "no restó", "penaliz"] {
            #expect(copy.lowercased().contains(afirmacion) == false,
                    "«\(afirmacion)» afirma algo que este endpoint no sabe")
        }
    }

    // MARK: - Velocidad

    @Test func speedingStatesTheLimitAndTheExcess() {
        let copy = AttemptMapCopy.speeding(excess: 12, limit: 50, speed: 62)

        #expect(copy.contains("50"))
        #expect(copy.contains("12"))
        #expect(copy.contains("62"))
    }

    /// Without the measured speed the sentence still works: the limit and the
    /// excess are the two facts, and inventing the third is not needed.
    @Test func speedingWorksWithoutTheMeasuredSpeed() {
        let copy = AttemptMapCopy.speeding(excess: 12, limit: 50, speed: nil)

        #expect(copy.contains("50"))
        #expect(copy.contains("12"))
    }

    // MARK: - VoiceOver de un pin

    /// A pin has to be readable without seeing the map: what happened and, if
    /// it is known, where in the lap.
    @Test func theSpokenPinSaysWhatHappened() {
        let evento = GpsEventDTO(
            id: "e-1", type: "EVT_01", severity: 0.9, sensorSeverity: "CRITICO", source: "DOBACK_ELITE", timestamp: nil,
            lat: 40, lng: -3, penaltyPoints: 1, noPenaltyReason: nil, stabilityLossPercent: nil,
            narrative: "Frenada brusca.", advice: "Anticipe la frenada.",
            speedKmh: nil, limitKmh: nil, excessKmh: nil
        )

        let label = AttemptMapCopy.eventLabel(evento)

        #expect(label.contains("Frenada brusca"))
        #expect(label.contains("EVT_01") == false, "el código del detector no se le lee a nadie")
    }

    /// With no narrative it falls back to something sayable rather than reading
    /// out an internal code.
    @Test func aPinWithoutANarrativeStillSaysSomething() {
        let evento = GpsEventDTO(
            id: "e-1", type: "EVT_01", severity: nil, sensorSeverity: nil, source: nil, timestamp: nil,
            lat: 40, lng: -3, penaltyPoints: nil, noPenaltyReason: nil, stabilityLossPercent: nil,
            narrative: nil, advice: nil, speedKmh: nil, limitKmh: nil, excessKmh: nil
        )

        let label = AttemptMapCopy.eventLabel(evento)

        #expect(label.isEmpty == false)
        #expect(label.contains("EVT_01") == false)
    }
}
