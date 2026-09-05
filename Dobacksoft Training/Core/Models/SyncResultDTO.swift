import Foundation

/// Resultado de `POST /api/v1/me/webfleet/sync`.
///
/// `ftp` y `webfleet` son dicts planos de contadores construidos por el backend
/// (`remap_sync_result`). Sus claves no están fijadas en el schema y pueden
/// evolucionar — los iteramos genéricamente en la UI sin asumir nombres.
///
/// Política del endpoint:
/// - Rate limit 3/min. 429 → mostrar "demasiados intentos" sin reintentar auto.
/// - Síncrono (capa 20 attempts en backend), responde 200 inline.
/// - NO decide APTO/NO_APTO (GDPR art. 22 intacto).
struct SyncResultDTO: Sendable {
    let ok: Bool
    let ftp: [String: SyncCounter]
    let webfleet: [String: SyncCounter]
}

nonisolated extension SyncResultDTO: Decodable {}

/// Valor de un contador del resultado de sync. El backend usa enteros para la
/// mayoría de claves pero puede meter strings (mensajes) en el mismo dict.
/// Decodificamos defensivamente para no fallar si aparece algo inesperado.
enum SyncCounter: Sendable, Hashable {
    case int(Int)
    case string(String)
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) { self = .int(i); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let d = try? container.decode(Double.self) { self = .int(Int(d)); return }
        self = .unknown
    }

    var display: String {
        switch self {
        case .int(let i):    return "\(i)"
        case .string(let s): return s
        case .unknown:       return "—"
        }
    }
}

nonisolated extension SyncCounter: Decodable {}
