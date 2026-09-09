import Foundation

/// Lo que VoiceOver oye de la cabecera de una convocatoria.
///
/// Con `.combine`, SwiftUI concatenaba las vistas en el orden en que están
/// puestas y salía «Oposición 2026, Abierta, 120, Aspirantes, Cierre punto
/// medio 12/10/2026, Actualizado punto medio 08/09/2026 13:42»: la cifra antes
/// de su rótulo, y los separadores decorativos leídos como «punto medio».
///
/// Una frase escrita a mano dice lo mismo en el orden en que se entiende.
nonisolated enum ConvocatoriaHeaderCopy {
    static func accessibilityLabel(
        name: String,
        statusLabel: String?,
        totalCandidates: Int,
        closedAt: String?,
        updatedAt: String?
    ) -> String {
        var partes = [name]
        if let statusLabel { partes.append(statusLabel) }

        // El plural, porque «1 aspirantes» se lee como un fallo.
        partes.append(totalCandidates == 1 ? "1 aspirante" : "\(totalCandidates) aspirantes")

        // «cerrada el» y no «cierre»: `closedAt` es cuándo se cerró, y el mismo
        // criterio que el subtítulo de «Mi posición».
        if let cerrada = APIDate.longDate(closedAt) {
            partes.append("cerrada el \(cerrada)")
        }
        if let actualizada = APIDate.longDateTime(updatedAt) {
            partes.append("actualizada el \(actualizada)")
        }
        return partes.joined(separator: ", ")
    }
}
