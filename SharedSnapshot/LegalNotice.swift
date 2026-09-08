import Foundation

/// The load-bearing sentences that appear on more than one screen.
///
/// These are not decoration. Training grades a public examination: the system
/// computes an objective mark and **does not issue a verdict** — the outcome is
/// determined by CMadrid, outside the system, at the formal close. That is
/// article 22 of the GDPR (the right to human review), and
/// `docs/CMADRID-ENTREGA.md` v1.1 states to the client in writing that the
/// system manages neither places nor quotas.
///
/// They live here because they were written by hand, screen by screen, and
/// drifted: two views described what CMadrid decides using the quota sense of a
/// word the delivered document denies. One sentence in one place cannot drift,
/// and `UICopyVocabularyTests` pins it.
///
/// The old wording is deliberately not quoted here: a repository-wide sweep for
/// the forbidden roots should come back empty, and a comment that recites them
/// turns that sweep into a false positive.
///
/// It lives in `SharedSnapshot/` so the widget shares it. It did not, and drift
/// started again within the day: the app was changed to state that a
/// provisional result has no legal effect while the widget went on saying only
/// that the mark may vary. Two surfaces describing one state in two ways is the
/// exact failure this file was created to end — and the widget is the surface
/// other people see, sitting on a home screen.
nonisolated enum LegalNotice: Sendable {
    /// Who decides the outcome of the examination, when, and where.
    ///
    /// «fuera de esta aplicación» is the operative half: it tells the candidate
    /// that no screen here is the decision, which is exactly what article 22
    /// requires them to know.
    static let outcomeDecidedByCMadrid =
        "El resultado de la oposición lo determina CMadrid al cierre formal de la convocatoria, fuera de esta aplicación."

    /// That a mark shown before the formal close is not yet a decision.
    ///
    /// The portal prints this on every page, the attempt screen included. The
    /// client only said the mark «puede variar», which is the mild half: it
    /// describes the number moving, not what the number does not yet mean. The
    /// attempt detail is also the screen most likely to be photographed and
    /// passed around, which is exactly where the sentence has to be.
    static let provisionalHasNoLegalEffect =
        "Resultado provisional. No tiene efecto jurídico hasta el cierre oficial de la convocatoria."
}
