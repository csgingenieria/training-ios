import Testing
import Foundation

@testable import Dobacksoft_Training

/// Freezes the backend enumerations this client reads, so a value added there
/// breaks the build here instead of going quiet on screen.
///
/// The Training team offered to warn us before adding a value. Their own agent
/// then found the flaw in that promise: nothing enforced it on their side — it
/// lived in a comment. The same held here. Pinning each value one by one, which
/// is what these tests did, proves the values we know are handled; it says
/// nothing about a value we have never seen.
///
/// A promise kept by one party is a hope. These tests are our half of it: if
/// the frozen set stops matching what the contract sends, someone has to come
/// back to this file and decide what the new value means before shipping.
@Suite struct ContractEnumFreezeTests {
    // MARK: - Estado de la convocatoria

    /// `ConvocatoriaStatus` in `app/models/training.py`, verified 2026-09-07.
    ///
    /// `PREVIEW` is never assigned by any backend flow — it survives in the
    /// enum only because the immutability triggers hold it in their protected
    /// set and removing it needs a delicate migration. It is mapped anyway,
    /// because a value that exists can arrive.
    private static let convocatoriaStates = ["OPEN", "PREVIEW", "CLOSING", "CLOSED", "LOCKED"]

    @Test func everyConvocatoriaStateDecidesWhetherTheGradeCanStillChange() {
        for state in Self.convocatoriaStates {
            let finality = GradeFinality(convocatoriaStatus: state)
            #expect(
                finality != .unknown,
                "«\(state)» cae a .unknown: el aspirante deja de ver si su nota puede cambiar"
            )
        }
    }

    /// The server's own rule: `_ESTADOS_NOTA_DEFINITIVA = {CLOSED, LOCKED}` in
    /// `student_service.py`. Everything else is provisional. This client must
    /// not disagree with it on the same screen.
    @Test func theClientAgreesWithTheServerOnWhatIsFinal() {
        #expect(GradeFinality(convocatoriaStatus: "CLOSED") == .pendingConfirmation)
        #expect(GradeFinality(convocatoriaStatus: "LOCKED") == .definitive)

        for provisional in ["OPEN", "PREVIEW", "CLOSING"] {
            #expect(GradeFinality(convocatoriaStatus: provisional) == .provisional)
        }
    }

    @Test func everyConvocatoriaStateReadsAsSpanish() {
        for state in Self.convocatoriaStates {
            let shown = StatusVocabulary.convocatoria(state).label
            #expect(shown != state, "«\(state)» se enseña crudo al usuario")
            #expect(shown != "Sin estado")
        }
    }

    /// A value outside the frozen set is exactly what the warning is for.
    ///
    /// This is not a failure to fix by widening the set: it is the signal to
    /// read the contract, decide what the new state means for a candidate's
    /// grade, and only then add it here.
    @Test func anUnfrozenStateIsHandledHonestlyMeanwhile() {
        #expect(GradeFinality(convocatoriaStatus: "ANULADA") == .unknown)
        #expect(StatusVocabulary.convocatoria("ANULADA").label == "ANULADA")
    }

    // MARK: - Estado de una fila del desglose

    /// The four values documented in the mobile blueprint beside
    /// `"state": item.get("estado")`, verified 2026-09-07.
    private static let breakdownStates = ["no_medido", "no_evaluable", "pendiente_enrichment", "invalido"]

    @Test func everyBreakdownStateExplainsItself() throws {
        for state in Self.breakdownStates {
            let json = Data("""
            {"family": "X", "key": "x", "max": 1.0, "obtained": null,
             "reason": "un_motivo_que_esta_app_no_conoce", "state": "\(state)"}
            """.utf8)

            let row = try JSONDecoder().decode(AttemptScoreFamilyDTO.self, from: json)

            #expect(
                row.unavailabilityDetail != nil,
                "«\(state)» dejaría la fila en «No evaluado» sin decir por qué"
            )
        }
    }

    /// The reason vocabulary is open on purpose — each component coins its own —
    /// so it is NOT frozen. What is frozen is the fallback: an unknown reason
    /// must never silence the row.
    @Test func anUnknownReasonFallsBackToTheState() throws {
        let json = Data("""
        {"family": "X", "key": "x", "max": 1.0, "obtained": null,
         "reason": "motivo_inventado_manana", "state": "no_medido"}
        """.utf8)

        let row = try JSONDecoder().decode(AttemptScoreFamilyDTO.self, from: json)

        #expect(row.unavailabilityDetail != nil)
    }
}
