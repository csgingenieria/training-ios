import Foundation

/// Errores estándar del APIClient. Mapean a la shape `{error, message}` del backend
/// `/api/v1/*` y los handlers JSON. La inconsistencia conocida de `@require_role`
/// (devuelve solo `{message}`) se tolera leyendo `message` siempre y `error` opcional.
enum APIError: Error, Sendable {
    case unauthenticated
    case forbidden
    /// Con el motivo, cuando el backend lo distingue. Ver `NotFoundReason`.
    case notFound(NotFoundReason)
    case rateLimited(retryAfter: Int?)
    case validation(message: String, details: [String: [String]]?)
    case server(message: String, status: Int)
    case decoding(Error)
    case transport(Error)
    case unexpected(status: Int, body: String?)
    /// El build no tiene una `BASE_URL` utilizable. No es un fallo de red: no se
    /// llegó a emitir petición alguna.
    case configuration(String)

    /// Texto mostrado al usuario final.
    ///
    /// Castellano formal peninsular: lo lee un bombero de la Comunidad de
    /// Madrid. Nada de voseo, aunque el equipo hable así entre nosotros.
    var userMessage: String {
        switch self {
        case .unauthenticated: return "La sesión ha caducado. Vuelva a iniciar sesión."
        case .forbidden: return "No dispone de permisos para acceder a esta sección."
        case .notFound(let reason): return reason.detail
        case .rateLimited(let retryAfter):
            if let s = retryAfter { return "Demasiadas peticiones. Inténtelo de nuevo en \(s) s." }
            return "Demasiadas peticiones. Inténtelo de nuevo más tarde."
        case .validation:
            // Frase fija, no el mensaje del backend. Un 422 puede traer texto
            // pensado para un desarrollador o para el portal web, y el
            // aspirante necesita saber qué HACER.
            return "No se ha podido procesar la petición. Inténtelo de nuevo."
        case .server:
            // Un 502 de nginx daba el fragmento «Error del servidor» bajo un
            // título «Error», y nada decía si esperar o reintentar. Esto sí, y
            // nombra la salida que existe: avisar al instructor.
            return "El servidor no está disponible en este momento. "
                + "Inténtelo de nuevo en unos minutos; si el problema continúa, avise a su instructor."
        case .decoding:
            return "La respuesta del servidor no tiene el formato esperado."
        case .transport:
            return "No se ha podido conectar. Compruebe su conexión a la red."
        case .unexpected:
            // **Sin el código HTTP.** Un «(418)» no le dice nada a un bombero y
            // le pide leer un número que no puede usar. El estado y el cuerpo
            // se registran por `AppLog.api`, que es donde sirven.
            return "Se ha producido un error inesperado. Inténtelo de nuevo."
        case .configuration: return "La aplicación no está configurada correctamente. Avise al soporte técnico."
        }
    }
}

extension APIError {
    /// El motivo del 404, o `nil` si este error no es un 404.
    var notFoundReason: NotFoundReason? {
        if case let .notFound(reason) = self { return reason }
        return nil
    }
}

/// Shape genérica del cuerpo de error del backend. Todos los campos opcionales
/// para tolerar la divergencia conocida entre handlers del blueprint y `@require_role`.
struct APIErrorBody: Sendable {
    let error: String?
    let message: String?
    let details: [String: [String]]?
    let reason: String?
}

nonisolated extension APIErrorBody: Decodable {}
