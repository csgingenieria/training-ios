import Foundation

/// De qué campo se queja el decodificador, sin decir qué venía dentro.
///
/// Un fallo de decodificación era indiagnosticable: la pantalla decía «La
/// respuesta del servidor no tiene el formato esperado» —que es lo correcto
/// para el aspirante— y no quedaba rastro de QUÉ campo lo rompió. Con seis
/// endpoints nuevos y respuestas que cambian, eso significa no poder arreglarlo.
///
/// **Se registra la RUTA y la clase de fallo, nunca la descripción completa.**
/// `dataCorrupted` puede llevar dentro el valor recibido, y esto va a un log de
/// un dispositivo con datos de CMadrid bajo NDA. Un nombre de campo no
/// identifica a nadie; el valor de ese campo, sí.
nonisolated enum DecodingFailure {
    /// Algo como `attempt.events[3].timestamp — valor esperado ausente`.
    static func summary(_ error: Error) -> String {
        guard let error = error as? DecodingError else {
            return "no es un DecodingError: \(type(of: error))"
        }

        switch error {
        case let .keyNotFound(key, context):
            return "\(path(context, adding: key.stringValue)) — falta la clave"
        case let .valueNotFound(type, context):
            return "\(path(context)) — nulo donde se espera \(type)"
        case let .typeMismatch(type, context):
            return "\(path(context)) — no es \(type)"
        case let .dataCorrupted(context):
            // Sin `debugDescription`: es el único caso que puede citar el valor.
            return "\(path(context)) — dato ilegible"
        @unknown default:
            return "clase de fallo desconocida"
        }
    }

    private static func path(_ context: DecodingError.Context, adding key: String? = nil) -> String {
        var partes = context.codingPath.map(\.stringValue)
        if let key { partes.append(key) }
        return partes.isEmpty ? "(raíz)" : partes.joined(separator: ".")
    }
}
