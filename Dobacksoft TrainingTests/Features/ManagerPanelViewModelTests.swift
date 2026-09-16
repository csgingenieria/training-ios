import Testing
import Foundation

@testable import Dobacksoft_Training

/// El panel del instructor.
///
/// **Era la superficie con más lógica del área del instructor sin una sola
/// prueba de comportamiento**, y no por descuido de criterio sino por una
/// dependencia: el modelo de vista usaba `APIClient.shared` directamente, así
/// que el doble de red no podía devolverle nada. La costura llegó tarde porque
/// el resto de los modelos la fueron recibiendo uno a uno, según hizo falta
/// probar cada arreglo, y este se quedó fuera.
///
/// Lo que aquí se prueba es justo lo que no se veía: que un fallo al indexar el
/// censo **no** tumba el panel, que la cobertura parcial se declara en vez de
/// afirmar un número que nadie ha medido, y que el tope de convocatorias
/// consultadas se respeta —porque el endpoint de ranking va limitado por minuto
/// y esta pantalla se refresca al tirar hacia abajo.
extension KeychainBacked {
    @MainActor
    struct ManagerPanelViewModelTests {
        init() { try? TokenStore.clearAll() }

        // MARK: - Andamiaje

        private func session(_ api: FakeTrainingAPI) async throws -> AuthSession {
            await api.setLoginResult(.success(.stub(access: "acc", refresh: "ref")))
            let session = AuthSession(api: api)
            try await session.login(email: "instructor@cmadrid.example", password: "x")
            return session
        }

        private func dashboard() -> ManagerDashboardDTO {
            ManagerDashboardDTO(
                activeConvocatorias: 2, totalCandidates: 40, totalParticipants: 31,
                attemptsToday: 5, attemptsThisWeek: 22,
                lastWebfleetSyncAt: nil, convocatoriasWithLowQuality: 0
            )
        }

        private func convocatoria(_ id: String, _ name: String) -> ConvocatoriaSummaryDTO {
            ConvocatoriaSummaryDTO(
                id: id, name: name, description: nil, status: "OPEN",
                totalCandidates: 0, closedAt: nil, updatedAt: nil
            )
        }

        private func ranking(
            _ convocatoria: ConvocatoriaSummaryDTO,
            _ gente: [(id: String, nombre: String, conducido: Bool)]
        ) -> RankingResponseDTO {
            RankingResponseDTO(
                convocatoria: convocatoria,
                entries: gente.map { persona in
                    RankingEntryDTO(
                        position: persona.conducido ? 1 : nil,
                        candidate: RankingCandidateDTO(
                            id: persona.id, name: persona.nombre, plaza: nil
                        ),
                        score: persona.conducido ? 7.5 : nil,
                        attemptsCompleted: persona.conducido ? 3 : 0,
                        attemptsTotal: 3, attemptId: nil, presented: nil, tied: nil,
                        requiredRoutes: nil, completedRequired: nil,
                        pendingRequired: nil, scoreOfCompleted: nil
                    )
                }
            )
        }

        // MARK: - La carga

        @Test func elPanelCargaLosAgregadosYElCenso() async throws {
            let api = FakeTrainingAPI()
            let c1 = convocatoria("c1", "Oposición 2026")
            await api.setManagerDashboardResults([.success(dashboard())])
            await api.setConvocatoriasResults([.success([c1])])
            await api.setRankingResults([.success(ranking(c1, [
                ("s1", "Ana Muñoz", true),
                ("s2", "Luis Pérez", false)
            ]))])

            let vm = ManagerPanelViewModel(api: api)
            await vm.load(auth: try await session(api))

            guard case .loaded(let d, let convs) = vm.state else {
                Issue.record("Se esperaba el panel cargado, y llegó \(vm.state)")
                return
            }
            #expect(d.totalCandidates == 40)
            #expect(convs.count == 1)
            #expect(vm.aspirantes.count == 2)
            #expect(vm.pendientes.map(\.name) == ["Luis Pérez"])
            #expect(vm.coverage.esCompleta)
            #expect(vm.coverage.aviso == nil)
        }

        /// El censo es información complementaria: perder los agregados porque
        /// no se pudo leer un ranking sería un mal negocio.
        @Test func unRankingQueFallaNoTumbaElPanel() async throws {
            let api = FakeTrainingAPI()
            await api.setManagerDashboardResults([.success(dashboard())])
            await api.setConvocatoriasResults([.success([convocatoria("c1", "Oposición 2026")])])
            await api.setRankingResults([.failure(APIError.transport(URLError(.timedOut)))])

            let vm = ManagerPanelViewModel(api: api)
            await vm.load(auth: try await session(api))

            if case .loaded = vm.state {} else {
                Issue.record("El panel tenía que seguir cargado, y quedó \(vm.state)")
            }
            #expect(vm.aspirantes.isEmpty)
            #expect(vm.coverage.fallidas == 1)
        }

        /// **El caso de control del anterior.** Si el panel se cayera también
        /// cuando el dashboard falla de verdad, la prueba de arriba no estaría
        /// demostrando que el fallo del ranking es benigno: estaría demostrando
        /// que nada rompe nunca.
        @Test func unDashboardQueFallaSiTumbaElPanel() async throws {
            let api = FakeTrainingAPI()
            await api.setManagerDashboardResults([.failure(APIError.transport(URLError(.timedOut)))])
            await api.setConvocatoriasResults([.success([])])

            let vm = ManagerPanelViewModel(api: api)
            await vm.load(auth: try await session(api))

            guard case .error = vm.state else {
                Issue.record("Un dashboard caído tiene que dejar el panel en error, y quedó \(vm.state)")
                return
            }
        }

        // MARK: - Lo que no se ha medido no se afirma

        /// Con más convocatorias que el tope, el índice queda corto **y lo
        /// dice**. Sin este aviso la pantalla diría «sin conducir: 18» como si
        /// fuera un hecho, cuando es el resultado de no haber mirado.
        @Test func laCoberturaParcialSeDeclara() async throws {
            let api = FakeTrainingAPI()
            let cs = (1...5).map { convocatoria("c\($0)", "Convocatoria \($0)") }
            await api.setManagerDashboardResults([.success(dashboard())])
            await api.setConvocatoriasResults([.success(cs)])
            await api.setRankingResults(cs.map { .success(ranking($0, [])) })

            let vm = ManagerPanelViewModel(api: api)
            await vm.load(auth: try await session(api))

            #expect(vm.coverage.disponibles == 5)
            #expect(!vm.coverage.esCompleta)
            let aviso = try #require(vm.coverage.aviso)
            #expect(aviso.contains("5"))
        }

        /// El tope no es decorativo: el endpoint de ranking va limitado por
        /// minuto y el panel se refresca al tirar hacia abajo.
        @Test func noSeConsultanMasConvocatoriasQueElTope() async throws {
            let api = FakeTrainingAPI()
            let cs = (1...5).map { convocatoria("c\($0)", "Convocatoria \($0)") }
            await api.setManagerDashboardResults([.success(dashboard())])
            await api.setConvocatoriasResults([.success(cs)])
            await api.setRankingResults(cs.map { .success(ranking($0, [])) })

            let vm = ManagerPanelViewModel(api: api)
            await vm.load(auth: try await session(api))

            let consultadas = await api.rankingRequests
            #expect(consultadas.count == 3, "Se consultaron \(consultadas.count) rankings")
        }

        /// Fallaron todas: eso no es un índice corto, es no tener índice, y el
        /// aviso tiene que distinguirlo.
        @Test func siFallanTodasElAvisoNoDiceQueSeaParcial() async throws {
            let api = FakeTrainingAPI()
            let cs = (1...2).map { convocatoria("c\($0)", "Convocatoria \($0)") }
            await api.setManagerDashboardResults([.success(dashboard())])
            await api.setConvocatoriasResults([.success(cs)])
            await api.setRankingResults(cs.map { _ in .failure(APIError.transport(URLError(.timedOut))) })

            let vm = ManagerPanelViewModel(api: api)
            await vm.load(auth: try await session(api))

            let aviso = try #require(vm.coverage.aviso)
            #expect(aviso.contains("No se ha podido consultar"))
            #expect(!aviso.contains("parcial"))
        }

        // MARK: - La sincronización

        @Test func elLimiteDePeticionesSeExplicaConSuEspera() async throws {
            let api = FakeTrainingAPI()
            await api.setSyncResults([.failure(APIError.rateLimited(retryAfter: 45))])

            let vm = ManagerPanelViewModel(api: api)
            await vm.triggerSync(auth: try await session(api))

            let mensaje = try #require(vm.syncErrorMessage)
            #expect(mensaje.contains("45"))
            #expect(vm.syncResult == nil)
            #expect(!vm.isSyncing)
        }

        /// Sin segundos, el mensaje no puede inventárselos.
        @Test func elLimiteSinEsperaConocidaNoInventaUnNumero() async throws {
            let api = FakeTrainingAPI()
            await api.setSyncResults([.failure(APIError.rateLimited(retryAfter: nil))])

            let vm = ManagerPanelViewModel(api: api)
            await vm.triggerSync(auth: try await session(api))

            let mensaje = try #require(vm.syncErrorMessage)
            #expect(mensaje.contains("minuto"))
        }

        /// Un límite de peticiones **no se reintenta**: reintentar es
        /// exactamente lo que el servidor está pidiendo que no se haga.
        @Test func elLimiteDePeticionesNoSeReintenta() async throws {
            let api = FakeTrainingAPI()
            await api.setSyncResults([.failure(APIError.rateLimited(retryAfter: 30))])

            let vm = ManagerPanelViewModel(api: api)
            await vm.triggerSync(auth: try await session(api))

            let llamadas = await api.syncCalls
            #expect(llamadas == 1, "Se llamó \(llamadas) veces a la sincronización")
        }
    }
}
