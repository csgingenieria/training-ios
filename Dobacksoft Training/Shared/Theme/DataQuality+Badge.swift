import SwiftUI

/// Presentación de `DataQuality`. Vive junto al design system, no en el modelo:
/// el dominio sabe qué calidad tiene un intento, no de qué color se pinta.
extension DataQuality {
    var badgeKind: BadgeKind {
        switch self {
        case .high:   .success
        case .medium: .warning
        case .low:    .danger
        }
    }
}
