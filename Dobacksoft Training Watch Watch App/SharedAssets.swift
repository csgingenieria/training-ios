import SwiftUI

// Theme/mock-data reducido para el Watch target.
//
// Igual que en el Widget: este target tiene su propia synced root group y no
// comparte código con el target principal automáticamente. Para V1 mantenemos
// "thin copy" de lo mínimo. Migrar a Swift Package si crece.

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

// MARK: - Mock data (V1)
//
// V2 requiere: WatchConnectivity para sincronizar token desde el iPhone,
// O App Groups + Keychain compartido + APIClient propio del Watch.
// V1 muestra el diseño con datos placeholder claros.

struct WatchStandingMock {
    let convocatoriaName: String
    let position: Int
    let totalCandidates: Int
    let plazas: Int
    let score: Double
    let attemptsCompleted: Int
    let attemptsTotal: Int
    let status: String

    var withinCutoff: Bool { position <= plazas }

    static let sample = WatchStandingMock(
        convocatoriaName: "Convocatoria 2026",
        position: 5,
        totalCandidates: 42,
        plazas: 50,
        score: 8.25,
        attemptsCompleted: 5,
        attemptsTotal: 6,
        status: "ACTIVE"
    )
}

struct WatchAttemptMock: Identifiable {
    let id: String
    let routeLabel: String
    let score: Double?
    let date: String

    static let samples: [WatchAttemptMock] = [
        WatchAttemptMock(id: "1", routeLabel: "Recorrido A", score: 8.20, date: "Hoy 09:15"),
        WatchAttemptMock(id: "2", routeLabel: "Recorrido B", score: 6.80, date: "Ayer 14:00"),
        WatchAttemptMock(id: "3", routeLabel: "Recorrido A", score: nil, date: "Lun 11:30"),
    ]
}
