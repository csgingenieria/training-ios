import SwiftUI

// Tipografía del design system.
//
// Familias (PostScript names, registrados via UIAppFonts en Info.plist):
//   - Fraunces72pt-Regular / -Italic / -Bold / -BoldItalic (display)
//   - Inter-Regular / -Medium / -SemiBold / -Bold (body/UI)
//
// Dynamic Type:
//   Cada rol semántico se construye con `relativeTo:` de un text style del sistema,
//   para que el accessibility setting "Larger Text" escale la app correctamente.
//
// API:
//   .font(.appTitle)            → Fraunces italic grande, hero.
//   .font(.sectionTitle)        → Inter SemiBold para títulos de sección.
//   .font(.cardTitle)           → Inter SemiBold para títulos de card.
//   .font(.bodyText)            → Inter Regular para body.
//   .font(.bodyEmphasis)        → Inter Medium para destacar en body.
//   .font(.metaCaption)         → Inter Regular pequeña para metadatos.
//   .font(.heroNumber)          → Fraunces Bold grande, para "32" en standing.
//   .font(.display(size:weight:italic:relativeTo:)) → acceso directo a Fraunces.
//   .font(.body(size:weight:relativeTo:))           → acceso directo a Inter.

private enum FontName {
    static let displayRegular     = "Fraunces72pt-Regular"
    static let displayItalic      = "Fraunces72pt-Italic"
    static let displayBold        = "Fraunces72pt-Bold"
    static let displayBoldItalic  = "Fraunces72pt-BoldItalic"

    static let bodyRegular        = "Inter-Regular"
    static let bodyMedium         = "Inter-Medium"
    static let bodySemiBold       = "Inter-SemiBold"
    static let bodyBold           = "Inter-Bold"
}

extension Font {
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
            name = FontName.displayBoldItalic
        case (.bold, false), (.semibold, false), (.heavy, false), (.black, false):
            name = FontName.displayBold
        case (_, true):
            name = FontName.displayItalic
        case (_, false):
            name = FontName.displayRegular
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
            name = FontName.bodyBold
        case .semibold:
            name = FontName.bodySemiBold
        case .medium:
            name = FontName.bodyMedium
        default:
            name = FontName.bodyRegular
        }
        return .custom(name, size: size, relativeTo: style)
    }

    // MARK: - Roles semánticos

    static var appTitle: Font {
        .display(size: 44, weight: .bold, italic: true, relativeTo: .largeTitle)
    }
    static var heroNumber: Font {
        .display(size: 80, weight: .bold, italic: false, relativeTo: .largeTitle)
    }
    static var sectionTitle: Font {
        .body(size: 20, weight: .semibold, relativeTo: .title3)
    }
    static var cardTitle: Font {
        .body(size: 16, weight: .semibold, relativeTo: .headline)
    }
    static var bodyText: Font {
        .body(size: 15, weight: .regular, relativeTo: .body)
    }
    static var bodyEmphasis: Font {
        .body(size: 15, weight: .medium, relativeTo: .body)
    }
    static var metaCaption: Font {
        .body(size: 12, weight: .regular, relativeTo: .caption)
    }
}
