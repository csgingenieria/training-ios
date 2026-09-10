import SwiftUI

/// Lo que el widget va a leer, expuesto para poder comprobarlo.
///
/// XCUITest no alcanza una extensión de widget desde el proceso de la app, así
/// que la pantalla de inicio del aspirante era lo único de todo el producto sin
/// una sola verificación contra datos reales. Y es la superficie que **ven
/// otras personas**.
///
/// Lo que no se puede alcanzar es la VISTA del widget. Lo que sí, y es lo que
/// puede estar mal, es la instantánea que va a leer: que se escriba, que lleve
/// el contenido que toca y que respete la preferencia. La app la lee del App
/// Group —el runner no puede, es otro proceso— y la deja aquí como etiqueta.
///
/// **Solo con `-uitest-redact-secrets`**, la misma bandera que tapa el PIN: es
/// una superficie de diagnóstico y no puede existir en la app que se instala.
/// La instantánea, además, no lleva identificador de persona, correo, plaza ni
/// cupo — eso ya lo garantiza `StandingSnapshot`.
struct PublishedSnapshotProbe: View {
    var body: some View {
        if SecretRedaction.isActive {
            Text(descripcion)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityIdentifier("snapshot.published")
                .accessibilityLabel(descripcion)
        }
    }

    /// Una línea que dice qué encontraría el widget ahora mismo.
    ///
    /// Se describe el CASO, no las cifras crudas: lo que puede estar roto es
    /// que se publique el contenido equivocado, no el número.
    private var descripcion: String {
        switch SnapshotStore().read() {
        case .ilegible(let motivo):
            return "ilegible:\(motivo.rawValue)"
        case .ausente:
            return "ausente"
        case .presente(let snapshot):
            switch snapshot.content {
            case .posicion(let standing):
                return "posicion:\(standing.position)/\(standing.totalCandidates)"
            case .desactivado:       return "desactivado"
            case .sinPosicionPropia: return "sinPosicionPropia"
            case .sinDatosAun:       return "sinDatosAun"
            case .sinConvocatoria:   return "sinConvocatoria"
            case .sinPosicion:       return "sinPosicion"
            }
        }
    }
}
