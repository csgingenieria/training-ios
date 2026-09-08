import SwiftUI

/// De qué está hecha la nota oficial.
///
/// Extraída de `StandingView` cuando la pantalla de progreso necesitó lo mismo.
/// Se comparte la VISTA y no solo el tipo a propósito: son cuatro números cuya
/// redacción importa, y dos copias de esta explicación se habrían separado a la
/// primera corrección — igual que se separó el aviso legal, que estaba escrito
/// a mano en dos sitios.
///
/// Los dos números de arriba contestan preguntas distintas y confundirlos es lo
/// que hacía que un 9,50 se leyera como un 4,75: la nota oficial responde «cómo
/// voy en el examen» contando ceros por lo no conducido, y la media de lo
/// conducido responde «cómo conduzco».
struct GradeCompositionView: View {
    let composition: GradeComposition

    var body: some View {
        // Sin recorridos exigidos la nota es el mejor intento global: no hay
        // composición que explicar.
        if !composition.isGlobalBest {
            VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recorridos exigidos")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    Spacer()
                    Text("\(composition.completedRequired) de \(composition.totalRequired)")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.ink)
                }

                if let progress = composition.progress {
                    ProgressView(value: progress)
                        .tint(Color.brand)
                        .accessibilityLabel(
                            "\(composition.completedRequired) de \(composition.totalRequired) recorridos exigidos conducidos"
                        )
                }

                if let explanation = composition.explanation {
                    Text(explanation)
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let conducted = composition.scoreOfCompleted {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Media de lo conducido")
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                        Spacer()
                        Text(ScoreFormat.aggregate(conducted))
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                            .accessibilityLabel(
                                "Media de lo conducido: \(ScoreFormat.spoken(conducted, decimals: 2))"
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
