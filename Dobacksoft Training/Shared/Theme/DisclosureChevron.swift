import SwiftUI

/// El galón que indica «esto abre otra pantalla».
///
/// Estaba escrito a mano en seis sitios, cada uno con su tamaño de fuente y su
/// color, y en algunos sin ocultar a VoiceOver — que entonces lo lee como
/// «chevron punto derecha» al final de cada fila.
///
/// Un componente para que sea el mismo galón, y para que oculto a VoiceOver sea
/// el comportamiento por defecto y no algo que haya que recordar.
struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.muted)
            // Decorativo: la fila ya dice a dónde va con su etiqueta o su
            // pista, y leer el galón añade ruido a cada parada.
            .accessibilityHidden(true)
    }
}
