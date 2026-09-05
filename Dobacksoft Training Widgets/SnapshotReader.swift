import Foundation

/// Lo que el widget sabe en un instante concreto.
struct WidgetState: Sendable, Equatable {
    let read: SnapshotReadResult
    let freshness: SnapshotFreshness?

    /// `true` cuando hay cifras que mostrar.
    var showsFigures: Bool {
        guard case let .presente(snapshot) = read,
              case .posicion = snapshot.content,
              freshness != .caducado
        else { return false }
        return true
    }
}

/// Lee la instantánea que depositó la app.
///
/// **Solo lectura.** No escribe ni borra nunca en el contenedor compartido, ni
/// siquiera para purgar algo caducado: el widget no es dueño de ese dato.
struct SnapshotReader {
    private let store: SnapshotStore

    init(store: SnapshotStore = SnapshotStore()) {
        self.store = store
    }

    func state(at now: Date) -> WidgetState {
        let read = store.read()
        guard case let .presente(snapshot) = read else {
            return WidgetState(read: read, freshness: nil)
        }
        return WidgetState(
            read: read,
            freshness: SnapshotFreshness.evaluate(capturedAt: snapshot.capturedAt, at: now)
        )
    }

    /// Instantes futuros en los que la representación cambia sola.
    func futureCrossings(after now: Date) -> [Date] {
        guard case let .presente(snapshot) = store.read() else { return [] }
        return SnapshotFreshness.futureThresholdCrossings(capturedAt: snapshot.capturedAt, after: now)
    }
}
