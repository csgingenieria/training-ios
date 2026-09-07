import Testing
import Foundation

@testable import Dobacksoft_Training

/// Crossing the ranking with the matrix into one table.
///
/// The shapes here are the ones the staging server actually returned for the
/// real convocatoria on 2026-09-07, not shapes invented alongside the code.
@Suite struct ResultadosMergeTests {
    private let requiredRoutes = ["1A", "1B", "2A1", "2A2", "2A3", "2B1", "2B2", "2B3", "3A", "3B"]

    private func ranking() throws -> RankingResponseDTO {
        let json = Data("""
        {
          "convocatoria": {
            "id": "conv-1", "name": "Oposición Conductores 2026", "status": "OPEN",
            "description": null, "totalCandidates": 4, "closedAt": null,
            "updatedAt": "2026-09-04T14:34:37.964306Z"
          },
          "entries": [
            {"attemptId": "at-jaime", "attemptsCompleted": 5, "attemptsTotal": 5,
             "candidate": {"id": "c-jaime", "name": "Primero Aspirante", "plaza": "011"},
             "completedRequired": 5, "pendingRequired": 5, "position": 1, "presented": true,
             "requiredRoutes": \(try json(requiredRoutes)), "score": 4.75,
             "scoreOfCompleted": 9.5, "tied": false},

            {"attemptId": "at-dos", "attemptsCompleted": 1, "attemptsTotal": 1,
             "candidate": {"id": "c-dos", "name": "Segundo Aspirante", "plaza": "014"},
             "completedRequired": 1, "pendingRequired": 9, "position": 2, "presented": true,
             "requiredRoutes": \(try json(requiredRoutes)), "score": 0.85,
             "scoreOfCompleted": 8.5, "tied": false},

            {"attemptId": null, "attemptsCompleted": 0, "attemptsTotal": 0,
             "candidate": {"id": "c-tres", "name": "Tercero Aspirante", "plaza": "015"},
             "completedRequired": 0, "pendingRequired": 10, "position": null, "presented": false,
             "requiredRoutes": \(try json(requiredRoutes)), "score": 0.0,
             "scoreOfCompleted": null, "tied": false}
          ]
        }
        """.utf8)
        return try JSONDecoder().decode(RankingResponseDTO.self, from: json)
    }

    /// The ten circuits the matrix returns since `get_matrix_data` was fixed,
    /// with `required` per column and the route's real name as its label.
    private func matrix() throws -> MatrixResponseDTO {
        let json = Data("""
        {
          "convocatoria": {
            "id": "conv-1", "name": "Oposición Conductores 2026", "status": "OPEN",
            "description": null, "totalCandidates": 4, "closedAt": null,
            "updatedAt": "2026-09-04T14:34:37.964306Z"
          },
          "circuits": [
            {"id": "1A", "label": "1A", "required": true, "synthetic": false},
            {"id": "1B", "label": "1B", "required": true, "synthetic": false},
            {"id": "2A1", "label": "2A1 Llegada puerto Cruz Verde", "required": true, "synthetic": false},
            {"id": "2A2", "label": "2A2 Subida y bajada Cruz Verde", "required": true, "synthetic": false},
            {"id": "2A3", "label": "2A3 Bajada puerto Cruz Verde a Rozas", "required": true, "synthetic": false},
            {"id": "2B1", "label": "2B1 por definir", "required": true, "synthetic": false},
            {"id": "2B2", "label": "2B2 por definir", "required": true, "synthetic": false},
            {"id": "2B3", "label": "2B3 por definir", "required": true, "synthetic": false},
            {"id": "3A", "label": "3A por definir", "required": true, "synthetic": false},
            {"id": "3B", "label": "3B por definir", "required": true, "synthetic": false}
          ],
          "rows": [
            {"candidate": {"id": "c-jaime", "name": "Primero Aspirante"},
             "scores": [
               {"circuitId": "1A", "score": 10.0, "attemptId": "a1"},
               {"circuitId": "1B", "score": 9.0, "attemptId": "a2"},
               {"circuitId": "2A1", "score": 10.0, "attemptId": "a3"},
               {"circuitId": "2A2", "score": 8.5, "attemptId": "a4"},
               {"circuitId": "2A3", "score": 10.0, "attemptId": "a5"}
             ]},
            {"candidate": {"id": "c-dos", "name": "Segundo Aspirante"},
             "scores": [{"circuitId": "2A2", "score": 8.5, "attemptId": "at-dos"}]},
            {"candidate": {"id": "c-tres", "name": "Tercero Aspirante"}, "scores": []}
          ]
        }
        """.utf8)
        return try JSONDecoder().decode(MatrixResponseDTO.self, from: json)
    }

    private func json(_ values: [String]) throws -> String {
        String(decoding: try JSONEncoder().encode(values), as: UTF8.self)
    }

    // MARK: - Las columnas

    /// The columns are the matrix's, straight through.
    ///
    /// This client briefly derived them by crossing the ranking's
    /// `requiredRoutes`, because the matrix only returned circuits somebody had
    /// driven — five of the ten required — and hid exactly the columns that
    /// explain each grade. The defect was in `get_matrix_data` and was fixed
    /// there; deriving it here now would duplicate logic the backend resolves
    /// with the same canonical sanitiser the ranking uses, which is what keeps
    /// the two halves of this screen from diverging.
    @Test func columnsComeStraightFromTheMatrix() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())

        #expect(data.circuits.map(\.id) == requiredRoutes)
        #expect(data.realCircuitCount == 10)
        #expect(data.circuits.allSatisfy { $0.isRequired })
        #expect(data.hasUndrivenRequiredColumn)
    }

    /// A required column with no grade must be reported as such — but from the
    /// column's own `required`, not deduced from the absence of grades. A
    /// PRACTICE route can end up in the required set
    /// (`_rutas_exigidas_validas` does not check `Route.categoria`) and come
    /// out empty even for whoever drove it.
    @Test func onlyRequiredColumnsCountAsUndriven() throws {
        let json = Data("""
        {"convocatoria": {"id": "conv-1", "name": "X", "status": "OPEN", "description": null,
          "totalCandidates": 1, "closedAt": null, "updatedAt": null},
         "circuits": [{"id": "1A", "label": "1A", "required": true, "synthetic": false},
                      {"id": "9Z", "label": "9Z Suelta", "required": false, "synthetic": false}],
         "rows": [{"candidate": {"id": "c-jaime", "name": "Primero Aspirante"},
                   "scores": [{"circuitId": "1A", "score": 7.0, "attemptId": "x1"}]}]}
        """.utf8)
        let matrix = try JSONDecoder().decode(MatrixResponseDTO.self, from: json)

        let data = ResultadosData.merge(ranking: try ranking(), matrix: matrix)

        // 9Z está vacía pero no es exigida: no cuenta.
        #expect(!data.hasUndrivenRequiredColumn)
    }

    /// The header shows the short id because the label is now the route's real
    /// name, which does not fit a table column. The full name stays reachable.
    @Test func theHeaderShowsTheShortIdAndKeepsTheFullName() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())
        let column = try #require(data.circuits.first { $0.id == "2A2" })

        #expect(column.displayLabel == "2A2")
        #expect(column.fullName == "2A2 Subida y bajada Cruz Verde")
    }

    /// A synthetic column groups attempts with no route. It is real data and
    /// must reach the screen, but its invented id («U00») may never pass for a
    /// route name, and it is not a required route either.
    @Test func theSyntheticColumnNamesItselfHonestly() throws {
        let json = Data("""
        {"convocatoria": {"id": "conv-1", "name": "X", "status": "OPEN", "description": null,
          "totalCandidates": 1, "closedAt": null, "updatedAt": null},
         "circuits": [{"id": "U00", "label": "U00", "required": false, "synthetic": true},
                      {"id": "1A", "label": "1A", "required": true, "synthetic": false}],
         "rows": [{"candidate": {"id": "c-jaime", "name": "Primero Aspirante"},
                   "scores": [{"circuitId": "U00", "score": 7.0, "attemptId": "u1"}]}]}
        """.utf8)
        let withSynthetic = try JSONDecoder().decode(MatrixResponseDTO.self, from: json)

        let data = ResultadosData.merge(ranking: try ranking(), matrix: withSynthetic)

        #expect(data.circuits.contains { $0.isSynthetic })
        let synthetic = try #require(data.circuits.first { $0.isSynthetic })
        #expect(synthetic.displayLabel == "Sin recorrido")
        #expect(synthetic.fullName == "Sin recorrido asignado")
        // No cuenta como recorrido real ni como columna exigida vacía.
        #expect(data.realCircuitCount == 1)
    }

    // MARK: - Las filas

    @Test func rankedRowsComeInMeritOrder() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())

        #expect(data.ranked.map(\.position) == [1, 2])
        #expect(data.ranked.first?.name == "Primero Aspirante")
        #expect(data.ranked.first?.score == 4.75)
        #expect(data.ranked.first?.composition?.completedRequired == 5)
    }

    /// Whoever has not driven is listed apart. Mixed in, they would take a
    /// place in an order of merit they are not part of.
    @Test func whoeverHasNotDrivenIsSetApart() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())

        #expect(data.notPresented.map(\.name) == ["Tercero Aspirante"])
        #expect(data.notPresented.first?.score == nil)
        #expect(data.notPresented.first?.composition == nil)
        #expect(data.totalCandidates == 3)
    }

    @Test func eachCellFindsItsCircuit() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())
        let first = try #require(data.ranked.first)

        #expect(first.byCircuit["1A"]?.score == 10.0)
        #expect(first.byCircuit["2A2"]?.attemptId == "a4")
        // Exigido, sin conducir: no hay celda, y la tabla pinta «—».
        #expect(first.byCircuit["3B"] == nil)
    }

    // MARK: - Cuando una fuente falla

    /// The matrix is optional on purpose: an instructor who only needs to know
    /// who is ahead should not lose the screen because one endpoint is down.
    @Test func theOrderSurvivesWithoutTheMatrix() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: nil)

        #expect(data.ranked.count == 2)
        #expect(data.ranked.first?.score == 4.75)
        // Sin matriz no hay columnas —eran de ella—, pero el orden de méritos
        // y la composición de cada nota siguen en pie, que es lo que hace útil
        // la pantalla cuando ese endpoint falla.
        #expect(data.circuits.isEmpty)
        #expect(data.ranked.first?.composition?.completedRequired == 5)
        #expect(data.ranked.first?.byCircuit.isEmpty == true)
    }

    /// A candidate present in the matrix and absent from the ranking must not
    /// be dropped. The portal keeps an integration test guarding that the two
    /// sources carry the same people, which means they can diverge.
    @Test func nobodyIsLostWhenTheSourcesDiverge() throws {
        let json = Data("""
        {"convocatoria": {"id": "conv-1", "name": "X", "status": "OPEN", "description": null,
          "totalCandidates": 1, "closedAt": null, "updatedAt": null},
         "circuits": [{"id": "1A", "label": "1A", "required": true, "synthetic": false}],
         "rows": [{"candidate": {"id": "c-fantasma", "name": "Cuarto Aspirante"},
                   "scores": [{"circuitId": "1A", "score": 6.0, "attemptId": "f1"}]}]}
        """.utf8)
        let divergent = try JSONDecoder().decode(MatrixResponseDTO.self, from: json)

        let data = ResultadosData.merge(ranking: try ranking(), matrix: divergent)

        let names = (data.ranked + data.notPresented).map(\.name)
        #expect(names.contains("Cuarto Aspirante"))
    }

    // MARK: - RGPD art. 22

    /// Nothing derived here may state an outcome, and the grade of someone who
    /// never drove must stay absent rather than render as a measured zero.
    @Test func nothingImpliesAVerdict() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())

        for row in data.notPresented {
            #expect(row.score == nil, "\(row.name) enseñaría un cero que nadie midió")
            #expect(row.position == nil)
        }
        let text = (data.ranked + data.notPresented)
            .map { "\($0.name) \($0.plaza ?? "")" }
            .joined(separator: " ")
            .lowercased()
        for banned in ["apto", "suspens", "aprob", "corte", "cupo"] {
            #expect(!text.contains(banned))
        }
    }
}
