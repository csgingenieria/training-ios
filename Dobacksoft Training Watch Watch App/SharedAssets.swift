import SwiftUI

// Tokens de color del reloj.
//
// Este target no comparte código con el principal: tiene su propio grupo
// sincronizado y, sobre todo, corre en OTRO dispositivo. Copia mínima y
// deliberada de la paleta; el resto no se duplica.

extension Color {
    static let watchPaper        = Color(red: 0xFC/255, green: 0xFB/255, blue: 0xF8/255)
    static let watchInk          = Color(red: 0x0C/255, green: 0x0A/255, blue: 0x09/255)
    static let watchMuted        = Color(red: 0x57/255, green: 0x53/255, blue: 0x4E/255)
    static let watchBrand        = Color(red: 0x1E/255, green: 0x3A/255, blue: 0x8A/255)
    static let watchBrandTint    = Color(red: 0xEE/255, green: 0xF2/255, blue: 0xFF/255)
    static let watchSuccess      = Color(red: 0x15/255, green: 0x80/255, blue: 0x3D/255)
    static let watchWarning      = Color(red: 0xB4/255, green: 0x53/255, blue: 0x09/255)
    static let watchDanger       = Color(red: 0xB9/255, green: 0x1C/255, blue: 0x1C/255)
}

/// Textos del reloj. Copia local de los de `SnapshotCopy`, porque este target
/// no puede compartir código con la app: corre en otro dispositivo.
///
/// Castellano formal peninsular. Ninguno afirma un dato que el reloj no tiene.
enum WatchCopy {
    static let sinDatosPosicion =
        "Sin datos en el reloj. Consulte su posición en la aplicación del iPhone."

    static let sinDatosIntentos =
        "Sin intentos en el reloj. Consulte sus recorridos en la aplicación del iPhone."
}
