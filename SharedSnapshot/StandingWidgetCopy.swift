import Foundation

/// Lo que VoiceOver oye del widget.
///
/// Vive aquí, y no en el target del widget, por dos razones. La primera es que
/// se pueda probar: el target del widget no tiene host de tests, así que todo
/// lo que se quede dentro es código sin red.
///
/// La segunda la enseñó el propio defecto que esto arregla. La línea
/// «Consultado el …» —la única señal de que una cifra puede tener entre 6 y 48
/// horas— se pintaba a 9 pt y **no estaba en la etiqueta de accesibilidad**.
/// Así que quien usa VoiceOver oía el puesto y la nota como si fueran de ahora,
/// sin manera de enterarse. Es la regla escrita del widget vuelta contra sí
/// misma: se niega a mostrar una cifra vieja sin etiquetarla, y la etiquetaba
/// para todos menos para quien no puede ver la etiqueta.
nonisolated enum StandingWidgetCopy {
    /// El rótulo de la nota según su finalidad.
    static func scoreLabel(_ standing: StandingSnapshot.Standing) -> String {
        standing.finality == .provisional ? SnapshotCopy.notaProvisional : SnapshotCopy.nota
    }

    static func accessibilityText(
        redacted: Bool,
        standing: StandingSnapshot.Standing?,
        message: String?,
        capturedAt: Date?,
        /// Opcional porque sin instantánea no hay nada que fechar, y eso es un
        /// estado real: `WidgetState.freshness` llega `nil` ahí.
        freshness: SnapshotFreshness?
    ) -> String {
        // La redacción manda sobre todo, la frescura incluida: con la pantalla
        // bloqueada no se dice ni una cifra. Antes VoiceOver leía el puesto a
        // través de la pantalla de bloqueo.
        if redacted { return SnapshotCopy.redactado }

        guard let standing else {
            // Sin cifras, el mensaje; y si tampoco hay mensaje, al menos el
            // nombre. Una etiqueta vacía es un widget que VoiceOver no puede
            // describir en absoluto.
            return "\(SnapshotCopy.widgetName). \(message ?? SnapshotCopy.ilegibleCorto)"
        }

        var parts = ["\(SnapshotCopy.widgetName). Puesto \(standing.position) de \(standing.totalCandidates)"]

        if let score = standing.score {
            parts.append("\(scoreLabel(standing)) \(ScoreFormat.aggregate(score))")
        } else {
            // Nunca un cero y nunca silencio: se dice que no la hay.
            parts.append(SnapshotCopy.notaNoDisponible)
        }

        parts.append(standing.convocatoriaName)

        // Al final, después de las cifras: primero va lo que se preguntó, y la
        // salvedad detrás, igual que el layout la pone debajo. Sin fecha no se
        // dice nada — inventarla sería peor que callar.
        if freshness == .envejecido, let capturedAt {
            parts.append(SnapshotCopy.consultadoEl(capturedAt))
        }

        return parts.joined(separator: ". ")
    }
}
