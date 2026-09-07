import Foundation

/// Traduce las fechas del backend a algo legible.
///
/// La API entrega ISO-8601 en UTC (`_iso` en su capa de servicios) y los DTOs
/// las guardan como `String` sin parsear. Cinco pantallas las pintaban en
/// crudo, así que un bombero leía `2026-09-03T14:22:11Z` donde el portal web
/// dice `03/09/2026 16:22`.
///
/// Todo se muestra en **hora de Madrid**, que es donde ocurre el examen. El
/// backend usa ese mismo huso para sus cortes de día y semana.
enum APIDate {
    /// Huso del examen. No usar la zona del dispositivo: un instructor de viaje
    /// vería horas que no casan con las del acta ni con las del portal.
    static let timeZone = TimeZone(identifier: "Europe/Madrid") ?? .gmt

    private static let locale = Locale(identifier: "es_ES")

    /// El backend emite fracciones de segundo en unos endpoints y no en otros,
    /// así que hacen falta las dos estrategias.
    private static let parsers: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [plain, withFraction]
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static let shortDateTimeFormatter = formatter("dd/MM/yyyy HH:mm")
    private static let shortDateFormatter = formatter("dd/MM/yyyy")
    private static let longDateTimeFormatter = formatter("d 'de' MMMM 'a las' HH:mm")
    private static let timeFormatter = formatter("HH:mm")

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter
    }()

    /// Convierte la cadena del backend en fecha. `nil` si no se reconoce: es
    /// preferible no mostrar nada a mostrar una cadena rota.
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        for parser in parsers {
            if let date = parser.date(from: value) { return date }
        }
        return nil
    }

    /// `03/09/2026 16:22`
    static func shortDateTime(_ value: String?) -> String? {
        parse(value).map(shortDateTimeFormatter.string(from:))
    }

    static func shortDateTime(_ date: Date) -> String {
        shortDateTimeFormatter.string(from: date)
    }

    /// `03/09/2026`
    static func shortDate(_ value: String?) -> String? {
        parse(value).map(shortDateFormatter.string(from:))
    }

    /// `16:22` — solo la hora.
    ///
    /// Para «Actualizado a las …», donde la fecha sobra: el dato se leyó en
    /// esta misma sesión. Y estorba, porque un `03/09/2026 16:22` debajo de
    /// una nota se lee como la fecha DEL intento, que es otro dato y más
    /// importante.
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// `3 de septiembre a las 16:22`
    static func longDateTime(_ date: Date) -> String {
        longDateTimeFormatter.string(from: date)
    }

    static func longDateTime(_ value: String?) -> String? {
        parse(value).map(longDateTimeFormatter.string(from:))
    }

    /// Texto de instante para pintar tal cual.
    ///
    /// La API **no es homogénea**: la mayoría de campos llegan en ISO-8601 UTC,
    /// pero los eventos de un intento traen la hora YA FORMATEADA en Madrid
    /// (`%H:%M:%S` desde `_hora_madrid`), porque el backend la compuso en
    /// Python. Pasarles un parser de ISO devuelve `nil` y la hora desaparece
    /// de la pantalla.
    ///
    /// Así que: si parsea como ISO, se formatea; si no, se devuelve lo que vino
    /// —que ya es legible— y solo se descarta el marcador de ausencia.
    static func displayInstant(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "—", trimmed != "-" else { return nil }
        return shortDateTime(trimmed) ?? trimmed
    }

    /// `hace 5 minutos`. Para listas de actividad, donde importa lo reciente
    /// que es algo más que el instante exacto.
    static func relative(from date: Date, to reference: Date = Date()) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: reference)
    }

    static func relative(_ value: String?, to reference: Date = Date()) -> String? {
        parse(value).map { relative(from: $0, to: reference) }
    }
}
