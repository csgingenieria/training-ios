# SDD Explore — iOS Training tras reunion remota

**Fecha**: 2026-05-24  
**Repo**: `training-ios` (`/Users/antoniohermoso/IOS/Dobacksoft Training`)  
**Trigger**: despues de la reunion remota, la Comunidad de Bomberos recibe muy bien la app y el track iOS pasa de "personal/piloto" a candidato serio para demo/piloto controlado.  
**Scope**: exploracion; no cambia contrato backend ni convierte la app en entregable oficial.

## 1. Contexto nuevo

La app ya no debe tratarse solo como experimento personal. La reunion remota valida que la experiencia nativa tiene valor para usuarios bomberos y puede convertirse en una pieza de demostracion o piloto si Antonio lo decide.

La regla vigente sigue siendo la de `CLAUDE.md`: este repo es privado, separado del repo `training`, y fuera del entregable oficial salvo decision nueva explicita. Si la app entra en circuito CMadrid/equipo, hace falta una decision nueva tipo `D-IOS-002` que declare el cambio de estado.

## 2. Estado actual de la app iOS

### Implementado

- Arranque SwiftUI con `RootView` y `AuthSession` en environment.
- Login por email/password contra `POST /api/v1/auth/login`.
- Persistencia de `accessToken` y `refreshToken` en Keychain.
- Restauracion de sesion en frio con pantalla de carga.
- Refresh de access token durante restore si el access token persistido ya expiro.
- Dashboard con tabs:
  - `Convocatorias`
  - `Mi posicion` solo para `STUDENT`
  - `Perfil`
- Lista de convocatorias:
  - `STUDENT`: `/api/v1/me/convocatorias`
  - `MANAGER/ADMIN/SUPER_ADMIN`: `/api/v1/convocatorias`
- Detalle basico de convocatoria.
- Standing individual de alumno con `/api/v1/me/convocatorias/<id>/standing`.
- Ranking completo para roles admin-like con `/api/v1/convocatorias/<id>/ranking`.
- Detalle de intento con `/api/v1/attempts/<id>`, aunque la navegacion hacia esa pantalla todavia depende de que exista un `attemptId` en algun flujo previo.

### Validacion tecnica

- Build Xcode exitoso el 2026-05-24.
- Tests unitarios y UI siguen en plantilla.
- No hay configuracion de produccion real; `Release` aun apunta a `https://training.example.com`.

## 3. Contrato backend observado

Fuente real inspeccionada: `app/blueprints/mobile_api/routes.py`, `schemas.py`, `services.py` en el repo `training`.

Endpoints reales disponibles:

- `GET /api/v1/health`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/me`
- `GET /api/v1/me/convocatorias`
- `GET /api/v1/me/convocatorias/<conv_id>/standing`
- `GET /api/v1/convocatorias`
- `GET /api/v1/convocatorias/<conv_id>`
- `GET /api/v1/convocatorias/<conv_id>/ranking`
- `GET /api/v1/convocatorias/<conv_id>/matrix`
- `GET /api/v1/attempts/<attempt_id>`

Observaciones de contrato:

- `docs/MOBILE-API.md` ya no esta en la ruta activa indicada por documentacion antigua; existe archivado en `docs/_archive/2026-05-13/MOBILE-API.md`.
- `docs/API.md` esta desactualizado en mobile: lista `GET /api/v1/auth/login`, pero el backend real implementa `POST`.
- `RankingEntrySchema` no expone `attempt_id`; por eso la app no puede navegar desde ranking a `AttemptDetailView` sin cambio backend o endpoint intermedio.
- El backend conserva la decision GDPR: no expone `withinCutoff`, `apto`, `no_apto`, `passed` ni equivalentes.

## 4. Gaps funcionales

### P0 — Contrato vivo y release target

La app necesita una fuente canonica actual para `/api/v1`. Hoy hay tres fuentes no alineadas: decision `D-API-001`, `docs/API.md` y codigo Flask. Para piloto, el codigo Flask manda, pero hay que congelar un snapshot humano.

Necesidad: actualizar o crear snapshot de contrato mobile v1 en repo `training`, sin editarlo desde iOS.

### P0 — Configuracion de entorno

`AppEnvironment.baseURL` usa `localhost` en debug y placeholder en release. Para demo remota/piloto hace falta una forma segura de apuntar a staging/VPS sin recompilar codigo cada vez.

Opciones:

- `.xcconfig` por build configuration.
- valor en `Info.plist` por scheme.
- selector interno solo para builds de desarrollo.

### P0 — Tests minimos

La app compila, pero no tiene tests reales. El primer set debe cubrir:

- decoding de DTOs contra fixtures del contrato real.
- `APIError.userMessage`.
- flujo de `AuthSession`: login, restore sin tokens, restore con access valido, restore con refresh.
- UI smoke test: arranque muestra login sin token.

### P1 — Navegacion a intento

`AttemptDetailView` existe, pero no hay camino contractual completo desde ranking/standing hacia un `attempt_id`.

Necesidad backend sugerida:

- agregar en ranking o matrix una referencia segura a intento visible para admin-like, por ejemplo `bestAttemptId` o `attemptId` por celda.
- para `STUDENT`, decidir si standing debe incluir `lastAttemptId` o si se agrega endpoint de historial propio.

Esto requiere canal cross-track `cross/api-needs/attempt-navigation`.

### P1 — Matrix mobile

El backend ya tiene `/api/v1/convocatorias/<id>/matrix`, pero la app no lo consume. Para Comunidad de Bomberos puede ser mas demostrativo que el ranking plano porque muestra candidatos vs circuitos/rutas.

Necesidad iOS:

- crear `MatrixDTO`.
- vista `MatrixView` para iPad y iPhone.
- entrada desde `ConvocatoriaDetailView` para admin-like.

### P1 — Experiencia iPad

La app funciona con SwiftUI adaptativo basico, pero no explota iPad. Si la reunion abrio camino a demo, iPad deberia ser el formato de presentacion:

- `NavigationSplitView` para convocatorias/detail.
- ranking/matrix con densidad mayor.
- perfil/debug de API relegado.

### P2 — Pulido visual y lenguaje

La UI actual es correcta pero generica. Para bomberos CMadrid conviene reforzar:

- jerarquia visual de posicion/ranking.
- estados de convocatoria (`OPEN`, `CLOSING`, `CLOSED`) traducidos a etiquetas legibles.
- fechas ISO renderizadas con formato local.
- separacion entre "dato operativo" y "decision final humana" para evitar lectura legal incorrecta.

## 5. Riesgos

- **Riesgo de contrato**: la documentacion mobile no esta sincronizada con codigo real.
- **Riesgo de demo**: release no tiene base URL real.
- **Riesgo legal**: cualquier texto que sugiera apto/no apto desde movil debe evitarse.
- **Riesgo de navegacion**: detalle de intento existe pero no tiene origen contractual.
- **Riesgo de calidad**: sin tests de decoding, un cambio backend rompe silenciosamente en runtime.
- **Riesgo de track**: si la app pasa a piloto oficial sin decision nueva, se rompe la separacion iOS personal vs Training equipo.

## 6. Decision pendiente

Crear decision nueva si Antonio quiere que esta app pase a demo/piloto:

`D-IOS-002 — Estado de training-ios tras validacion remota Comunidad de Bomberos`

Contenido minimo:

- si sigue siendo personal, demo interna, piloto CMadrid o entregable oficial.
- plataformas activas: iPhone, iPad, Watch diferido.
- entorno autorizado: local, staging, VPS.
- quien puede verla y con que datos.
- si se abre comunicacion formal al equipo Training o se mantiene solo Antonio.

## 7. Propuesta de siguiente SDD

Nombre sugerido:

`sdd/ios-pilot-readiness-v1`

Secuencia:

1. `explore`: este documento.
2. `proposal`: definir objetivo de piloto, scope de pantallas y restricciones legales.
3. `spec`: contrato UI/API y escenarios por rol.
4. `design`: arquitectura iOS minima, fixtures de contrato, estrategia de entorno.
5. `tasks`: implementar en pasos pequenos.

Primer bloque implementable recomendado:

1. Congelar fixtures JSON reales del contrato mobile.
2. Tests de decoding y auth session.
3. Configuracion de `baseURL` por scheme.
4. Vista matrix admin-like.
5. Pedir al backend `attempt-navigation` por engram/GitHub solo si Antonio decide que se necesita para piloto.
