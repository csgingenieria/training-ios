import Foundation

/// Why there is no session any more.
///
/// The two endings need opposite messages and used to get the same one: none.
/// A rejected refresh token and a deliberate «Cerrar sesión» both dropped the
/// candidate on an empty login form, so the person who was mid-scroll reading
/// their position could not tell whether something had broken, whether they had
/// been signed out on purpose, or whether the app had simply forgotten them.
nonisolated enum LogoutReason: Sendable, Equatable {
    /// The backend rejected the stored credentials.
    case sessionExpired
    /// The person pressed «Cerrar sesión».
    case userInitiated

    /// What the login screen says about it, or `nil` when there is nothing to
    /// explain.
    ///
    /// «por seguridad» is doing real work: without it, an expiry reads as a
    /// fault of the app or of the candidate's account. Access tokens last an
    /// hour by design, and being asked for the password again is the system
    /// working, not failing.
    var notice: String? {
        switch self {
        case .sessionExpired:
            "Su sesión ha caducado por seguridad. Vuelva a iniciar sesión."
        case .userInitiated:
            // Salir es una decisión, no un incidente: un aviso aquí sobra.
            nil
        }
    }
}

/// Copy about the state of the session itself, in one testable place.
nonisolated enum SessionCopy: Sendable {
    /// Shown when the session could not be restored but the credentials are
    /// intact — no network, not a rejection.
    ///
    /// It has to say both halves. «Sin conexión» alone still leaves the
    /// candidate wondering whether they have to sign in again; «su sesión sigue
    /// activa» is the half that stops them from trying a password that cannot
    /// possibly work right now, which is what made the app feel broken.
    static let sessionSurvivesOffline =
        "Sin conexión. Su sesión sigue activa y se restaurará al recuperar la red."

    /// The launch screen, while the stored session is being verified.
    static let restoring = "Restaurando sesión…"
}
