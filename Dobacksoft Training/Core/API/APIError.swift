import Foundation

/// Errores estándar del APIClient. Mapean a la shape `{error, message}` del backend
/// `/api/v1/*` y los handlers JSON. La inconsistencia conocida de `@require_role`
/// (devuelve solo `{message}`) se tolera leyendo `message` siempre y `error` opcional.
enum APIError: Error, Sendable {
    case unauthenticated

    /// Un 401 que **no** es sobre la sesión.
    ///
    /// El backend usa 401 para dos cosas distintas: «tu token no vale» y «la
    /// credencial que acabas de escribir en el cuerpo no vale». Confundirlas
    /// costaba la sesión: escribir mal la contraseña actual daba 401,
    /// `AuthSession.authorized` refrescaba el token, reintentaba, recibía el
    /// mismo 401 —claro, la contraseña seguía siendo la misma— y cerraba la
    /// sesión con «Su sesión ha caducado por seguridad».
    ///
    /// Un aspirante que se equivoca al teclear acababa fuera de la aplicación
    /// con un mensaje que no describe lo que pasó. Encontrado ejecutando el
    /// endpoint contra staging, no leyendo el código: desde dentro, un 401 es
    /// un 401 en todas partes.
    case credentialRejected(CredentialRejection)
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
        case .credentialRejected(let rejection): return rejection.detail
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
/// Por qué el servidor rechazó una credencial del cuerpo, no la sesión.
///
/// La frase la escribe el cliente, como en `NotFoundReason`: el `message` del
/// backend puede estar pensado para el portal web o para quien lo programó, y
/// aquí lo lee un bombero.
nonisolated enum CredentialRejection: Sendable, Equatable {
    /// `wrong_current_password` — comprobado contra staging el 2026-09-10:
    /// `PATCH /api/v1/me/password` responde 401 con ese código.
    case wrongCurrentPassword

    /// El código del cuerpo, o `nil` si no es uno de los que conocemos.
    ///
    /// **Solo escapan los códigos conocidos**, y es deliberado: un 401 sin
    /// código, o con uno que nombra el token, sigue cerrando la sesión como
    /// siempre. Invertir el criterio dejaría a alguien con la sesión caducada
    /// mirando un error en vez de volver a entrar.
    init?(apiCode: String?) {
        switch apiCode {
        case "wrong_current_password": self = .wrongCurrentPassword
        default: return nil
        }
    }

    /// El rechazo que corresponde a esta respuesta, **sin mirar el estado**
    /// más allá de que sea un 4xx.
    ///
    /// Deliberadamente independiente del código HTTP. El backend devuelve hoy
    /// `401` para `wrong_current_password` por herencia de un endpoint anterior
    /// al API móvil, y va a pasar a `422`, que es lo coherente: las otras
    /// cuatro validaciones del cuerpo del mismo endpoint ya son 422 o 400, y
    /// un 403 diría «no tiene permiso» cuando el permiso lo tiene —el JWT es
    /// válido y es el dueño— y lo que no vale es un campo.
    ///
    /// Ramificar por estado obligaría a coordinar los dos despliegues. Leyendo
    /// la clave, el cambio del servidor es seguro en cualquier orden y sin
    /// avisar.
    ///
    /// Solo 4xx: un 500 con un cuerpo raro no es una credencial rechazada.
    static func forResponse(status: Int, body: APIErrorBody?) -> CredentialRejection? {
        guard (400...499).contains(status) else { return nil }
        return CredentialRejection(apiCode: body?.error)
    }

    var detail: String {
        switch self {
        case .wrongCurrentPassword:
            // Y dice que NO ha cambiado nada: sin esa mitad, alguien puede
            // quedarse sin saber con cuál de las dos entrar la próxima vez.
            return "La contraseña actual no es correcta. No se ha cambiado nada."
        }
    }
}

struct APIErrorBody: Sendable {
    let error: String?
    let message: String?
    let details: [String: [String]]?
    let reason: String?
}

nonisolated extension APIErrorBody: Decodable {}
