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

// El semáforo de nota se retiró deliberadamente.
//
// Colorear la nota con frontera en 5 (rojo debajo, verde encima) dibuja un
// veredicto APTO / NO APTO que el sistema declara no emitir: RGPD art. 22, y
// `CMADRID-ENTREGA.md` v1.1 se lo dice al cliente por escrito. El propio
// backend eliminó esa misma frontera de su panel por este motivo.
//
// Y con el régimen de rutas exigidas el umbral es doblemente falso: un 4,75
// puede ser la media de cinco recorridos conducidos entre 8,5 y 10 más cinco
// que el tribunal nunca hizo conducibles. Ese rojo no describiría la
// conducción del aspirante, sino la configuración del examen.
//
// No reintroducir un `scoreColor` aquí ni en ninguna otra superficie.
