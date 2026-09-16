import SwiftUI

/// La tarjeta del puesto y la nota, y la métrica suelta que la acompaña.
///
/// Es la superficie que el conmutador de aplicaciones enseñaba a cualquiera
/// que mirase el teléfono, y la razón de que exista `PrivacyGate`.
struct StandingCard: View {
    let standing: StandingDTO

    /// Si la nota ya es definitiva. Depende del estado de la CONVOCATORIA, que
    /// este DTO no trae: lo inyecta quien sí lo conoce.
    var finality: GradeFinality = .unknown

    var body: some View {
        VStack(spacing: Theme.spacing.lg.value) {
            VStack(spacing: Theme.spacing.xs.value) {
                Text("Puesto")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                Text("\(standing.position)")
                    .font(.heroNumber)
                    // La cifra saltaba de golpe al refrescar. `numericText`
                    // rueda los dígitos que cambian y deja quietos los demás,
                    // que es lo que hace legible un cambio de puesto en vez de
                    // un parpadeo.
                    .contentTransition(.numericText())
                    .foregroundStyle(Color.brand)
                    .accessibilityLabel("Puesto \(standing.position) de \(standing.totalCandidates)")
                Text("de \(standing.totalCandidates)")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            HStack(spacing: Theme.spacing.md.value) {
                StandingMetric(
                    title: finality.scoreLabel,
                    value: ScoreFormat.aggregate(standing.score)
                )
                // Sin fracción: `attemptsCompleted` cuenta recorridos de examen
                // distintos y `attemptsTotal` cuenta intentos. Son dos unidades
                // distintas, así que «2/4» no describe ningún progreso real, y
                // ninguno de los dos es el denominador de la nota.
                StandingMetric(
                    title: "Intentos registrados",
                    value: "\(standing.attemptsTotal)"
                )
            }

            if let composition = standing.composition {
                compositionBlock(composition)
            }

            if let note = finality.note {
                Text(note)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                let enrolment = StatusVocabulary.enrolment(standing.status)
                HStack(spacing: Theme.spacing.sm.value) {
                    Text("Estado de su matrícula")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    StatusBadge(text: enrolment.label, kind: enrolment.kind)
                }
                // Una sola frase, en un solo sitio. La que había aquí usaba el
                // sentido de CUPO de una palabra que el documento de entrega
                // v1.1 le niega al cliente por escrito, y estaba justo debajo
                // de la posición del aspirante. La escribí yo; la cazó la
                // auditoría de la otra sesión.
                Text(LegalNotice.outcomeDecidedByCMadrid)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.spacing.lg.value)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.paperElevated)
        )
        .themedShadow(.medium)
    }

    /// De qué está hecha la nota.
    ///
    /// Es la diferencia entre leer «4,75» y entender «4,75, que son cinco
    /// recorridos conducidos con un 9,50 de media más cinco que aún no has
    /// hecho y computan como cero». Sin esto, alguien concluye que conduce mal
    /// cuando lo que pasa es que va por la mitad del examen.
    @ViewBuilder
    private func compositionBlock(_ composition: GradeComposition) -> some View {
        // La explicación vive en `GradeCompositionView`, que comparten esta
        // pantalla y la de progreso: son cuatro números cuya redacción importa,
        // y dos copias se habrían separado a la primera corrección.
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            if !composition.isGlobalBest { Divider() }
            GradeCompositionView(composition: composition)
        }
    }
    
}

struct StandingMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.body(size: 18, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Color.ink)
            Text(title)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing.md.value)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.paper)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// El destino «ver esta vuelta» dentro de la pila del aspirante.
/// Deja de ser privado al fichero porque lo usan tres vistas que ahora
/// viven en ficheros distintos.
struct StudentAttemptRoute: Hashable {
    let attemptId: String

    /// Cuándo fue el intento. La lleva la fila de la lista y el detalle no la
    /// recibe del API, así que viaja en la ruta.
    var createdAt: String?
}

/// Tab del STUDENT en el dashboard: muestra saludo + selector de convocatorias
/// + standing + lista de intentos. Si tiene una sola, va directo a ella.
