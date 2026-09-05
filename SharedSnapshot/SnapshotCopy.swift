import Foundation

/// Todos los textos de la vista rápida, en un solo sitio.
///
/// Compartidos entre la app y el widget a propósito: repartidos por las vistas,
/// cada superficie acaba diciendo una cosa distinta del mismo estado, y una de
/// ellas termina afirmando algo que no es cierto.
///
/// Castellano formal peninsular: lo lee un bombero de la Comunidad de Madrid.
///
/// **Regla que gobierna todos estos textos**: ninguno afirma un dato que no se
/// tiene. Cuando no hay dato se dice que no lo hay — nunca un cero, nunca un
/// guion en lugar de una cifra, nunca «te falta» nada.
enum SnapshotCopy {
    static let widgetName = "Mi posición"

    static let widgetDescription =
        "Su puesto y su nota en la convocatoria seleccionada, según la última consulta realizada desde la aplicación."

    // MARK: - Estados sin dato

    /// Contenedor legible y sin instantánea: no hay sesión. **Único** caso que
    /// puede decir esto.
    static let sinSesion = "Inicie sesión en la aplicación."

    /// No se pudo leer. Nunca se traduce como «inicie sesión»: un fallo de
    /// firma o de protección de datos no es un hecho sobre la cuenta de nadie.
    static let ilegibleCorto = "No hay datos disponibles."
    static let ilegibleLargo =
        "No hay datos disponibles. No ha sido posible consultarlos en este dispositivo. Abra la aplicación."

    static let desactivado =
        "Vista rápida desactivada. Puede activarla en su perfil, dentro de la aplicación."

    static let sinPosicionPropia =
        "Sin posición propia. Este resumen solo está disponible para los aspirantes."

    static let sinDatosAun =
        "Sin datos todavía. Abra «Mi posición» en la aplicación para obtenerlos."

    static let sinConvocatoria = "Sin convocatorias. No consta ninguna inscripción."

    static let sinPosicionTitulo = "Todavía sin posición"
    static let sinPosicionDetalle =
        "Su posición aparecerá cuando se registre el primer recorrido calificado."

    static func sinPosicionEn(_ convocatoria: String) -> String {
        "Todavía sin posición en \(convocatoria). \(sinPosicionDetalle)"
    }

    /// Más de 48 horas: se retiran las cifras.
    static let caducado = "Sin datos recientes. Abra la aplicación para actualizarlos."

    static let notaNoDisponible = "Nota no disponible."

    // MARK: - Rótulos con dato

    static let notaProvisional = "Nota provisional"
    static let nota = "Nota"

    static let notaProvisionalDetalle =
        "La convocatoria sigue abierta: esta nota puede variar hasta su cierre."

    /// Acompaña a las cifras cuando el dato tiene entre 6 y 48 horas.
    static func consultadoEl(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM 'a las' HH:mm"
        return "Consultado el \(formatter.string(from: date))."
    }

    // MARK: - Accesibilidad

    /// El sistema ha ocultado el contenido por tener el dispositivo bloqueado.
    /// VoiceOver no puede leer lo que la pantalla oculta.
    static let redactado = "Mi posición. Contenido oculto. Desbloquee el dispositivo para verlo."

    // MARK: - Reloj (primera entrega: sin integrar, solo dejando de mentir)

    static let relojSinDatosPosicion =
        "Sin datos en el reloj. Consulte su posición en la aplicación del iPhone."

    static let relojSinDatosIntentos =
        "Sin intentos en el reloj. Consulte sus recorridos en la aplicación del iPhone."
}
