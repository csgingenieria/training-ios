import SwiftUI
import MapKit

/// La traza de la vuelta, en un mapa nativo.
///
/// Es la pantalla con más margen frente a la web: allí es una imagen dentro de
/// un navegador, y aquí se puede acercar, girar y tocar una incidencia para
/// leer qué pasó en ese punto exacto.
///
/// Y es también la que más fácil miente, porque **un mapa afirma cosas con la
/// forma de una línea**. Tres cuidados, los tres del contrato:
///
/// - Los segmentos se dibujan SEPARADOS. Un corte es un salto que el GPS no
///   pudo confirmar, y unirlos pintaría al camión atravesando un terreno que
///   nunca atravesó.
/// - Lo que se está mirando va rotulado: una traza pegada a la calzada no es lo
///   mismo que unos puntos crudos, y una ubicada al 40 % no es una medida.
/// - Un evento sin coordenadas no se clava. Inventarle un sitio pondría una
///   incidencia donde no ocurrió.
struct AttemptMapView: View {
    let attemptId: String

    @Environment(AuthSession.self) private var auth
    @State private var state: MapState = .loading
    @State private var selectedEvent: GpsEventDTO?

    enum MapState {
        case loading
        case loaded(GpsPayloadDTO)
        case empty
        case error(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando el recorrido…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()

            case .loaded(let payload):
                map(payload)

            case .empty:
                ContentUnavailableView {
                    Label("Sin traza de este intento", systemImage: "map")
                } description: {
                    Text("No consta ningún punto de GPS para esta vuelta, así que no hay recorrido que dibujar.")
                }

            case .error(let mensaje):
                ContentUnavailableView {
                    Label("No se ha podido cargar el recorrido", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(mensaje)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        .accessibilityIdentifier("mapa.retry")
                }
            }
        }
        .navigationTitle("Recorrido")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - El mapa

    @ViewBuilder
    private func map(_ payload: GpsPayloadDTO) -> some View {
        Map {
            // El recorrido previsto, de fondo y discreto: es el contraste, no
            // lo que condujo.
            if payload.route.count > 1 {
                MapPolyline(coordinates: payload.route.map(\.clLocation))
                    .stroke(Color.muted.opacity(0.5), style: .init(lineWidth: 3, dash: [6, 4]))
            }

            // Un `MapPolyline` por segmento, nunca uno solo con todos los
            // puntos: el corte entre dos es el dato.
            ForEach(Array(payload.drawableSegments.enumerated()), id: \.offset) { _, segmento in
                if segmento.count > 1 {
                    MapPolyline(coordinates: segmento.map(\.clLocation))
                        .stroke(
                            payload.isFallback ? Color.warning : Color.brand,
                            style: .init(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                }
            }

            ForEach(payload.pinnableEvents) { evento in
                if let coordenada = evento.coordinate {
                    Annotation(
                        evento.narrative ?? evento.type ?? "Incidencia",
                        coordinate: coordenada.clLocation
                    ) {
                        Button {
                            selectedEvent = evento
                        } label: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.danger)
                                // 44 pt reales: un pin de 20 pt sobre un mapa
                                // que se arrastra es imposible de acertar.
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .accessibilityLabel(AttemptMapCopy.eventLabel(evento))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .safeAreaInset(edge: .bottom) { legend(payload) }
        .sheet(item: $selectedEvent) { evento in
            EventDetailSheet(event: evento)
        }
    }

    /// Qué se está mirando. Va siempre, no solo cuando algo va mal: leer una
    /// aproximación como una medida es el error que un mapa sin etiqueta invita
    /// a cometer.
    @ViewBuilder
    private func legend(_ payload: GpsPayloadDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
            Text(AttemptMapCopy.traceLabel(payload))
                .font(.metaCaption)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            if payload.track?.hasGaps == true {
                Text(AttemptMapCopy.gaps)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing.base.value)
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            let payload = try await auth.authorized { token in
                try await APIClient.shared.attemptGps(id: attemptId, accessToken: token)
            }
            state = payload.hasSomethingToDraw ? .loaded(payload) : .empty
        } catch let error as APIError {
            state = .error(error.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: - Detalle de una incidencia

private struct EventDetailSheet: View {
    let event: GpsEventDTO

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
                    if let narrativa = event.narrative {
                        Text(narrativa)
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // El consejo lo escribe el backend: es pedagógico y la app
                    // no lo reescribe.
                    if let consejo = event.advice {
                        Text(consejo)
                            .font(.bodyText)
                            .foregroundStyle(Color.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let exceso = event.excessKmh, let limite = event.limitKmh {
                        Divider()
                        Text(AttemptMapCopy.speeding(excess: exceso, limit: limite, speed: event.speedKmh))
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let perdida = event.stabilityLossPercent {
                        Text("Pérdida de estabilidad: \(ScoreFormat.attempt(perdida)) %")
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                    }

                    // Lo que este endpoint NO dice, dicho: si restó o no sale
                    // de la ficha, no del mapa.
                    Text(AttemptMapCopy.deductionLivesInTheSheet)
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.spacing.base.value)
            }
            .pageBackground()
            .navigationTitle("Incidencia")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

/// `sheet(item:)` necesita identidad; `GpsEventDTO` ya es `Identifiable`, pero
/// su `id` es opcional, así que se envuelve para el binding.
private extension View {
    func sheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let valor = item.wrappedValue { content(valor) }
        }
    }
}
