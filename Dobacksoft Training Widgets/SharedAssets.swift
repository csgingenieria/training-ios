import SwiftUI

// Theme/DTOs/MockData reducidos para el Widget target.
//
// Por qué duplicado y no shared: este target es una Widget Extension que vive
// en una synced root group propia (PBXFileSystemSynchronizedRootGroup). Compartir
// código con el target principal requeriría un Swift Package + reconfig en
// Xcode UI (capability, framework search paths). Para V1 mantenemos esta
// "thin copy" con solo lo mínimo. Si crece, migrar a Swift Package.

// MARK: - Color tokens (subset del Theme principal)
//
// Mapean a los mismos assets de color del target principal. PERO el Widget
// no comparte Assets.xcassets, así que los definimos como literales aquí.
// Si actualizás el Theme principal, actualizá esto también — fuente única en
// /Users/antoniohermoso/repos/training/app/static/css/tokens.css.

extension Color {
    static let widgetPaper        = Color(red: 0xFC/255, green: 0xFB/255, blue: 0xF8/255)
    static let widgetInk          = Color(red: 0x0C/255, green: 0x0A/255, blue: 0x09/255)
    static let widgetMuted        = Color(red: 0x57/255, green: 0x53/255, blue: 0x4E/255)
    static let widgetBrand        = Color(red: 0x1E/255, green: 0x3A/255, blue: 0x8A/255)
    static let widgetBrandTint    = Color(red: 0xEE/255, green: 0xF2/255, blue: 0xFF/255)
    static let widgetSuccess      = Color(red: 0x15/255, green: 0x80/255, blue: 0x3D/255)
    static let widgetDanger       = Color(red: 0xB9/255, green: 0x1C/255, blue: 0x1C/255)
}

// MARK: - Mock data (V1 sin App Groups)
//
// V1: el widget muestra datos PLACEHOLDER porque no tiene acceso al token JWT
// del usuario (vive en Keychain del target principal). Para V2:
//   1. Activar capability "App Groups" en target principal Y en widget.
//   2. Crear App Group `group.com.dobacksoft.training`.
//   3. Refactor TokenStore para usar `kSecAttrAccessGroup` apuntando al group.
//   4. Acá, leer token del Keychain compartido y hacer requests reales.
// Hoy V1 muestra el diseño/arquitectura sin datos reales.

struct WidgetStandingMock {
    let convocatoriaName: String
    let position: Int
    let totalCandidates: Int
    let plazas: Int
    let score: Double
    let attemptsCompleted: Int
    let attemptsTotal: Int

    var withinCutoff: Bool { position <= plazas }

    static let sample = WidgetStandingMock(
        convocatoriaName: "Convocatoria 2026",
        position: 5,
        totalCandidates: 42,
        plazas: 50,
        score: 8.25,
        attemptsCompleted: 5,
        attemptsTotal: 6
    )

    static let outsideCutoff = WidgetStandingMock(
        convocatoriaName: "Convocatoria 2026",
        position: 58,
        totalCandidates: 60,
        plazas: 50,
        score: 5.10,
        attemptsCompleted: 4,
        attemptsTotal: 6
    )
}
