import Foundation

/// `GET /api/v1/me/pin` — el PIN de tablet del propio aspirante.
///
/// Existe para que nadie dependa de que otro se lo dicte.
///
/// ⚠ **Leerlo no es gratis**: el backend audita cada consulta
/// (`KIOSK_PIN_VIEWED`), también cuando el PIN no se puede mostrar. El PIN, con
/// el número de inscripción, permite conducir en nombre de otro — así que la
/// pantalla no lo pide de fondo ni lo refresca sola: se abre cuando la persona
/// entra a verlo.
nonisolated struct PinDTO: Sendable {
    /// El PIN, o `nil`.
    ///
    /// **`nil` significa dos cosas que para quien llama son la misma**: que no
    /// tiene PIN, o que la clave de cifrado no está disponible. En los dos
    /// casos la pantalla dice «no se puede mostrar» — y en ninguno de los dos
    /// dice que no pueda conducir, porque el hash es lo que valida el acceso y
    /// sigue funcionando.
    let pin: String?

    /// Con qué número de inscripción va cada convocatoria.
    ///
    /// Va con el PIN porque **la tablet pide las dos cosas**: el PIN solo no
    /// abre nada. La web pasa esta lista como `plazas=`; ese nombre no se copia
    /// al JSON — es vocabulario de cupo, prohibido por el artículo 22.
    let activeEnrollments: [ProgressEnrollmentDTO]

    /// Si hay un PIN que enseñar.
    var canBeShown: Bool { pin != nil }

    /// Si no poder mostrarlo impide conducir. **Nunca.**
    ///
    /// Existe como propiedad y no como comentario porque es la afirmación que
    /// la pantalla NO debe hacer, y tenerla escrita evita que alguien la derive
    /// de `canBeShown` por descuido.
    var blocksDriving: Bool { false }

    /// Si la pantalla tiene lo que la tablet va a pedir.
    ///
    /// Las dos cosas: el PIN y al menos un número de inscripción. Con una sola
    /// el aspirante se queda a medias delante del camión.
    var isReadyForTheTablet: Bool {
        canBeShown && activeEnrollments.contains { $0.plaza != nil }
    }
}

nonisolated extension PinDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            // El centinela otra vez: un PIN que no se puede mostrar puede
            // llegar como «—» en vez de como `null`. Es la misma ausencia.
            pin: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .pin)),
            activeEnrollments: try c.decodeIfPresent([ProgressEnrollmentDTO].self, forKey: .activeEnrollments) ?? []
        )
    }

    private enum CodingKeys: String, CodingKey { case pin, activeEnrollments }
}

/// Lo que dice la pantalla del PIN.
nonisolated enum PinCopy {
    /// Por qué están los dos números en pantalla.
    static let tabletNeedsBoth =
        "La tablet le pedirá su PIN y el número de inscripción de la convocatoria."

    /// No se puede mostrar. **Sin decir que no pueda conducir**: el acceso lo
    /// valida el hash, que sigue funcionando, y la lectura contraria mandaría a
    /// alguien a casa por un problema de visualización.
    static let unavailable =
        "Su PIN no se puede mostrar en este momento. Podrá conducir igual; si la tablet no lo acepta, avise a su instructor."

    /// Por qué no se comparte. Descriptivo, sin dramatizar: es la consecuencia
    /// real y el aspirante tiene derecho a saberla.
    static let keepItPrivate =
        "No comparta estos datos: con el PIN y el número de inscripción se puede conducir en su nombre."
}
