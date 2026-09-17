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

extension Font {

    // MARK: - Roles semánticos

    static var appTitle: Font {
        .display(size: 44, weight: .bold, italic: true, relativeTo: .largeTitle)
    }
    /// Una cifra en una fila de métricas. Inter, porque va con su rótulo.
    static var metricValue: Font {
        .body(size: 20, weight: .semibold, relativeTo: .title3)
    }

    /// Una cifra que es el dato principal de su tarjeta.
    static var metricValueLarge: Font {
        .display(size: 28, weight: .bold, italic: false, relativeTo: .title)
    }

    /// La nota, cuando es lo único que se mira.
    ///
    /// Los tres existen porque las cifras estaban escritas con `size:` a mano
    /// en cada sitio —18, 20, 22, 28, 44— y no había forma de saber si dos que
    /// coincidían era a propósito o por casualidad. Un rol dice qué ES la
    /// cifra; un tamaño solo dice cuánto mide.
    /// El glifo de pantalla completa: el escudo del arranque, del bloqueo y del
    /// acceso, y los iconos de los estados vacíos.
    ///
    /// Era un `56` literal repartido por seis sitios. El valor no cambia —esto
    /// no altera un píxel—, pero deja de estar disperso: el día que el escudo
    /// tenga que crecer, se cambia aquí y no en una búsqueda por el proyecto.
    ///
    /// **Sigue siendo tamaño fijo, y conviene saberlo.** Es lo único de la app
    /// que no escala con el tamaño de texto del sistema. Se acepta porque es un
    /// símbolo decorativo, marcado `accessibilityHidden` allá donde aparece:
    /// quien usa tamaños de accesibilidad necesita que crezca el texto que
    /// informa, no el adorno que lo acompaña.
    static var heroGlyph: Font {
        .system(size: 56)
    }

    /// El PIN de la tablet, en monoespaciada.
    ///
    /// Monoespaciada porque se teclea mirando: con proporcional, un `1` y un
    /// `7` ocupan distinto y el ojo pierde la posición al copiar dígito a
    /// dígito. Y **escala con el texto del sistema**, a diferencia de
    /// `heroGlyph`: esto no es un adorno, es la cifra que hay que leer.
    static var pinDisplay: Font {
        .system(.largeTitle, design: .monospaced, weight: .bold)
    }

    static var scoreHero: Font {
        .display(size: 56, weight: .bold, italic: false, relativeTo: .largeTitle)
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
