import Foundation

/// Cuándo se puede enviar el formulario de acceso, y qué hace Return.
///
/// Vive fuera de la vista para poder probarlo: «cuándo se puede enviar» es la
/// clase de condición a la que alguien le añade un `||` con prisa y nadie nota
/// que ya permite entrar con la contraseña vacía.
nonisolated enum LoginFormRules {
    enum Field: Hashable {
        case email, password
    }

    /// El email SÍ se recorta: un espacio al final —de un autocompletado o de
    /// un pegado— nunca es parte de una dirección, y sin recortarlo el acceso
    /// falla con un mensaje sobre las credenciales.
    static func email(from raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// La contraseña **no** se recorta, y es deliberado: puede empezar o acabar
    /// con un espacio, y alterar en silencio lo que alguien teclea rechazaría
    /// una contraseña correcta sin explicar por qué. Lo que se envía es lo que
    /// se escribió.
    static func password(from raw: String) -> String { raw }

    /// Los dos campos con algo que no sea espacios.
    ///
    /// **No se juzga si la dirección es válida.** Una expresión regular que
    /// rechace una dirección real deja a alguien fuera de su propia cuenta, y
    /// quien sabe si existe es el servidor.
    static func canSubmit(email: String, password: String) -> Bool {
        !Self.email(from: email).isEmpty
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// El campo siguiente, o `nil` si este es el último.
    static func nextField(after field: Field) -> Field? {
        field == .email ? .password : nil
    }

    /// Cuándo se puede volver a intentar, tras un límite de peticiones.
    ///
    /// El mensaje decía «Inténtelo de nuevo en 60 s» con el botón **habilitado**,
    /// así que invitaba a un reintento que iba a fallar y que reinicia la
    /// ventana. Con la cuenta atrás real, el botón no se puede pulsar hasta que
    /// el servidor vuelva a aceptar.
    ///
    /// Me ha mordido dos veces en la propia sesión de trabajo: lanzando muchos
    /// recorridos seguidos, el acceso empezaba a fallar y no había forma de
    /// distinguirlo de unas credenciales mal puestas.
    static func canSubmit(email: String, password: String, retryUntil: Date?, now: Date) -> Bool {
        guard canSubmit(email: email, password: password) else { return false }
        guard let retryUntil else { return true }
        return now >= retryUntil
    }

    /// Los segundos que faltan, o `nil` si ya se puede.
    ///
    /// Se redondea hacia ARRIBA: con 0,4 s restantes, decir «0 s» y no dejar
    /// pulsar es peor que decir «1 s».
    static func secondsRemaining(until retryUntil: Date?, now: Date) -> Int? {
        guard let retryUntil else { return nil }
        let restan = retryUntil.timeIntervalSince(now)
        guard restan > 0 else { return nil }
        return Int(restan.rounded(.up))
    }

    /// El rótulo del botón mientras hay que esperar.
    static func waitLabel(secondsRemaining: Int) -> String {
        secondsRemaining == 1
            ? "Espere 1 segundo"
            : "Espere \(secondsRemaining) segundos"
    }

    /// Si Return desde este campo debe enviar.
    ///
    /// Solo desde el último y solo con el formulario completo: pulsar Return con
    /// el email vacío gastaría uno de los cinco intentos por minuto en nada.
    static func submitsOnReturn(from field: Field, email: String, password: String) -> Bool {
        nextField(after: field) == nil && canSubmit(email: email, password: password)
    }
}
