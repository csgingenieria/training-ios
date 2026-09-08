import WidgetKit
import SwiftUI

// Widget «Mi posición».
//
// No habla con el backend ni tiene credenciales: la app iOS es el único proceso
// que consulta la API, y deposita una instantánea fechada en el App Group que
// este widget se limita a pintar.
//
// Hasta ahora mostraba SIEMPRE un dato inventado —puesto 5 de 42, nota 8,25—
// con el rótulo «Tu puesto y nota en la convocatoria actual». Cualquiera que
// mirase el teléfono de un aspirante leía un resultado que nadie había medido.
//
// Regla que gobierna todo este archivo: si no hay dato, se dice que no lo hay.
// Nunca un cero, nunca un guion en lugar de una cifra.

struct StandingEntry: TimelineEntry {
    let date: Date
    let state: WidgetState

    /// Entrada sin dato, para la galería y para cuando no se puede leer.
    static func placeholder(at date: Date) -> StandingEntry {
        StandingEntry(
            date: date,
            state: WidgetState(read: .ilegible(.sinContenedor), freshness: nil)
        )
    }
}

struct StandingProvider: TimelineProvider {
    private let reader = SnapshotReader()

    /// La galería del sistema nunca ve cifras: enseñar ahí un puesto de ejemplo
    /// es lo que hacía que el widget pareciera tener datos antes de tenerlos.
    func placeholder(in context: Context) -> StandingEntry {
        .placeholder(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StandingEntry) -> Void) {
        let now = Date()
        completion(
            context.isPreview
                ? .placeholder(at: now)
                : StandingEntry(date: now, state: reader.state(at: now))
        )
    }

    /// Una sola lectura de fichero deja programado el envejecimiento del dato.
    ///
    /// En vez de despertar cada media hora a releer lo mismo, se emiten
    /// entradas en los instantes en que la representación cambia sola (a las 6 h
    /// y a las 48 h de la captura). Así el dato envejece sin gastar presupuesto
    /// de recarga, que iOS raciona.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StandingEntry>) -> Void) {
        let now = Date()
        let crossings = reader.futureCrossings(after: now)

        var entries = [StandingEntry(date: now, state: reader.state(at: now))]
        entries += crossings.map { StandingEntry(date: $0, state: reader.state(at: $0)) }

        // Nunca una línea temporal vacía ni una política en el pasado: dejaría
        // el widget congelado en lo último que pintó.
        let policy: TimelineReloadPolicy = crossings.isEmpty
            ? .never
            : .after(min(crossings[0], now.addingTimeInterval(4 * 3600)))

        completion(Timeline(entries: entries, policy: policy))
    }
}

// MARK: - Vista

struct StandingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons

    var entry: StandingEntry

    var body: some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
            // El toque abre «Mi posición», que es la pantalla que el propio
            // widget dice que hay que abrir y la única que republica la
            // instantánea. Sin esto abría Convocatorias: la instrucción era
            // cierta y el toque la contradecía.
            .widgetURL(SnapshotLink.miPosicion)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        case .systemMedium:         mediumView
        default:                    smallView
        }
    }

    /// Qué contar según el estado. Un solo sitio para las dos familias grandes.
    private var message: String? {
        switch entry.state.read {
        case .ilegible:
            return family == .systemMedium ? SnapshotCopy.ilegibleLargo : SnapshotCopy.ilegibleCorto
        case .ausente:
            return SnapshotCopy.sinSesion
        case let .presente(snapshot):
            if entry.state.freshness == .caducado { return SnapshotCopy.caducado }
            switch snapshot.content {
            case .desactivado:       return SnapshotCopy.desactivado
            case .sinPosicionPropia: return SnapshotCopy.sinPosicionPropia
            case .sinDatosAun:       return SnapshotCopy.sinDatosAun
            case .sinConvocatoria:   return SnapshotCopy.sinConvocatoria
            case let .sinPosicion(name):
                return family == .systemMedium
                    ? SnapshotCopy.sinPosicionEn(name)
                    : "\(SnapshotCopy.sinPosicionTitulo). \(SnapshotCopy.sinPosicionDetalle)"
            case .posicion:
                return nil // Hay cifras.
            }
        }
    }

    private var standing: StandingSnapshot.Standing? {
        guard case let .presente(snapshot) = entry.state.read,
              case let .posicion(value) = snapshot.content,
              entry.state.freshness != .caducado
        else { return nil }
        return value
    }

    private var capturedAt: Date? {
        guard case let .presente(snapshot) = entry.state.read else { return nil }
        return snapshot.capturedAt
    }

    // MARK: Familias

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            if let standing {
                positionBlock(standing)
                scoreLine(standing)
            } else if let message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ageNote
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Color.widgetPaper, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let standing {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    positionBlock(standing)
                    Divider().frame(height: 32)
                    scoreBlock(standing)
                    Spacer(minLength: 0)
                }
                Text(standing.convocatoriaName)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                    .lineLimit(1)
                if standing.finality == .provisional {
                    Text(SnapshotCopy.notaProvisionalDetalle)
                        .font(.caption2)
                        .foregroundStyle(Color.widgetMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.widgetMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ageNote
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Color.widgetPaper, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let standing {
                VStack(spacing: 0) {
                    Text("\(standing.position)")
                        .font(.title3.weight(.bold))
                    Text("de \(standing.totalCandidates)")
                        .font(.caption2)
                        .minimumScaleFactor(0.8)
                }
                .privacySensitive()
            } else {
                Image(systemName: "trophy")
                    .font(.title3)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(SnapshotCopy.widgetName)
                .font(.caption2.weight(.semibold))
            if let standing {
                Text("Puesto \(standing.position) de \(standing.totalCandidates)")
                    .font(.caption2)
                    .privacySensitive()
            } else if let message {
                Text(message)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }

    // MARK: Piezas

    private var header: some View {
        Text(SnapshotCopy.widgetName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.widgetMuted)
    }

    private func positionBlock(_ standing: StandingSnapshot.Standing) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(standing.position)")
                // Estilo de texto y no un tamaño fijo: `.system(size:)` ignora
                // el tamaño de letra del sistema, y un bombero con la letra
                // grande veía el puesto igual de pequeño que todo lo demás.
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Color.widgetInk)
            Text("de \(standing.totalCandidates)")
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
        }
        .privacySensitive()
    }

    private func scoreBlock(_ standing: StandingSnapshot.Standing) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let score = standing.score {
                Text(ScoreFormat.aggregate(score))
                    .font(.title2.weight(.semibold))
                    .fontDesign(.rounded)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Color.widgetInk)
                    .privacySensitive()
            } else {
                Text(SnapshotCopy.notaNoDisponible)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
            }
            Text(scoreLabel(standing))
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
        }
    }

    @ViewBuilder
    private func scoreLine(_ standing: StandingSnapshot.Standing) -> some View {
        if let score = standing.score {
            Text("\(scoreLabel(standing)) \(ScoreFormat.aggregate(score))")
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
                .privacySensitive()
        } else {
            Text(SnapshotCopy.notaNoDisponible)
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
        }
    }

    private func scoreLabel(_ standing: StandingSnapshot.Standing) -> String {
        StandingWidgetCopy.scoreLabel(standing)
    }

    /// Con el dato entre 6 y 48 horas se muestra cuándo se consultó. Un puesto
    /// de anteayer presentado como actual es tan falso como uno inventado.
    @ViewBuilder
    private var ageNote: some View {
        if entry.state.freshness == .envejecido, let capturedAt {
            Text(SnapshotCopy.consultadoEl(capturedAt))
                .font(.caption2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(2)
        }
    }

    // MARK: Accesibilidad

    /// Derivado del estado, nunca compuesto a mano sobre las cifras: antes
    /// VoiceOver leía el puesto y la nota incluso con la pantalla bloqueada.
    ///
    /// El texto vive en `SharedSnapshot` porque este target no tiene host de
    /// tests, y porque le faltaba la nota de frescura: quien usa VoiceOver oía
    /// una cifra de hace dos días como si fuera de ahora.
    private var accessibilityText: String {
        StandingWidgetCopy.accessibilityText(
            redacted: redactionReasons.contains(.privacy),
            standing: standing,
            message: message,
            capturedAt: capturedAt,
            freshness: entry.state.freshness
        )
    }
}

// MARK: - Declaración

struct StandingWidget: Widget {
    let kind: String = "com.dobacksoft.training.standing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StandingProvider()) { entry in
            StandingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(SnapshotCopy.widgetName)
        .description(SnapshotCopy.widgetDescription)
        // Solo pantalla de inicio en la primera entrega.
        //
        // Las familias `accessory*` viven en la pantalla de bloqueo, donde el
        // dato lo ve cualquiera que pase junto al teléfono sin desbloquearlo.
        // Hablamos de la posición de una persona en una oposición pública, con
        // datos bajo NDA: `.privacySensitive()` mitiga, pero el riesgo no
        // compensa mientras nadie las haya pedido.
        //
        // `.accessoryInline` queda descartada del todo: es texto plano que el
        // sistema no redacta. Las otras dos se activan añadiéndolas aquí, y las
        // vistas que las pintan siguen escritas más arriba.
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
        ])
    }
}
