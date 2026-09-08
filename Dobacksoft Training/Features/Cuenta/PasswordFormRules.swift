import Foundation

/// Cuándo se puede enviar el cambio de contraseña, y qué se dice si el
/// servidor se niega.
///
/// Las reglas se comprueban en el cliente por una sola razón: **no gastar uno
/// de los cinco intentos por minuto** en un error que ya se ve desde aquí. El
/// servidor sigue siendo la autoridad — el cliente nunca decide que una
/// contraseña es correcta, solo que todavía no merece la pena enviarla.
nonisolated enum PasswordFormRules {
    /// El mínimo del backend. Vive aquí para poder avisar antes de gastar un
    /// intento; si el backend lo cambia, este número queda desactualizado y lo
    /// único que pasa es que el aviso llega del servidor en vez de local.
    static let minimumLength = 8

    /// Lo que el cliente puede afirmar con certeza.
    enum LocalProblem: Equatable {
        case doNotMatch
        case tooShort

        var message: String {
            switch self {
            case .doNotMatch: "Las dos contraseñas nuevas no coinciden."
            case .tooShort:   "La contraseña nueva debe tener al menos \(minimumLength) caracteres."
            }
        }
    }

    /// El único problema que el cliente ve sin preguntar.
    ///
    /// **No mira la contraseña actual**: si es correcta o no lo sabe el
    /// servidor, y adivinarlo aquí dejaría a alguien fuera de su propia cuenta
    /// por una regla del cliente.
    static func localProblem(new: String, confirm: String) -> LocalProblem? {
        // Sin recortar espacios: una contraseña puede llevarlos, y alterar en
        // silencio lo que alguien teclea haría que el formulario rechazase una
        // contraseña correcta sin explicar por qué.
        if !new.isEmpty, new.count < minimumLength { return .tooShort }
        if !new.isEmpty, new != confirm { return .doNotMatch }
        return nil
    }

    static func canSubmit(current: String, new: String, confirm: String) -> Bool {
        !current.isEmpty && !new.isEmpty && !confirm.isEmpty && localProblem(new: new, confirm: confirm) == nil
    }

    /// Lo que se enseña cuando el servidor rechaza el cambio.
    ///
    /// Las claves son las de `password_service`. Una que no se reconozca cae a
    /// una frase genérica: el código crudo no se le enseña a nadie.
    static func message(forServerError key: String?) -> String {
        switch key {
        case "missing_fields":
            "Rellene los tres campos para continuar."
        case "wrong_current_password":
            // Un error de tecleo, no una avería: el formulario sigue abierto y
            // la frase no alarma.
            "La contraseña actual no es correcta. Vuelva a introducirla."
        case "passwords_do_not_match":
            LocalProblem.doNotMatch.message
        case "password_too_short":
            LocalProblem.tooShort.message
        case "password_unchanged":
            // No es un fallo que merezca un reproche: es que no cambia nada.
            "La contraseña nueva es la misma que la actual."
        case "user_not_found":
            "No se ha podido identificar su cuenta. Vuelva a iniciar sesión."
        default:
            "No se ha podido cambiar la contraseña. Inténtelo de nuevo."
        }
    }
}
