import SwiftUI

// Tokens de color del widget.
//
// Copia mínima y deliberada de la paleta. El modelo (`StandingSnapshot`,
// `SnapshotFreshness`, `SnapshotStore`, `SnapshotCopy`) NO se duplica: el
// widget compila esos ficheros del target principal por pertenencia adicional,
// así que hay una sola definición de cada uno en el repositorio.

extension Color {
    static let widgetPaper        = Color(red: 0xFC/255, green: 0xFB/255, blue: 0xF8/255)
    static let widgetInk          = Color(red: 0x0C/255, green: 0x0A/255, blue: 0x09/255)
    static let widgetMuted        = Color(red: 0x57/255, green: 0x53/255, blue: 0x4E/255)
    static let widgetBrand        = Color(red: 0x1E/255, green: 0x3A/255, blue: 0x8A/255)
    static let widgetBrandTint    = Color(red: 0xEE/255, green: 0xF2/255, blue: 0xFF/255)
    static let widgetSuccess      = Color(red: 0x15/255, green: 0x80/255, blue: 0x3D/255)
    static let widgetDanger       = Color(red: 0xB9/255, green: 0x1C/255, blue: 0x1C/255)
}
