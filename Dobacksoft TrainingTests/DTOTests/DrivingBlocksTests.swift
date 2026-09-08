import Testing
import Foundation

@testable import Dobacksoft_Training

/// The four driving blocks of the attempt sheet — block C, read from
/// `mobile_api/services.py` and `schemas.py` on `origin/main`.
///
/// The two ⚠ the backend flags are the two things worth testing, and both are
/// about not asserting something false about a person:
///
/// - `compliancePct` caps at 100 and `rawCompliancePct` does not. They are not
///   the same number rounded, so a screen showing one as the other would be
///   reporting a compliance the candidate did not have.
/// - `partialWebfleet` and `drivingNarrative` arrive `null` when the Webfleet
///   indicator is not the attempt's own window. Attempts enriched before
///   2026-08-06 stored the WEEKLY preset, and attributing the truck's week of
///   driving to the candidate is imputing someone else's conduct. `null` there
///   is the backend refusing to do that, so the client must not fill the gap.
struct DrivingBlocksTests {
    private func decode(_ json: String) throws -> AttemptDetailDTO {
        try JSONDecoder().decode(AttemptDetailDTO.self, from: Data(json.utf8))
    }

    private func sheet(_ extra: String) -> String {
        #"{"id": "a-1", "scoreBreakdown": [], "events": [], \#(extra)}"#
    }

    // MARK: - null no es un error

    /// Every one of the four is absent on plenty of real attempts. A missing
    /// block is «this attempt does not have it», and painting an empty card
    /// would read as a zero — which is a statement about the driver.
    @Test func theFourBlocksAreAllowedToBeMissing() throws {
        let a = try decode(sheet(#""allison": null, "partialWebfleet": null, "drivingNarrative": null"#))

        #expect(a.allison == nil)
        #expect(a.partialWebfleet == nil)
        #expect(a.drivingNarrative == nil)
        #expect(a.showsDrivingBlocks == false, "sin ninguno de los tres no hay sección que pintar")
    }

    @Test func anOlderServerWithoutTheFieldsStillDecodes() throws {
        let a = try decode(#"{"id": "a-1", "scoreBreakdown": [], "events": []}"#)

        #expect(a.allison == nil)
        #expect(a.webfleetQueriedNoTrip == nil, "ausente no es false")
    }

    // MARK: - allison, y el ⚠ de los dos porcentajes

    @Test func theAllisonBoxDecodes() throws {
        let a = try decode(sheet(#"""
        "allison": {"evaluated": true, "reason": null, "presses": 7, "minimumPresses": 5,
                    "compliancePct": 100.0, "rawCompliancePct": 140.0, "outOfTen": 10.0,
                    "deduction": 0.0, "weight": 0.15, "max": 1.5, "contribution": 1.5,
                    "maxPenalty": 1.5, "curveExponent": 1.0}
        """#))

        let allison = try #require(a.allison)
        #expect(allison.evaluated == true)
        #expect(allison.presses == 7)
        #expect(allison.minimumPresses == 5)
        #expect(allison.outOfTen == 10.0)
    }

    /// The ⚠ itself: exceeding the minimum does not add, so `compliancePct`
    /// tops out while `rawCompliancePct` keeps going. Showing 140 % as
    /// compliance would credit the candidate with something the criterion does
    /// not award; showing 100 % as raw would hide that they exceeded it.
    @Test func cappedAndRawComplianceAreNotTheSameNumber() throws {
        let a = try decode(sheet(#""allison": {"compliancePct": 100.0, "rawCompliancePct": 140.0}"#))
        let allison = try #require(a.allison)

        #expect(allison.compliancePct == 100.0)
        #expect(allison.rawCompliancePct == 140.0)
        #expect(allison.exceededTheMinimum, "140 sobre un tope de 100: se pasó del mínimo")
    }

    @Test func meetingTheMinimumExactlyIsNotExceedingIt() throws {
        let a = try decode(sheet(#""allison": {"compliancePct": 100.0, "rawCompliancePct": 100.0}"#))

        #expect(try #require(a.allison).exceededTheMinimum == false)
    }

    /// An unevaluated box carries its reason, and the sheet says the reason
    /// rather than drawing an empty gauge.
    @Test func anUnevaluatedBoxSaysWhy() throws {
        let a = try decode(sheet(#""allison": {"evaluated": false, "reason": "sin_datos_can"}"#))
        let allison = try #require(a.allison)

        #expect(allison.evaluated == false)
        #expect(allison.reason == "sin_datos_can")
    }

    // MARK: - partialWebfleet: el agregado, nunca los viajes

    @Test func thePartialHalfDecodes() throws {
        let a = try decode(sheet(#"""
        "partialWebfleet": {"optidrive": 0.75, "outOfTen": 7.5, "distanceKm": 12.4,
                            "durationMin": 45, "tripCount": 2,
                            "missing": "estabilidad (sensor del camión)", "drivingWeightPct": 15.0}
        """#))

        let parcial = try #require(a.partialWebfleet)
        #expect(parcial.outOfTen == 7.5)
        #expect(parcial.tripCount == 2)
        #expect(parcial.missing == "estabilidad (sensor del camión)")
        #expect(parcial.drivingWeightPct == 15.0)
    }

    /// `outOfTen` is the scale the grade is read in — it is NOT the grade. A
    /// screen labelling it «su nota» would publish half a grade as the whole.
    @Test func theHalfIsNotAGrade() throws {
        let a = try decode(sheet(#""partialWebfleet": {"outOfTen": 7.5, "missing": "estabilidad"}"#))
        let parcial = try #require(a.partialWebfleet)

        #expect(parcial.isHalfOfTheGrade, "lo dice el propio campo `missing`")
    }

    // MARK: - drivingNarrative

    @Test func theNarrativeDecodesWithItsPoints() throws {
        let a = try decode(sheet(#"""
        "drivingNarrative": {"outOfTen": 7.5, "optidrive": 0.75, "isPartial": true,
          "missing": "estabilidad (sensor del camión)", "distanceKm": 12.4, "durationMin": 45,
          "points": [
            {"title": "Frenadas", "detail": "Sin frenadas bruscas.", "level": "bueno", "outOfTen": 10.0},
            {"title": "Ralentí", "detail": "Demasiado tiempo al ralentí.", "level": "malo", "outOfTen": 4.0}]}
        """#))

        let narrativa = try #require(a.drivingNarrative)
        #expect(narrativa.points.count == 2)
        #expect(narrativa.points.first?.level == .bueno)
        #expect(narrativa.points.last?.level == .malo)
        #expect(narrativa.isPartial == true)
    }

    @Test func theFourLevelsAreUnderstood() throws {
        for (raw, esperado) in [("bueno", DrivingLevel.bueno), ("regular", .regular),
                                ("malo", .malo), ("neutro", .neutro)] {
            let a = try decode(sheet(#""drivingNarrative": {"points": [{"title": "T", "level": "\#(raw)"}]}"#))
            #expect(try #require(a.drivingNarrative).points.first?.level == esperado)
        }
    }

    @Test func anUnknownLevelIsNotInvented() throws {
        let a = try decode(sheet(#""drivingNarrative": {"points": [{"title": "T", "level": "regulero"}]}"#))

        #expect(try #require(a.drivingNarrative).points.first?.level == nil)
    }

    // MARK: - webfleetQueriedNoTrip

    /// «Ya se preguntó y no había viaje» is not «todavía no se ha preguntado».
    /// Saying «pendiente» for the first sends the candidate to wait for
    /// something that is never going to arrive.
    @Test func askedAndFoundNothingIsNotTheSameAsNotAskedYet() throws {
        let preguntado = try decode(sheet(#""webfleetQueriedNoTrip": true"#))
        let sinPreguntar = try decode(sheet(#""webfleetQueriedNoTrip": false"#))

        #expect(preguntado.webfleetQueriedNoTrip == true)
        #expect(sinPreguntar.webfleetQueriedNoTrip == false)
        #expect(preguntado.drivingDataWillNotArrive)
        #expect(sinPreguntar.drivingDataWillNotArrive == false)
    }

    /// The one case that must not claim anything: an older server sends
    /// nothing, and «no field» is not «asked and found nothing».
    @Test func anAbsentFlagClaimsNothing() throws {
        let a = try decode(#"{"id": "a-1", "scoreBreakdown": [], "events": []}"#)

        #expect(a.drivingDataWillNotArrive == false)
    }
}
