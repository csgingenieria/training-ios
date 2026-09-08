import Foundation

/// La ruta de `GET /api/v1/me/routes/<code>`, con o sin convocatoria.
///
/// Misma disciplina que `ProgressQuery`, y por la misma razón: **`?conv_id=`
/// vacío da 400** porque el servicio del portal gatea el filtro con un `if`, y
/// una cadena vacía caería al respaldo y contestaría por otra convocatoria con
/// aspecto de respuesta correcta. Así que el parámetro se OMITE.
///
/// Vive fuera del `APIClient` para poder probarlo: es un error del que sin test
/// nadie se vuelve a acordar.
nonisolated enum RouteQuery {
    static func path(code: String, convocatoriaId: String?) -> String {
        // El código va percent-encoded: son códigos del catálogo («2A1») pero
        // nada del contrato promete que no lleven un carácter que rompa la URL.
        let codificado = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        let base = "/api/v1/me/routes/\(codificado)"
        guard let convocatoriaId,
              !convocatoriaId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return base }
        return "\(base)?conv_id=\(convocatoriaId)"
    }
}
