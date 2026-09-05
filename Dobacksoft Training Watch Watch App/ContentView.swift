import SwiftUI

// El reloj no muestra datos del aspirante.
//
// Hasta ahora enseñaba una posición y una nota inventadas (puesto 5 de 42,
// nota 8,25) con el rótulo «Mi posición». Un aspirante que no hubiera conducido
// nada leía en su muñeca, delante de sus compañeros de parque, un resultado que
// nadie había medido.
//
// La app iOS es el único proceso con credenciales. Para que el reloj muestre el
// dato real hace falta transporte por WatchConnectivity y una cirugía de
// targets —el reloj es hoy `WKWatchOnly`, con un bundle id que no cuelga del de
// la app, así que no se distribuye con ella—. Eso es una segunda entrega.
//
// Mientras tanto dice la verdad: no tiene el dato y explica dónde está.

struct ContentView: View {
    var body: some View {
        TabView {
            UnavailablePage(
                title: "Mi posición",
                message: WatchCopy.sinDatosPosicion,
                symbol: "trophy"
            )
            .tag(0)

            UnavailablePage(
                title: "Mis intentos",
                message: WatchCopy.sinDatosIntentos,
                symbol: "list.bullet"
            )
            .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

private struct UnavailablePage: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.watchMuted)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.watchInk)

            Text(message)
                .font(.caption2)
                .foregroundStyle(Color.watchMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    ContentView()
}
