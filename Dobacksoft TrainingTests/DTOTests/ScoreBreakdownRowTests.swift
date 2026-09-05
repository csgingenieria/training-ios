import Testing
import Foundation

@testable import Dobacksoft_Training

/// The breakdown row carries three distinct situations behind two nullable
/// numbers. Rendering "obtained / max" for all of them printed "— / 0" for a
/// component nobody could measure — which reads as a zero the candidate scored.
struct ScoreBreakdownRowTests {
    private func row(_ obtained: Double?, _ max: Double?) -> AttemptScoreFamilyDTO {
        AttemptScoreFamilyDTO(family: "Estabilidad (deducciones)", obtained: obtained, max: max)
    }

    @Test func measuredRowKeepsBothNumbers() {
        guard case let .measured(obtained, max) = row(4.5, 5.0).presentation else {
            Issue.record("se esperaba .measured")
            return
        }
        #expect(obtained == 4.5)
        #expect(max == 5.0)
    }

    /// `obtained == nil` with `max == 0.0` is the backend's `_fila_no_medida`,
    /// and also every row when the quality gates fail.
    @Test func rowWithNoWeightIsNotMeasured() {
        #expect(row(nil, 0.0).presentation == .notMeasured)
        #expect(row(nil, nil).presentation == .notMeasured)
    }

    /// The component counts towards the grade but its value did not arrive.
    @Test func rowWithWeightButNoValueIsMissingData() {
        #expect(row(nil, 3.0).presentation == .missingData)
    }

    @Test func aZeroIsAMeasuredZeroNotAnAbsence() {
        #expect(row(0.0, 5.0).presentation == .measured(obtained: 0.0, max: 5.0))
    }

    /// Copy must not attribute an unmeasured component to the candidate.
    @Test func unmeasuredRowsReadAsUnmeasured() {
        #expect(AttemptScoreFamilyDTO.Presentation.notMeasured.label == "No evaluado")
        #expect(AttemptScoreFamilyDTO.Presentation.missingData.label == "Sin dato")
    }

    /// `family` is a display label, not a key. A measured row and an unmeasured
    /// one for the same component carry the SAME label, so identifying rows by
    /// it made SwiftUI collapse them in the `ForEach`. Pinned here so nobody
    /// reintroduces `id = family`.
    @Test func labelDoesNotIdentifyARow() {
        let measured = row(4.5, 5.0)
        let unmeasured = row(nil, 0.0)
        #expect(measured.family == unmeasured.family)
        #expect(measured != unmeasured)
    }

    /// Real shape from the backend when the quality gates fail: every row
    /// arrives unmeasured, so the whole card must read as unmeasured.
    @Test func failedGatesLeaveEveryRowUnmeasured() throws {
        let json = Data("""
        [
          {"family": "Estabilidad (deducciones)", "obtained": null, "max": 0.0},
          {"family": "Conducción (eventos de Webfleet)", "obtained": null, "max": 0.0},
          {"family": "Velocidad (excesos por vía)", "obtained": null, "max": 0.0}
        ]
        """.utf8)

        let rows = try JSONDecoder().decode([AttemptScoreFamilyDTO].self, from: json)

        #expect(rows.count == 3)
        #expect(rows.allSatisfy { $0.presentation == .notMeasured })
    }
}
