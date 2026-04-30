import SwiftUI

struct ConvocatoriaDetailView: View {
    let convocatoria: ConvocatoriaSummaryDTO
    @Environment(AuthSession.self) private var auth

    var body: some View {
        Form {
            Section("Resumen") {
                LabeledContent("Nombre", value: convocatoria.name)
                if let s = convocatoria.status {
                    LabeledContent("Estado", value: s)
                }
                LabeledContent("Plazas", value: "\(convocatoria.plazas)")
                LabeledContent("Candidatos", value: "\(convocatoria.totalCandidates)")
                if let updated = convocatoria.updatedAt {
                    LabeledContent("Actualizado", value: updated)
                }
            }
            if let descr = convocatoria.description, !descr.isEmpty {
                Section("Descripción") {
                    Text(descr)
                }
            }

            Section {
                if auth.user?.isAdminLike == true {
                    NavigationLink {
                        RankingView(convocatoriaId: convocatoria.id)
                    } label: {
                        Label("Ver ranking completo", systemImage: "list.number")
                    }
                }
                if auth.user?.isStudent == true {
                    NavigationLink {
                        StandingView(convocatoriaId: convocatoria.id)
                    } label: {
                        Label("Mi posición", systemImage: "trophy.fill")
                    }
                }
            }
        }
        .navigationTitle(convocatoria.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
