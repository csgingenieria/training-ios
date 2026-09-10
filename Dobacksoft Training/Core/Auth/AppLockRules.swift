import Foundation

/// Qué puede hacer este dispositivo para comprobar que quien mira es su dueño.
///
/// `.deviceOwnerAuthentication` cae al código del dispositivo cuando no hay
/// biometría inscrita, así que «sin Face ID» **no** es «no se puede»: lo único
/// que no se puede es un dispositivo sin código.
nonisolated enum BiometryCapability: Sendable, Equatable {
    case faceID
    case touchID

    /// Sin biometría inscrita, pero con código: la política sí evalúa.
    case passcodeOnly

    /// El dispositivo no puede evaluar la política. En la práctica: sin código.
    case unavailable
}

/// Cuándo se pide, cuándo se puede activar y qué pasa cuando falla.
///
/// **El ajuste es una conveniencia opt-in, y una conveniencia no puede dejar a
/// nadie fuera de su propia cuenta.** Es la línea que separa esto de un
/// candado: el cliente final son bomberos aspirantes que no tienen a quién
/// preguntarle, y una app que se niega a abrirse por un ajuste que activaron
/// hace un mes es un incidente, no una medida de seguridad.
nonisolated enum AppLockRules {
    /// La gracia al volver al frente.
    ///
    /// Pedirlo en CADA vuelta al frente hace la app inusable: mirar una
    /// notificación y volver ya obligaría a autenticarse. Un minuto es
    /// suficiente para atender algo y volver, y corto para un teléfono que
    /// cambió de manos.
    ///
    /// **No se reutiliza el número de `RefreshTicker.staleAfter`** (300 s) por
    /// mucho que quede a mano: ese mide cuándo una cifra deja de ser fresca, y
    /// este cuándo el teléfono pudo cambiar de manos. Compartir la constante
    /// ataría dos decisiones que no tienen nada que ver, y el día que una
    /// cambie arrastraría a la otra sin que nadie lo pidiera.
    static let grace: TimeInterval = 60

    /// Si hay que pedir la autenticación ahora.
    ///
    /// - `leftForegroundAt == nil` es el arranque en frío: se pide siempre.
    /// - Con la sesión cerrada **no** se pide: no hay nada que tapar, y un
    ///   candado sobre la pantalla de acceso no protege un dato, solo impide
    ///   entrar.
    static func shouldAsk(
        enabled: Bool,
        authenticated: Bool,
        leftForegroundAt: Date?,
        now: Date
    ) -> Bool {
        guard enabled, authenticated else { return false }
        guard let leftForegroundAt else { return true }

        // Reloj hacia atrás: se PIDE.
        //
        // Un dispositivo con la hora movida hacia atrás daría una diferencia
        // negativa, y tratarla como «hace poco» convertiría el reloj en la
        // forma de no volver a autenticarse nunca.
        guard now >= leftForegroundAt else { return true }

        return now.timeIntervalSince(leftForegroundAt) >= grace
    }

    /// Si el ajuste se puede encender en este dispositivo.
    ///
    /// **Un interruptor que se enciende y no protege nada es peor que no
    /// tenerlo**: deja a alguien creyendo que su puesto y su nota están detrás
    /// de una comprobación que nunca ocurre.
    static func mayEnable(_ capability: BiometryCapability) -> Bool {
        capability != .unavailable
    }

    /// Por qué no se puede encender, en palabras y con la salida.
    ///
    /// `nil` cuando sí se puede. Un rechazo sin el paso siguiente deja a quien
    /// lo lee sin nada que hacer.
    static func enablementRefusal(_ capability: BiometryCapability) -> String? {
        guard capability == .unavailable else { return nil }
        return "Este dispositivo no tiene código de desbloqueo, así que la aplicación no puede pedirlo. Configure un código en los Ajustes del dispositivo y vuelva a intentarlo."
    }

    /// Si el ajuste debe apagarse solo porque el dispositivo ya no puede.
    ///
    /// El código se puede quitar DESPUÉS de encender el ajuste. Mantenerlo
    /// encendido entonces dejaría la app pidiendo algo que no se puede dar:
    /// una pantalla bloqueada sin forma de desbloquearla, por una conveniencia.
    /// Se abre y se apaga el ajuste diciéndolo.
    static func shouldTurnOffAfterLosingCapability(_ capability: BiometryCapability) -> Bool {
        capability == .unavailable
    }

    /// Lo que se le dice a quien encuentra el ajuste apagado solo.
    static let turnedOffBecauseTheDeviceCannot =
        "El bloqueo se ha desactivado porque este dispositivo ya no tiene código de desbloqueo."

    /// El motivo que ve el sistema en el diálogo de Face ID.
    ///
    /// Lo lee la persona en el diálogo del sistema, así que dice QUÉ protege y
    /// no «autentíquese»: la frase del sistema es la única explicación que hay
    /// en ese momento.
    static let reason = "Para mostrar su puesto y su nota."

    /// Qué se ofrece cuando la comprobación no sale.
    ///
    /// Reintentar, **y cerrar sesión**. Sin la segunda, alguien que no puede
    /// autenticarse —el sensor sucio, un código que no recuerda en ese
    /// momento— se queda encerrado en una pantalla sin nada que pulsar, con su
    /// sesión dentro y sin manera de salir.
    enum Exit: Sendable, Hashable, CaseIterable {
        case retry
        case signOut
    }

    static let exitsAfterFailure: [Exit] = [.retry, .signOut]
}
