import Testing
import Foundation

@testable import Dobacksoft_Training

/// Freezes the words the interface may NOT say to a candidate.
///
/// Training grades a public examination. The system computes an objective mark;
/// it does not issue a verdict — admission is decided by CMadrid, outside the
/// system, at the formal close. That is article 22 of the GDPR (the right to
/// human review), not a product preference, so the vocabulary is a contract
/// obligation and not a matter of taste.
///
/// `StatusVocabularyTests.noLabelStatesAnOutcome` already guards the status
/// badges. It never reached the prose: the sentence under every candidate's
/// position and the per-event explanations in the attempt sheet were written by
/// hand, screen by screen, and drifted. This suite covers that prose.
///
/// Two roots are new here and were the actual defect: `admitid` («tolerancia
/// admitida») and the *quota* sense of `plaza` («asignación de plaza»), which
/// `docs/CMADRID-ENTREGA.md` v1.1 denies to the client in writing.
@Suite struct UICopyVocabularyTests {
    /// Roots, not whole words: the forbidden term shows up inflected
    /// («admitida», «excluido», «aprobó»), and matching whole words lets every
    /// inflection through.
    ///
    /// `plaza` is banned in PROSE only. The kiosk enrolment number is also
    /// called «plaza» («Plaza 118», «Nombre o plaza») and is legitimate — it is
    /// a persistent identifier the candidate types into the tablet, not a quota.
    /// This suite therefore enumerates the sentences it checks instead of
    /// sweeping the repository, which would forbid that identifier too.
    private static let bannedRoots = [
        "apto", "aprob", "suspens", "admitid", "excluid", "corte", "plaza", "cupo",
    ]

    private func expectNoBannedRoot(_ copy: String, _ origin: String) {
        let lowered = copy.lowercased()
        for root in Self.bannedRoots {
            #expect(
                !lowered.contains(root),
                "«\(root)» aparece en \(origin): «\(copy)»"
            )
        }
    }

    // MARK: - Explicaciones de por qué un evento no restó

    /// Every branch of `noPenaltyLabel`, including the default.
    ///
    /// `dentro_de_tolerancia` and `franquicia` said «tolerancia admitida». The
    /// margin is *permitted* by the scoring configuration; «admitida» is the
    /// word the resolution uses for a person who gets in, and it has no place
    /// in a sentence about a sensor threshold.
    @Test func noPenaltyLabelsAvoidForbiddenRoots() {
        let reasons: [String?] = [
            "informativo", "evento_informativo",
            "dentro_de_tolerancia", "franquicia",
            "sin_datos_can", "un_motivo_que_no_conocemos", "", nil,
        ]

        for reason in reasons {
            let event = AttemptEventDTO.stub(noPenaltyReason: reason)
            expectNoBannedRoot(
                event.noPenaltyLabel,
                "noPenaltyLabel(noPenaltyReason: \(reason.map { "\"\($0)\"" } ?? "nil"))"
            )
        }
    }

    /// The sentence has to state the fact — it did not deduct — without
    /// reassuring or judging.
    @Test func theToleranceBranchStillExplainsItself() {
        for reason in ["dentro_de_tolerancia", "franquicia"] {
            let label = AttemptEventDTO.stub(noPenaltyReason: reason).noPenaltyLabel
            #expect(label.contains("tolerancia"), "«\(label)» ya no explica el motivo")
            #expect(label.contains("no ha restado puntuación"))
        }
    }

    // MARK: - Avisos legales

    /// The sentence that sits under every candidate's position.
    ///
    /// It said «La asignación de plaza la decide CMadrid al cierre de la
    /// convocatoria» in two views — the quota sense of «plaza» that
    /// `docs/CMADRID-ENTREGA.md` v1.1 denies to the client. It was the most
    /// exposed string in the app and the least reviewed.
    @Test func theOutcomeNoticeAvoidsForbiddenRoots() {
        expectNoBannedRoot(LegalNotice.outcomeDecidedByCMadrid, "LegalNotice.outcomeDecidedByCMadrid")
    }

    /// Article 22 is about the candidate knowing a human decides. A notice that
    /// drops either half — who decides, or that it happens outside the app —
    /// stops doing the job it exists for.
    @Test func theOutcomeNoticeNamesWhoDecidesAndWhere() {
        let notice = LegalNotice.outcomeDecidedByCMadrid

        #expect(notice.contains("CMadrid"), "el aviso ya no dice quién decide")
        #expect(notice.contains("fuera de esta aplicación"), "el aviso ya no dice que se decide fuera")
    }

    // MARK: - Aclaraciones de la nota

    @Test func gradeFinalityCopyAvoidsForbiddenRoots() {
        let states = ["OPEN", "PREVIEW", "CLOSING", "CLOSED", "LOCKED", "DRAFT", "", nil]

        for state in states {
            let finality = GradeFinality(convocatoriaStatus: state)
            expectNoBannedRoot(finality.scoreLabel, "GradeFinality.scoreLabel(\(state ?? "nil"))")
            if let note = finality.note {
                expectNoBannedRoot(note, "GradeFinality.note(\(state ?? "nil"))")
            }
        }
    }
}

// MARK: - Stub

private extension AttemptEventDTO {
    /// A minimal event: this suite only reads the copy derived from
    /// `noPenaltyReason`, so everything else stays nil.
    static func stub(noPenaltyReason: String?) -> AttemptEventDTO {
        AttemptEventDTO(
            type: nil,
            severity: nil,
            confidence: nil,
            description: nil,
            timestamp: nil,
            source: nil,
            penaltyPoints: nil,
            categoria: nil,
            affectsScore: false,
            noPenaltyReason: noPenaltyReason,
            sensorSeverity: nil
        )
    }
}
