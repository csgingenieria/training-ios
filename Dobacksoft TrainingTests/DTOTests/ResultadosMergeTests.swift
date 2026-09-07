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

    /// The matrix returns only circuits with at least one attempt — five, in
    /// the real convocatoria, against the ten the process requires.
    private func matrix() throws -> MatrixResponseDTO {
        let json = Data("""
        {
          "convocatoria": {
            "id": "conv-1", "name": "Oposición Conductores 2026", "status": "OPEN",
            "description": null, "totalCandidates": 4, "closedAt": null,
            "updatedAt": "2026-09-04T14:34:37.964306Z"
          },
          "circuits": [
            {"id": "1A", "label": "1A", "synthetic": false},
            {"id": "1B", "label": "1B", "synthetic": false},
            {"id": "2A1", "label": "2A1", "synthetic": false},
            {"id": "2A2", "label": "2A2", "synthetic": false},
            {"id": "2A3", "label": "2A3", "synthetic": false}
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

    /// **The rule that matters.** The matrix hides the required circuits nobody
    /// has driven, which are exactly the ones dragging every grade down. A
    /// table showing five nines and tens beside an official 4,75 argues the
    /// opposite of what is happening.
    @Test func columnsAreTheUnionOfBothSources() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())

        #expect(data.circuits.map(\.id) == requiredRoutes)
        #expect(data.realCircuitCount == 10)
        #expect(data.hasUndrivenRequiredColumn)
    }

    /// Required routes keep the order the convocatoria declares them in, not
    /// the order the matrix happens to return.
    @Test func requiredRoutesKeepTheirDeclaredOrder() throws {
        let data = ResultadosData.merge(ranking: try ranking(), matrix: try matrix())

        #expect(data.circuits.prefix(5).map(\.id) == ["1A", "1B", "2A1", "2A2", "2A3"])
        #expect(data.circuits.suffix(5).map(\.id) == ["2B1", "2B2", "2B3", "3A", "3B"])
    }

    /// A synthetic column groups attempts with no route. It is real data and
    /// must survive the merge, but it is not a required route, so it goes last.
    @Test func theSyntheticColumnGoesLast() throws {
        let json = Data("""
        {"convocatoria": {"id": "conv-1", "name": "X", "status": "OPEN", "description": null,
          "totalCandidates": 1, "closedAt": null, "updatedAt": null},
         "circuits": [{"id": "U00", "label": "U00", "synthetic": true},
                      {"id": "1A", "label": "1A", "synthetic": false}],
         "rows": [{"candidate": {"id": "c-jaime", "name": "Primero Aspirante"},
                   "scores": [{"circuitId": "U00", "score": 7.0, "attemptId": "u1"}]}]}
        """.utf8)
        let withSynthetic = try JSONDecoder().decode(MatrixResponseDTO.self, from: json)

        let data = ResultadosData.merge(ranking: try ranking(), matrix: withSynthetic)

        #expect(data.circuits.last?.isSynthetic == true)
        #expect(data.circuits.last?.displayLabel == "Sin recorrido")
        // 10 exigidos + la sintética; no cuenta como recorrido real.
        #expect(data.circuits.count == 11)
        #expect(data.realCircuitCount == 10)
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
        // Sin matriz, las columnas siguen siendo las que exige la convocatoria.
        #expect(data.circuits.map(\.id) == requiredRoutes)
        #expect(data.ranked.first?.byCircuit.isEmpty == true)
    }

    /// A candidate present in the matrix and absent from the ranking must not
    /// be dropped. The portal keeps an integration test guarding that the two
    /// sources carry the same people, which means they can diverge.
    @Test func nobodyIsLostWhenTheSourcesDiverge() throws {
        let json = Data("""
        {"convocatoria": {"id": "conv-1", "name": "X", "status": "OPEN", "description": null,
          "totalCandidates": 1, "closedAt": null, "updatedAt": null},
         "circuits": [{"id": "1A", "label": "1A", "synthetic": false}],
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
