import SwiftUI

/// Los cuatro bloques de conducción en la ficha del intento.
///
/// Es lo que contesta «qué nota tengo y en qué he fallado» cuando falta la
/// mitad de estabilidad. El portal se lo enseñaba al aspirante y la app no,
/// así que la ficha nativa tenía la nota y no la explicación.
///
/// Cada bloque se pinta solo si llega. Un bloque ausente NO se dibuja vacío:
/// un marco sin cifras se lee como un cero, y un cero es una afirmación sobre
/// el conductor. Y hay un `null` que es deliberado del backend — cuando el
/// indicador de Webfleet no corresponde a la ventana del propio intento— para
/// no imputarle al aspirante la conducción del camión durante toda la semana.
struct DrivingBlocksSection: View {
    let attempt: AttemptDetailDTO

    var body: some View {
        if attempt.showsDrivingBlocks || attempt.drivingDataWillNotArrive {
            VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
                Text("Cómo condujo")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)

                if let narrativa = attempt.drivingNarrative {
                    narrativeCard(narrativa)
                }
                if let parcial = attempt.partialWebfleet {
                    partialCard(parcial)
                }
                if let allison = attempt.allison {
                    allisonCard(allison)
                }
                if attempt.drivingDataWillNotArrive {
                    noTripCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - La narrativa, punto por punto

    @ViewBuilder
    private func narrativeCard(_ narrativa: DrivingNarrativeDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack(alignment: .firstTextBaseline) {
                Text("Su conducción")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Spacer()
                if let sobreDiez = narrativa.outOfTen {
                    Text(ScoreFormat.attempt(sobreDiez))
                        .font(.metricValue)
                        .foregroundStyle(Color.ink)
                        .accessibilityLabel(
                            "Su conducción: \(ScoreFormat.spoken(sobreDiez, decimals: 1))"
                        )
                }
            }

            // Lo primero, no una nota al pie: sin esto el número de arriba se
            // lee como la nota del intento, y es media.
            if narrativa.isPartial == true, let falta = narrativa.missing {
                Text("Es la mitad de la nota: falta \(falta).")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(narrativa.points) { punto in
                VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
                    HStack(spacing: Theme.spacing.sm.value) {
                        Text(punto.title ?? "—")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                        if let level = punto.level {
                            StatusBadge(text: level.label, kind: level.badgeKind)
                        }
                        Spacer()
                        if let sobreDiez = punto.outOfTen {
                            Text(ScoreFormat.attempt(sobreDiez))
                                .font(.metaCaption)
                                .foregroundStyle(Color.muted)
                        }
                    }
                    if let detalle = punto.detail {
                        // La frase la escribe el backend y se pinta tal cual:
                        // reescribirla aquí la separaría de la del portal, y
                        // las dos explican la misma deducción.
                        Text(detalle)
                            .font(.metaCaption)
                            .foregroundStyle(Color.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            if let km = narrativa.distanceKm, let min = narrativa.durationMin {
                Text("\(ScoreFormat.attempt(km)) km · \(min) min")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - La mitad de Webfleet

    @ViewBuilder
    private func partialCard(_ parcial: PartialWebfleetDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Conducción registrada")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)

            if let sobreDiez = parcial.outOfTen {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.xs.value) {
                    Text(ScoreFormat.attempt(sobreDiez))
                        .font(.body(size: 24, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Color.ink)
                    Text("sobre 10")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Conducción registrada: \(ScoreFormat.spoken(sobreDiez, decimals: 1))"
                )
            }

            // `isHalfOfTheGrade` y no `outOfTen != nil`: lo que hace media a
            // esta cifra es que falte la otra mitad, y el campo que lo dice es
            // `missing`.
            if parcial.isHalfOfTheGrade, let falta = parcial.missing {
                Text("No es la nota del intento: falta \(falta).")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let peso = parcial.drivingWeightPct {
                Text("Este apartado pesa un \(ScoreFormat.attempt(peso)) % en la nota.")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            if let viajes = parcial.tripCount, let km = parcial.distanceKm {
                Text("\(viajes) \(viajes == 1 ? "trayecto" : "trayectos") · \(ScoreFormat.attempt(km)) km")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - La caja Allison

    @ViewBuilder
    private func allisonCard(_ allison: AllisonDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Caja de cambios")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)

            if allison.evaluated == false {
                Text(AllisonCopy.unevaluated(reason: allison.reason))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let pulsaciones = allison.presses, let minimo = allison.minimumPresses {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Pulsaciones")
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                        Spacer()
                        Text("\(pulsaciones) de \(minimo) exigidas")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                    }
                }

                Text(AllisonCopy.compliance(allison))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let sobreDiez = allison.outOfTen, let maximo = allison.max {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Aporta")
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                        Spacer()
                        Text("\(ScoreFormat.component(allison.contribution ?? 0)) de \(ScoreFormat.component(maximo))")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Aporta \(ScoreFormat.component(allison.contribution ?? 0)) de \(ScoreFormat.component(maximo)) puntos, con un \(ScoreFormat.attempt(sobreDiez)) sobre 10"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Preguntado y sin viaje

    /// El caso que evita una espera inútil: ya se preguntó a Webfleet y no
    /// había viaje en la ventana. Decir «pendiente» aquí manda al aspirante a
    /// esperar algo que no va a llegar nunca.
    @ViewBuilder
    private var noTripCard: some View {
        HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.muted)
                .accessibilityHidden(true)
            Text("No consta ningún trayecto del camión en el horario de este intento, así que no habrá datos de conducción para esta vuelta.")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
