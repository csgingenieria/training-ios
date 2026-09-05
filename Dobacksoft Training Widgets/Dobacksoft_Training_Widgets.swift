import WidgetKit
import SwiftUI

// Widget "Mi posición" — V1 con datos placeholder.
//
// Caso de uso: STUDENT mira el lock screen / home screen y ve su puesto +
// nota sin abrir la app. Ideal para el bombero candidato.
//
// V2 (cuando se configure App Groups + Keychain compartido):
//   - Provider lee token del Keychain compartido (kSecAttrAccessGroup).
//   - getTimeline llama GET /api/v1/me/convocatorias/<id>/standing.
//   - .policy(.after(...)) cada 30 minutos para refrescar.
// Hoy V1: snapshot estático, mismo standing en todas las entries.

struct StandingProvider: TimelineProvider {
    func placeholder(in context: Context) -> StandingEntry {
        StandingEntry(date: Date(), standing: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StandingEntry) -> Void) {
        completion(StandingEntry(date: Date(), standing: .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StandingEntry>) -> Void) {
        // V1: una entry, refresh policy en 30 min. V2 reemplaza esto con
        // request real al backend usando token del Keychain compartido.
        let now = Date()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        let entry = StandingEntry(date: now, standing: .sample)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct StandingEntry: TimelineEntry {
    let date: Date
    let standing: WidgetStandingMock
}

struct StandingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StandingEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        case .accessoryInline:      inlineView
        case .systemSmall:          smallView
        case .systemMedium:         mediumView
        default:                    smallView
        }
    }

    // MARK: - Lock screen / watch face

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.standing.position)")
                    .font(.system(size: 22, weight: .bold, design: .serif).italic())
                Text("/\(entry.standing.totalCandidates)")
                    .font(.system(size: 9, weight: .medium))
            }
        }
        .accessibilityLabel("Puesto \(entry.standing.position) de \(entry.standing.totalCandidates)")
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.standing.convocatoriaName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.standing.position)")
                    .font(.system(size: 24, weight: .bold, design: .serif).italic())
                Text("/\(entry.standing.totalCandidates)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(String(format: "Nota %.2f", entry.standing.score))
                Text("·")
                Text("\(entry.standing.attemptsCompleted)/\(entry.standing.attemptsTotal)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var inlineView: some View {
        Text("Training · \(entry.standing.position) de \(entry.standing.totalCandidates) · \(String(format: "%.2f", entry.standing.score))")
    }

    // MARK: - Home screen

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.widgetBrand)
                Text("Training")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.widgetBrand)
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.standing.position)")
                    .font(.system(size: 56, weight: .bold, design: .serif).italic())
                    .foregroundStyle(Color.widgetBrand)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("/\(entry.standing.totalCandidates)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)
            }

            Text(entry.standing.convocatoriaName)
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                Text(String(format: "%.2f", entry.standing.score))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(scoreColor(entry.standing.score))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Color.widgetPaper, for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Mi posición. Puesto \(entry.standing.position) de \(entry.standing.totalCandidates). " +
            "Nota \(String(format: "%.2f", entry.standing.score)). " +
            "\(entry.standing.convocatoriaName)."
        )
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .center, spacing: 2) {
                Text("Puesto")
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                Text("\(entry.standing.position)")
                    .font(.system(size: 48, weight: .bold, design: .serif).italic())
                    .foregroundStyle(Color.widgetBrand)
                Text("de \(entry.standing.totalCandidates)")
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(Color.widgetBrand)
                    Text("Training")
                        .foregroundStyle(Color.widgetBrand)
                }
                .font(.caption.weight(.semibold))

                Text(entry.standing.convocatoriaName)
                    .font(.caption)
                    .foregroundStyle(Color.widgetInk)
                    .lineLimit(2)

                Spacer(minLength: 0)

                metric(label: "Nota", value: String(format: "%.2f", entry.standing.score), color: scoreColor(entry.standing.score))
                metric(label: "Intentos", value: "\(entry.standing.attemptsCompleted)/\(entry.standing.attemptsTotal)")
            }
            Spacer(minLength: 0)
        }
        .containerBackground(Color.widgetPaper, for: .widget)
        .accessibilityElement(children: .combine)
    }

    private func metric(label: String, value: String, color: Color = .widgetInk) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<5:  return .widgetDanger
        case 5..<7:  return .widgetMuted
        case 7..<9:  return .widgetBrand
        default:     return .widgetSuccess
        }
    }
}

struct StandingWidget: Widget {
    let kind: String = "com.dobacksoft.training.standing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StandingProvider()) { entry in
            StandingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mi posición")
        .description("Tu puesto y nota en la convocatoria actual.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    StandingWidget()
} timeline: {
    StandingEntry(date: .now, standing: .sample)
    StandingEntry(date: .now, standing: .lowerPosition)
}

#Preview(as: .systemMedium) {
    StandingWidget()
} timeline: {
    StandingEntry(date: .now, standing: .sample)
}

#Preview(as: .accessoryRectangular) {
    StandingWidget()
} timeline: {
    StandingEntry(date: .now, standing: .sample)
}

#Preview(as: .accessoryCircular) {
    StandingWidget()
} timeline: {
    StandingEntry(date: .now, standing: .sample)
}
