import SwiftUI

/// Las fuentes del producto, compartidas con el widget.
///
/// El número del puesto —lo que el aspirante mira de un vistazo— era Fraunces
/// dentro de la app y SF Rounded en la pantalla de inicio: la misma cifra con
/// dos caras según dónde la mirara.
///
/// Vive aquí porque los `.ttf` viven ahora en `SharedSnapshot/Fonts/`, que los
/// dos targets copian a su bundle, y porque una extensión no puede usar las
/// factorías del target de la app.
///
/// **Solo las factorías.** Los roles semánticos —`appTitle`, `heroNumber`— se
/// quedan en el target de la app: el widget no tiene sus tamaños ni debería,
/// porque lo suyo lo manda `WidgetFamily`.

nonisolated private enum SharedFontName {
    static let displayRegular     = "Fraunces72pt-Regular"
    static let displayItalic      = "Fraunces72pt-Italic"
    static let displayBold        = "Fraunces72pt-Bold"
    static let displayBoldItalic  = "Fraunces72pt-BoldItalic"

    static let bodyRegular        = "Inter-Regular"
    static let bodyMedium         = "Inter-Medium"
    static let bodySemiBold       = "Inter-SemiBold"
    static let bodyBold           = "Inter-Bold"
}

nonisolated extension Font {
    // MARK: - Acceso directo

    static func display(
        size: CGFloat,
        weight: Weight = .regular,
        italic: Bool = true,
        relativeTo style: TextStyle = .body
    ) -> Font {
        let name: String
        switch (weight, italic) {
        case (.bold, true), (.semibold, true), (.heavy, true), (.black, true):
            name = SharedFontName.displayBoldItalic
        case (.bold, false), (.semibold, false), (.heavy, false), (.black, false):
            name = SharedFontName.displayBold
        case (_, true):
            name = SharedFontName.displayItalic
        case (_, false):
            name = SharedFontName.displayRegular
        }
        return .custom(name, size: size, relativeTo: style)
    }

    static func body(
        size: CGFloat,
        weight: Weight = .regular,
        relativeTo style: TextStyle = .body
    ) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:
            name = SharedFontName.bodyBold
        case .semibold:
            name = SharedFontName.bodySemiBold
        case .medium:
            name = SharedFontName.bodyMedium
        default:
            name = SharedFontName.bodyRegular
        }
        return .custom(name, size: size, relativeTo: style)
    }
}
