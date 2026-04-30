import Foundation

/// Errores estándar del APIClient. Mapean a la shape `{error, message}` del backend
/// `/api/v1/*` y los handlers JSON. La inconsistencia conocida de `@require_role`
/// (devuelve solo `{message}`) se tolera leyendo `message` siempre y `error` opcional.
enum APIError: Error, Sendable {
    case unauthenticated
    case forbidden
    case notFound
    case rateLimited(retryAfter: Int?)
    case validation(message: String, details: [String: [String]]?)
    case server(message: String, status: Int)
    case decoding(Error)
    case transport(Error)
    case unexpected(status: Int, body: String?)

    var userMessage: String {
        switch self {
        case .unauthenticated: return "Sesión expirada o credenciales inválidas."
        case .forbidden: return "No tenés permisos para esta sección."
        case .notFound: return "Recurso no encontrado."
        case .rateLimited(let retryAfter):
            if let s = retryAfter { return "Demasiadas peticiones. Probá en \(s)s." }
            return "Demasiadas peticiones. Probá más tarde."
        case .validation(let m, _): return m
        case .server(let m, _): return m
        case .decoding: return "Respuesta inesperada del servidor."
        case .transport: return "Error de conexión. Revisá tu red."
        case .unexpected(let s, _): return "Error inesperado (\(s))."
        }
    }
}

/// Shape genérica del cuerpo de error del backend. Todos los campos opcionales
/// para tolerar la divergencia conocida entre handlers del blueprint y `@require_role`.
struct APIErrorBody: Decodable, Sendable {
    let error: String?
    let message: String?
    let details: [String: [String]]?
    let reason: String?
}
