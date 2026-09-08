import SwiftUI

// Tokens de color del widget.
//
// Apuntan a los colorsets del catálogo de ESTE target, copiados del de la app.
// Antes eran siete literales hexadecimales, y por eso el widget era una tarjeta
// crema sobre una pantalla de inicio oscura: ignoraba la apariencia que la app
// sí respeta en todas sus pantallas.
//
// El catálogo tiene que ser el del widget: `Bundle.main` dentro de una
// extensión es la extensión, no la app, así que los colorsets de la app no se
// alcanzan desde aquí.
//
// Son una COPIA, y una copia deriva. `scripts/check-widget-palette.sh` compara
// los dos catálogos componente a componente y falla si dejan de coincidir, para
// que la app y el widget no acaben con dos azules distintos.
//
// El modelo (`StandingSnapshot`, `SnapshotFreshness`, `SnapshotStore`,
// `SnapshotCopy`, `StandingWidgetCopy`) NO se duplica: vive en
// `SharedSnapshot/` y lo compilan los dos targets.

extension Color {
    static let widgetPaper     = Color("Paper", bundle: .main)
    static let widgetInk       = Color("Ink", bundle: .main)
    static let widgetMuted     = Color("Muted", bundle: .main)
    static let widgetBrand     = Color("Brand", bundle: .main)
    static let widgetBrandTint = Color("BrandTint", bundle: .main)
    static let widgetSuccess   = Color("Success", bundle: .main)
    static let widgetDanger    = Color("Danger", bundle: .main)
}
