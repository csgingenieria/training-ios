import SwiftUI

/// El puesto guardado, enseñado sin red.
///
/// Deliberadamente **más pobre** que `StandingCard`, y no por falta de trabajo:
/// de la caché se guarda una proyección que no lleva correo, ni nombre, ni
/// identificadores, ni la composición de la nota. Lo que no se guardó no se
/// puede pintar, y fabricarlo para que las dos tarjetas se parezcan sería
/// inventar datos.
///
/// Cada cifra pasa por su propio `if let`: la proyección las guarda opcionales
/// porque el DTO puede no traerlas, y un cero por defecto aquí afirmaría un
/// puesto o una nota que nadie ha calculado.
struct CachedStandingCard: View {
    let cache: StandingCache

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            if let name = cache.convocatoriaName {
                Text(name)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            if let position = cache.position, let total = cache.totalParticipants {
                Text("Puesto \(position) de \(total)")
                    .font(.metricValueLarge)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel("Puesto \(position) de \(total)")
            }

            if let score = cache.score {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.xs.value) {
                    Text(scoreLabel)
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    Text(ScoreFormat.aggregate(score))
                        .font(.metricValue)
                        .foregroundStyle(Color.ink)
                    Text("sobre 10")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(scoreLabel): \(ScoreFormat.spoken(score, decimals: 2))")
            } else {
                Text(SnapshotCopy.notaNoDisponible)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            // La misma aclaración que con red: la finalidad viaja guardada, ya
            // resuelta por la app, para que esta tarjeta no la derive por su
            // cuenta de un estado que la caché no guarda.
            if let note = finality.note {
                Text(note)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var finality: GradeFinality {
        cache.finality.map(GradeFinality.init(persisted:)) ?? .unknown
    }

    private var scoreLabel: String { finality.scoreLabel }
}
