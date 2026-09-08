import Foundation

/// La ruta de `GET /api/v1/me/progress`, con o sin convocatoria.
///
/// Vive fuera del `APIClient` para poder probarla: el parámetro vacío es un
/// error del que el backend avisa por escrito y que sin test nadie vuelve a
/// mirar.
///
/// **`?conv_id=` vacío devuelve 400, y es deliberado.** El servicio del portal
/// gatea el filtro con un `if` de verdad, así que una cadena vacía caería al
/// respaldo y el aspirante leería la nota de OTRA convocatoria con aspecto de
/// respuesta correcta. Por eso el parámetro se OMITE en vez de mandarse vacío:
/// sin convocatoria, que el backend elija su inscripción activa es lo correcto;
/// mandarle una cadena vacía es pedirle que adivine.
nonisolated enum ProgressQuery {
    static func path(convocatoriaId: String?) -> String {
        let base = "/api/v1/me/progress"
        guard let convocatoriaId,
              !convocatoriaId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return base }
        return "\(base)?conv_id=\(convocatoriaId)"
    }
}
