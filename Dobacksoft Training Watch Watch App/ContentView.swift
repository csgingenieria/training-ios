import SwiftUI

// Watch app — V1 con mock data.
// Vista principal: standing del STUDENT en glance. Tab horizontal a "Mis intentos".
//
// V2 (necesita pasos en Xcode UI):
//   1. Activar "App Groups" en target principal + Watch target.
//   2. Crear `group.com.dobacksoft.training` en developer portal.
//   3. Refactor `TokenStore` con `kSecAttrAccessGroup`.
//   4. Crear `WatchAPIClient` que lea token compartido y use endpoints reales.
//   5. Alternativa: WatchConnectivity para empujar token + standing desde iPhone.

struct ContentView: View {
    var body: some View {
        TabView {
            StandingPage(standing: .sample)
                .tag(0)
            AttemptsPage(attempts: WatchAttemptMock.samples)
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Página standing

private struct StandingPage: View {
    let standing: WatchStandingMock

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Mi posición")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.watchMuted)
                    .textCase(.uppercase)

                Text("\(standing.position)")
                    .font(.system(size: 60, weight: .bold, design: .serif).italic())
                    .foregroundStyle(Color.watchBrand)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("de \(standing.totalCandidates)")
                    .font(.caption2)
                    .foregroundStyle(Color.watchMuted)

                Divider().padding(.vertical, 4)

                metricRow(label: "Nota", value: String(format: "%.2f", standing.score), color: scoreColor(standing.score))
                metricRow(label: "Intentos", value: "\(standing.attemptsCompleted)/\(standing.attemptsTotal)")

                Text(standing.convocatoriaName)
                    .font(.caption2)
                    .foregroundStyle(Color.watchMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .containerBackground(Color.watchBrand.opacity(0.08).gradient, for: .navigation)
        .accessibilityElement(children: .contain)
    }

    private func metricRow(label: String, value: String, color: Color = .watchInk) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.watchMuted)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<5:  return .watchDanger
        case 5..<7:  return .watchWarning
        case 7..<9:  return .watchBrand
        default:     return .watchSuccess
        }
    }
}

// MARK: - Página intentos

private struct AttemptsPage: View {
    let attempts: [WatchAttemptMock]

    var body: some View {
        List {
            Section {
                ForEach(attempts) { attempt in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attempt.routeLabel)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(attempt.date)
                                .font(.caption2)
                                .foregroundStyle(Color.watchMuted)
                        }
                        Spacer()
                        if let s = attempt.score {
                            Text(String(format: "%.2f", s))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(scoreColor(s))
                        } else {
                            Text("—")
                                .foregroundStyle(Color.watchMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Mis intentos")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.watchBrand)
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<5:  return .watchDanger
        case 5..<7:  return .watchWarning
        case 7..<9:  return .watchBrand
        default:     return .watchSuccess
        }
    }
}

#Preview {
    ContentView()
}
