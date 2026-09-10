import Testing
import Foundation

@testable import Dobacksoft_Training

/// One rule for the intensity of an incident, shared by the two endpoints that
/// describe the same incidents.
///
/// **This is the exact shape of a defect the backend had just finished fixing.**
/// The map called `severity` what the ficha calls `sensorSeverity` and sent the
/// label under the number's name; that one sank the payload, so it was found.
/// The version that does not sink anything is two DTOs each deriving the
/// intensity their own way — the same incident reading differently depending on
/// which screen you opened it from, and nothing crashing to say so.
struct SensorIntensityTests {
    // MARK: - La etiqueta manda

    /// The three labels the contract actually sends, verified against the
    /// endpoint: 125 events across six laps of the staging candidate came as
    /// `0.3/LEVE`, `0.6/MODERADO`, `0.95/CRITICO` — never another pairing.
    @Test func theThreeLabelsTheContractSends() {
        #expect(SensorIntensity.derived(label: "LEVE", number: 0.3) == .leve)
        #expect(SensorIntensity.derived(label: "MODERADO", number: 0.6) == .moderada)
        #expect(SensorIntensity.derived(label: "CRITICO", number: 0.95) == .critica)
    }

    /// **The label wins over the number**, and the disagreement is the test:
    /// reading the number first would reclassify an incident the detector
    /// itself had already named.
    @Test func theLabelWinsWhenTheTwoDisagree() {
        #expect(SensorIntensity.derived(label: "LEVE", number: 0.95) == .leve)
        #expect(SensorIntensity.derived(label: "CRITICO", number: 0.3) == .critica)
    }

    /// Case is not a promise the contract made. `Critico` must not silently
    /// become «no consta».
    @Test func theLabelIsReadRegardlessOfCase() {
        #expect(SensorIntensity.derived(label: "critico", number: nil) == .critica)
        #expect(SensorIntensity.derived(label: "Moderado", number: nil) == .moderada)
    }

    /// A label we do not know is not translated by eye: it falls through to the
    /// number, which is a measurement rather than a guess.
    @Test func anUnknownLabelFallsThroughToTheNumber() {
        #expect(SensorIntensity.derived(label: "GRAVISIMO", number: 0.3) == .leve)
        #expect(SensorIntensity.derived(label: "GRAVISIMO", number: nil) == nil,
                "sin número tampoco se inventa: no consta")
    }

    // MARK: - El centinela

    /// **0,5 means «could not be classified», and it must stay unclassified.**
    ///
    /// Rebuilt from the buckets it lands squarely in «moderada» — an intensity
    /// nobody measured, printed with the same confidence as one that was.
    @Test func theHalfSentinelIsNotAnIntensity() {
        #expect(SensorIntensity.derived(label: nil, number: 0.5) == nil)
        #expect(SensorIntensity.derived(label: "", number: 0.5) == nil)
    }

    /// But 0,5 with a real label IS classified: the sentinel says the number
    /// failed, not that the detector had nothing to say.
    @Test func theSentinelDoesNotDiscardAGoodLabel() {
        #expect(SensorIntensity.derived(label: "CRITICO", number: 0.5) == .critica)
    }

    @Test func withNeitherFieldNothingIsClaimed() {
        #expect(SensorIntensity.derived(label: nil, number: nil) == nil)
    }

    // MARK: - Los dos endpoints no pueden discrepar

    /// **The anti-drift test.** The same values, read through the map's DTO and
    /// through the ficha's, have to give the same answer — and each is asserted
    /// against the expected value by hand, not against the other, so that two
    /// DTOs drifting the same way could not both pass.
    @Test func theMapAndTheSheetReadTheSameIncidentTheSameWay() {
        let casos: [(String?, Double?, SensorIntensity?)] = [
            ("CRITICO", 0.95, .critica),
            ("MODERADO", 0.6, .moderada),
            ("LEVE", 0.3, .leve),
            (nil, 0.5, nil),
            (nil, nil, nil),
            ("LEVE", 0.95, .leve),
        ]

        for (etiqueta, numero, esperada) in casos {
            let mapa = GpsEventDTO(
                id: "e1", type: nil, severity: numero, sensorSeverity: etiqueta,
                source: nil, timestamp: nil, lat: 40, lng: -3,
                penaltyPoints: nil, noPenaltyReason: nil, stabilityLossPercent: nil,
                narrative: nil, advice: nil, speedKmh: nil, limitKmh: nil, excessKmh: nil
            )
            let ficha = AttemptEventDTO(
                severity: numero,
                sensorSeverity: etiqueta
            )

            let caso = "«\(etiqueta ?? "—")»/\(numero?.description ?? "—")"
            #expect(mapa.intensity == esperada, "el mapa lee \(caso) mal")
            #expect(ficha.intensity == esperada, "la ficha lee \(caso) mal")
        }
    }
}

/// What the map says in words about one incident.
struct AttemptMapIntensityCopyTests {
    private func evento(
        narrative: String? = nil,
        severity: Double? = nil,
        sensorSeverity: String? = nil,
        excessKmh: Double? = nil,
        type: String? = "EVT_01"
    ) -> GpsEventDTO {
        GpsEventDTO(
            id: "e1", type: type, severity: severity, sensorSeverity: sensorSeverity,
            source: nil, timestamp: nil, lat: 40, lng: -3,
            penaltyPoints: nil, noPenaltyReason: nil, stabilityLossPercent: nil,
            narrative: narrative, advice: nil, speedKmh: nil, limitKmh: nil,
            excessKmh: excessKmh
        )
    }

    /// **The pin's own title never carries the detector code.**
    ///
    /// The VoiceOver label had this rule written next to it and honoured it;
    /// the visible title fell back to `event.type`, so the code was hidden from
    /// whoever listens to the screen and shown to whoever looks at it.
    @Test func theVisibleTitleNeverShowsTheDetectorCode() {
        #expect(AttemptMapCopy.eventTitle(evento(type: "EVT_01")) == "Incidencia")
        #expect(AttemptMapCopy.eventTitle(evento(narrative: "Frenada brusca.")) == "Frenada brusca.")
    }

    /// Every pin is drawn as the same red circle, so intensity is the only
    /// thing that tells one from another: leaving it out of the label gives
    /// someone listening less than someone looking.
    @Test func theSpokenPinCarriesTheIntensityWhenItIsKnown() {
        let label = AttemptMapCopy.eventLabel(
            evento(narrative: "Frenada brusca.", severity: 0.95, sensorSeverity: "CRITICO")
        )
        #expect(label.contains("Frenada brusca"))
        #expect(label.lowercased().contains("intensidad crítica"))
    }

    /// And it says nothing when nothing is known — including for the sentinel.
    @Test func withNoIntensityTheLabelDoesNotInventOne() {
        for caso in [evento(narrative: "Frenada brusca."),
                     evento(narrative: "Frenada brusca.", severity: 0.5)] {
            let label = AttemptMapCopy.eventLabel(caso)
            #expect(label == "Frenada brusca.", "sobra todo lo que no consta: «\(label)»")
        }
    }

    /// **The map never claims the incident cost points.** This endpoint does
    /// not receive the field that says so — that is documented on the DTO — and
    /// a sentence about a deduction would be signed by a datum it does not
    /// have.
    @Test func theMapNeverSaysTheIncidentDeductedAnything() {
        let frases = [
            AttemptMapCopy.eventLabel(evento(narrative: "Frenada brusca.", sensorSeverity: "CRITICO")),
            AttemptMapCopy.intensity(.critica),
        ]
        for frase in frases {
            let bajo = frase.lowercased()
            for prohibida in ["penaliz", "resta", "restó", "deducc", "descuent", "puntos menos"] {
                #expect(bajo.contains(prohibida) == false,
                        "«\(frase)» afirma una deducción que el mapa no sabe")
            }
        }
    }

    /// The intensity sentence names the SENSOR, so nobody reads it as the
    /// gravity with which the incident was graded.
    @Test func theIntensitySentenceNamesTheSensor() {
        #expect(AttemptMapCopy.intensity(.moderada).lowercased().contains("sensor"))
        #expect(AttemptMapCopy.intensity(.moderada).contains("moderada"))
    }
}
