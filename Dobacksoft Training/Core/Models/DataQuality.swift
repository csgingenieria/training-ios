import Foundation

/// Calidad de los datos capturados durante un intento.
///
/// El backend la deriva en `_data_quality_label` y devuelve exactamente tres
/// valores: `HIGH`, `MEDIUM` y `LOW`. Cualquier otra cosa —campo ausente, cadena
/// vacía, valor desconocido— significa «sin clasificar», y entonces no se pinta
/// insignia: inventar una etiqueta sería afirmar algo que el backend no dijo.
enum DataQuality: String, Sendable, CaseIterable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"

    /// Tolera espacios y diferencias de caja; devuelve `nil` si no reconoce el valor.
    ///
    /// Etiqueta propia en vez de sobrecargar `init?(rawValue:)`: `String` se
    /// promociona a `String?`, así que la sobrecarga se llamaría a sí misma.
    init?(apiValue: String?) {
        guard let apiValue else { return nil }
        let normalised = apiValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let match = DataQuality(rawValue: normalised) else { return nil }
        self = match
    }

    /// Texto mostrado al usuario final. Castellano formal: lo lee un bombero.
    var label: String {
        switch self {
        case .high:   "Calidad alta"
        case .medium: "Calidad media"
        case .low:    "Calidad baja"
        }
    }
}
