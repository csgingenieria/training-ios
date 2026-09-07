# Pedido de contrato: paridad del portal del aspirante en el API móvil v1

**Fecha:** 2026-09-07 (v2, tras verificación adversarial del texto contra el código del backend)
**Origen:** repo `training-ios` (cliente nativo iOS, entregable oficial a CMadrid — `D-IOS-002`)
**Destino:** repo `training`, blueprint `app/blueprints/mobile_api/`
**Decide:** Antonio (único enlace humano entre los dos tracks)

---

## Por qué

La app iOS tiene cliente para **los 16 endpoints** que expone `mobile_api` hoy y consume 15 en
pantalla: `GET /convocatorias/<id>` está implementado (`APIClient.convocatoriaDetail`,
`Core/API/APIClient.swift:71`) pero ninguna vista lo llama; el detalle de convocatoria se alimenta
del DTO de la lista. El techo del cliente no es Swift: es el contrato.

La decisión de producto es cerrar **paridad total del portal del aspirante** (`app/blueprints/student/`),
porque son 256 aspirantes contra 2-3 instructores. El portal del instructor queda para una fase
posterior y **no** forma parte de este pedido.

El portal del aspirante (blueprint `student`, montado en `/alumno` por `app/__init__.py:342`; en
este documento `/student/...` nombra la ruta del blueprint, no la URL pública) tiene 9 vistas
reales: 7 pantallas, el JSON `/intento/<id>/gps` que alimenta el mapa de la ficha y 2 PDFs
(`/historial` y `/evolucion` son redirect 302 a `/progreso`, no cuentan). Quitando los 2 PDFs
quedan **7 en alcance** (una de ellas, el JSON del mapa, no es pantalla sino el endpoint que la
ficha consume). De esas, el cliente nativo tiene **3 parciales** (panel sin tarjeta ni resumen por
recorrido —ese resumen lo cubre `evolution[]` del bloque A—, ficha de intento sin los cuatro
bloques de conducción, perfil solo lectura) y le faltan **4 enteras** (progreso, mapa GPS, detalle
por recorrido, PIN). Tanto las 4 que faltan como los huecos de las 3 parciales están bloqueados por
contrato: no hay endpoint que los sirva.

**Fuera de alcance por decisión explícita de Antonio (2026-09-07):** los PDFs
(`/alumno/intento/<id>/pdf`, `/alumno/evolucion.pdf`; ambas responden 404 salvo
`FEATURE_PDF_EXPORTS=true`, que por defecto es `false` — `student/routes.py:487`, `:506`,
`app/config.py:532-533`) no se piden. No se van a implementar en el cliente.

**Dentro de alcance por decisión explícita de Antonio (2026-09-07):** la tarjeta del aspirante
(bloque E). Entra aunque no estaba en el foco inicial, porque el caso de uso es más móvil que web
y el coste es casi nulo.

**Pendiente registrado, no pedido en esta ronda (para que «paridad total» sea una afirmación honesta):**

- **Perfil editable.** `/student/perfil` (`student/routes.py:361-443`) permite al STUDENT cambiar
  nombre, foto, fecha de nacimiento y género, y muestra `id_card_number`, organización y
  `passwordChangedAt`; `GET /me` expone solo `id/email/name/role/organizationId/studentProfileId`
  (`schemas.py:18-24`). No se pide `PATCH /me/profile` ni subida de foto en esta fase.
- **Panel por recorrido.** El dashboard web pinta una tarjeta por recorrido del catálogo con mejor
  intento y estado «esperando» (`student_service.py:730-742`), más `candidato.sesiones/ultima` y
  `convocatoria.nota_definitiva`. `evolution[]` del bloque A cubre la mayor parte; lo que no cubra
  queda para una ronda posterior.
- **Cierre de sesión y recuperación de contraseña.** El portal enlaza `POST /auth/logout` (cookies)
  y `/auth/recuperar` (`auth/routes.py:535`); `mobile_api` no tiene revocación de refresh token.
  El cliente borra tokens localmente; no se pide nada aquí.

---

## Restricciones que este pedido NO negocia

1. **RGPD art. 22 — vocabulario prohibido.** Ninguna respuesta puede traer `APTO`/`NO APTO`,
   «aprobado», «suspenso», «admitido», «excluido», «línea de corte», `withinCutoff`, ni
   `plazas`/`totalPlazas`. El sistema calcula una nota objetiva; no emite veredicto.

   `plaza` en singular **sí puede viajar**: es `Enrollment.plazaNumber`, el número de inscripción
   que el aspirante teclea en la tablet (`student_service.py:216-222`, `_plaza_for`: «plaza
   PERSISTENTE (plazaNumber), no posición»), y ya lo expone `RankingEntrySchema.candidate.plaza`
   (`mobile_api/services.py:236`). Lo prohibido es el cupo (`plazas`, `totalPlazas`). En las
   respuestas nuevas, `null` en vez del centinela `"—"` que usa la web.

2. **Guard GDPR por rol.** Mismo criterio que `remap_attempt(attempt_dict, caller_role=...)` ya
   aplica: con `caller_role == STUDENT` se filtran los eventos Webfleet nativos
   (`HARSH_*`, `IDLE_EXCEPTION`). Todo endpoint nuevo que devuelva eventos debe respetarlo
   (atención: el payload del mapa usa la clave `type`, no `tipo` — ver bloque B).

3. **Read-only.** Salvo los endpoints de cuenta (bloque F), todo lo pedido es `GET`.
   El cliente no escribe nada que toque la nota.

4. **Un aspirante puede tener varias inscripciones.** `student/routes.py:162-174` (comentario
   dentro de `progreso()`) documenta que **en producción hay uno con dos** (comprobado). Todo
   endpoint con dimensión de convocatoria acepta `conv_id` opcional y, sin él, cae a la primera
   inscripción activa — mismo patrón que `dashboard()` y `progreso()`.

   «Activa» en los servicios del portal significa `EnrollmentStatus.ACTIVE`
   (`student_service.py:225-232`, `:1422-1430`), que es **más estricto** que el
   `status != INVALIDATED` que usa `/me/convocatorias/<id>/standing` (`mobile_api/routes.py:139`):
   un aspirante con inscripción `COMPLETED` tiene standing hoy pero recibiría «sin inscripción» de
   `/me/progress` y `/me/routes/<code>`. Pedimos que el backend elija un criterio y lo diga;
   aceptamos cualquiera de los dos. Sin inscripción que cumpla el criterio: `404 not_enrolled`,
   mismo código que `me_standing` (`routes.py:144`), no un 500 sobre `ctx["candidato"]` ni un 200
   vacío sin documentar.

5. **Guard por rol, mismo patrón que el blueprint.** A `/me/progress`, D `/me/routes/<code>`,
   E `/me/card`, F `/me/pin` → `@require_role(["STUDENT"])` como `me_standing`
   (`mobile_api/routes.py:126`). B `/attempts/<id>/gps` → `@jwt_required()` +
   `can_user_view_attempt` + 404 como `/attempts/<id>` (`:382-383`), para que el instructor
   también pueda abrir el mapa. F `/me/password`, `/me/email` → `@jwt_required()` cualquier rol,
   como `/auth/change-*`. Tests en `tests/api/test_mobile_api.py`; añadir los endpoints nuevos a
   `test_ninguna_respuesta_expone_plazas_ni_total_plazas` (`:953`), que enumera endpoints a mano.

---

## Lo que se pide

Cada bloque nombra el servicio que **ya existe** en el backend. Ninguno pide lógica nueva de
dominio: son adaptadores JSON de vistas que ya funcionan en la web. Todo camelCase con fechas
ISO 8601: los dicts de la vista son para Jinja y `mobile_api` no los reutiliza directo
(`services.py:9-10`).

### A. `GET /api/v1/me/progress` — LA PRIORITARIA

Reemplaza la pantalla `/student/progreso`. El cliente ya muestra dos de sus tres mitades por otros
endpoints (el historial de intentos vía `GET /me/convocatorias/<id>/attempts` y la composición de
la nota vía `/standing`, ambas en `StandingView`); lo que no tiene en absoluto es la evolución por
recorrido (`evolucion[]`, `mejor`/`peor`, tendencia) ni un booleano explícito de «tiene nota» (hoy
`/standing` responde `404 no_standing_yet`, `mobile_api/routes.py:162`). Es la pantalla más grande
que falta y la que más piden los aspirantes: *«cómo voy»*.

- **Query param:** `conv_id` (opcional).
- **Servicios existentes:** `get_student_historial(student_id, org_id, conv_id=None)`
  (`app/blueprints/student/student_service.py:1013`) y
  `get_student_evolucion(student_id, org_id, conv_id=None)` (`student_service.py:1102`). Ambos
  viven en el blueprint `student`, no en `app/services/`: el adaptador de `mobile_api` tendrá que
  importarlos entre blueprints o la lógica moverse. Los dos devuelven `None` cuando no hay
  inscripción `ACTIVE` (ver restricción 4).
- **Campos de primer nivel que la vista web ya recibe y el cliente necesita:**
  - `attempts[]` — el historial (`ctx_h["intentos"]`).
  - `evolution[]` — la serie por recorrido para el gráfico (`ctx_e["evolucion"]`).
  - `score` (`nota_media`) y **`presented`** (`tiene_nota`, que el servicio deriva de
    `metricas["presentado"]`, `student_service.py:1165`). Mismos nombres que `StandingSchema.score`
    y `RankingEntrySchema.presented` (`mobile_api/schemas.py:100`): el cliente ya lee `presented`
    en `RankingEntryDTO` y no quiere dos nombres para el mismo booleano.
    `presented` es obligatorio: `canonical_nota` devuelve `0.0` tanto para un cero real como
    para «todavía nada», y sin el booleano la pantalla escribe un «0,0» a quien no ha sido
    calificado — que es peor que no escribir nada.
  - `requiredRoutes` (**lista de códigos**, `[String] | null`, obtenida de
    `ranking_common.rutas_exigidas_de_matricula(enrollment.id)` — **no** de `recorridos_exigidos`,
    que en `ranking_common.py:304` es `len(exigidas)`, un entero; con ese nombre y ese tipo
    colisionaría con el `fields.List(fields.String(), allow_none=True)` que `StandingSchema`,
    `RankingEntrySchema` y `ProfileStandingSchema` ya declaran en `schemas.py:75`, `:92`, `:214`),
    `completedRequired` (`recorridos_conducidos`), `pendingRequired` (`recorridos_pendientes`),
    `scoreOfCompleted` (`nota_de_lo_conducido`). Mismos nombres y tipos que `StandingSchema`
    (`schemas.py:75-80`): el cliente decodifica los cuatro en `GradeComposition`
    (`Core/Models/GradeComposition.swift:20-30`) y reutiliza esa vista; un segundo vocabulario
    para los mismos cuatro números obligaría a un segundo DTO.
    Los cuatro son lo que explica la nota oficial desde #845 cuando la convocatoria declara
    recorridos exigidos (`canonical_nota`, `ranking_common.py:155-159`); si no declara ninguno,
    `canonical_nota` cae al mejor intento global (H7, `:151-153`) y `requiredRoutes` viaja `null`,
    régimen que el cliente ya modela con `GradeComposition.isGlobalBest`. Con exigidos: media del
    mejor intento por recorrido exigido, contando 0 los no conducidos. Sin ellos la pantalla no
    puede explicar el número.
  - `best` (`mejor`) y `worst` (`peor`).
  - `candidate`, `convocatoria`, `activeEnrollments[]`.

**Forma del JSON:**

- `attempts[]`: `{attemptId, route{id, label, name}, score | null, state, dataQuality, endedAt,
  isCurrentBest, distanceKm, durationMin}`. `state` es un enum nuevo y cerrado:
  `CON_NOTA | ESPERANDO | NO_EVALUABLE` (`student_service.py:186-199`, `_estado_intento`); el
  cliente lo congela en `ContractEnumFreezeTests`, así que cualquier valor nuevo se avisa antes.
  `isCurrentBest` ← `es_actual`. `fecha`/`hora` (dd/mm/yyyy, HH:MM; `:1077-1078`) se sustituyen
  por un `endedAt` ISO.
- **Duplicidad a resolver:** `GET /me/convocatorias/<id>/attempts` ya lista intentos
  (`mobile_api/services.py:200-212`: solo `CLOSED`, orden `createdAt`) mientras
  `get_student_historial` incluye `CLOSED` y `PROCESSING` ordenados por `endTime`
  (`student_service.py:1031-1039`). Preferimos (a): `attempts[]` de `/me/progress` reutiliza
  `AttemptSummarySchema` más `state` e `isCurrentBest`, y el endpoint existente pasa a incluir
  `PROCESSING` con los mismos dos campos (aditivo, `allow_none`). Si el backend prefiere (b) —
  `/me/progress` sin `attempts[]` y el cliente sigue usando la lista existente — también sirve;
  lo que no sirve es que dos endpoints devuelvan dos listas distintas al mismo aspirante.
- `evolution[]`: `{routeCode, label, score, previousScore, trend, diffVsBest, attemptId}`. `trend`
  es el segundo enum nuevo (`subiendo | bajando | estable | primer`, o su traducción; que quede
  fijado). Se descartan `icono`, `color` y `texto_tendencia` (`:1217-1219`: clases Phosphor,
  nombres de color y frases en castellano para la plantilla). `diff_media` se llama así «por
  compat» y ya significa diferencia contra la mejor nota (`:1221`), de ahí `diffVsBest`.
- `best` / `worst`: `{routeCode, label, score, attemptId} | null` (en la vista son entradas
  completas de `evolucion`, `:1225-1226`).
- `candidate`: `{id, name, plaza | null}` (ver restricción 1).

### B. `GET /api/v1/attempts/<attempt_id>/gps`

La traza del recorrido. En un móvil esto es MapKit nativo — es la pantalla con más margen de
mejora frente a la web de todo el portal.

- **Servicio existente:** `build_gps_map_payload(attempt, org)` en
  `app/services/attempt_detail.py:1268`, el **mismo** builder que usa `student.intento_gps`
  (`student/routes.py:284`, `:298`). **No** usar `build_attempt_gps_payload` (`:1129`): es el del
  manager, su docstring (`:1273-1277`) avisa de que los dos builders no se comparten, y su payload
  difiere (los eventos del aspirante llevan `stability_loss_percent`, `narrativa` y `consejo`,
  `:1401-1403`, que el del manager no trae; los waypoints salen de `attempt.routeId`, no de un
  `route_id` que pase el cliente). Devuelve cuatro claves: `points`, `route`, `events` y `track`
  (`:1414`) — `track` es la traza ajustada a la calzada y es la que hay que dibujar; `points` es
  el respaldo cuando `track` viene vacío.
- **Autorización:** reusar `can_user_view_attempt(user, attempt)`, igual que
  `GET /attempts/<id>`. Y **404, no 403**, cuando no es del solicitante — no filtrar
  existencia, mismo criterio que el endpoint de detalle (la web devuelve 403 en
  `student/routes.py:293`; el móvil no debe copiarlo).
- **Guard GDPR:** el payload trae `events[]` con la clave `type`, no `tipo`, así que
  `remap_attempt` (que filtra `ev.get("tipo")`, `mobile_api/services.py:320`) **no sirve tal
  cual**. Con `caller_role == STUDENT`, filtrar `payload["events"]` por `type` contra
  `_GDPR_BLOCKED_EVENT_TYPES_STUDENT` (`services.py:288`), exactamente como hace
  `student/routes.py:300-304`. MANAGER/ADMIN/SUPER_ADMIN: sin filtro, igual que `/attempts/<id>`.
- **Nota:** el docstring de `student/intento/<id>/gps` avisa de que la versión anterior
  consumía `kiosko.intento_gps`, que autoriza por la sesión de la tablet y no por el JWT del
  alumno → el mapa salía vacío. El endpoint móvil debe autorizar por JWT.

**Remap, no passthrough.** El payload del builder es snake_case y castellano (`penalty_points`,
`aplica_a_nota`, `motivo_no_penaliza`, `stability_loss_percent`, `narrativa`, `consejo`;
`attempt_detail.py:1396-1403`). Se pide un `remap_gps_payload(payload, caller_role=...)` en
`mobile_api/services.py` con su `GpsPayloadSchema`, camelCase, cuyos eventos reutilicen los
nombres de `AttemptDetailSchema.events` (`penaltyPoints`, `noPenaltyReason`, ...).
**`affectsScore` no puede salir de `aplica_a_nota`**: `remap_attempt` documenta
(`services.py:392-402`) que `aplica_a_nota` vale `True` por defecto para los eventos informativos
(EVT_06/EVT_08) y que la fuente correcta es `descuenta`. Si el builder del mapa no trae
`descuenta`, `affectsScore` se omite en los eventos del mapa y el cliente lo cruza por `id` con
`/attempts/<id>`. De lo contrario el mismo evento diría «afectó a la nota» en el mapa y «no
afectó» en la ficha.

### C. Enriquecer `GET /api/v1/attempts/<attempt_id>` (ya existe)

El endpoint existe y el cliente ya lo consume, pero `AttemptDetailSchema` **no expone cuatro
bloques que la vista web sí pinta**. La ficha nativa está incompleta aunque tenga endpoint.

Los cuatro son lecturas derivadas sobre datos ya persistidos (`Attempt.scoreBreakdown["allison"]`,
`Attempt.optidriveScore`, `AttemptTrip`, `Attempt.webfleetEnrichmentAt`); ninguno escribe y su
salida no se persiste. Viven en `app/services/scoring/breakdown_reader.py:1064` (`allison_detalle`),
`app/services/scoring/narrativa_webfleet.py:47` (`narrativa_webfleet`) y
`app/blueprints/manager/parcial_webfleet.py:98` y `:160` (`vista_parcial_webfleet`,
`webfleet_consultado_sin_viaje` — en el blueprint `manager`, no en `app/services/`). Los pasan
*las dos* vistas web (`student/routes.py:234` y `manager/routes.py:544`):

- `allison_detalle(attempt.scoreBreakdown)` — la caja Allison. Sale del bus CAN de la vuelta
  que condujo el aspirante: es su dato y tiene el mismo derecho que el freno motor.
- `vista_parcial_webfleet(attempt)` — la mitad Webfleet cuando falta la estabilidad.
- `webfleet_consultado_sin_viaje(attempt)` — si ya se preguntó a Webfleet y no hay viaje en la
  ventana. Importa: «pendiente» manda a esperar algo que no va a llegar.
- `narrativa_webfleet(attempt)` — la lectura **agregada** de su conducción cuando falta la
  estabilidad: el dict que devuelve la función tal cual (`sobre_diez`, `optidrive`,
  `puntos[]{titulo, detalle, nivel, sobre_diez}` — hasta 5 puntos —, `es_parcial: true`, `falta`,
  `distancia_km`, `duracion_min`; `narrativa_webfleet.py:124-131`) o `null` cuando
  `optidriveScore` no está etiquetado como la ventana del propio intento
  (`parcial_webfleet.py:64-85`). Lee unas 11 claves del JSON; los «26 campos» son una frase del
  docstring del módulo (`:6`), no lo que devuelve. **Nunca el JSONB `optidriveScore` crudo**:
  sigue fuera del contrato para STUDENT («agregado sí, crudo no»). Es lo que contesta *«qué nota
  tengo y en qué he fallado»* cuando falta la mitad de estabilidad.

**Este bloque enmienda REQ-7 tal como está escrito en el blueprint, y hay que decirlo.**
`mobile_api/services.py:14-16` y el docstring de `remap_attempt` (`:300-301`) afirman que nada de
`optidriveScore` viaja en `AttemptDetailSchema`; `student_service.py:6-7` dice lo mismo del portal
web. Dos de los cuatro bloques (`vista_parcial_webfleet`, `narrativa_webfleet`) se derivan de
`optidriveScore`. La justificación es que el portal web del aspirante **ya** se los pasa al STUDENT
(`student/routes.py:244-266`: «Sale de `optidriveScore`, que es el desglose de SU conducción — no
telemetría de la flota»), así que la paridad no amplía lo que el aspirante ve; lo que sigue
excluido es el JSONB crudo, `kpisVehicle`/`kpisDriver`, `AttemptTrip` por viaje y los eventos
`HARSH_*`/`IDLE_EXCEPTION`. Pedimos que el backend confirme la enmienda antes de implementar y
actualice los tres docstrings en el mismo PR.

**Nombre y forma de los cuatro campos** (camelCase, para que el cliente los congele):

- `allison` (Dict, `allow_none`): el dict de `allison_detalle` — `null` para intentos anteriores al
  criterio D10-W o sin sección (`breakdown_reader.py:1081-1085`); el cliente no lo trata como error.
- `partialWebfleet` (Dict, `allow_none`): **solo el agregado** que devuelve `vista_parcial_webfleet`
  (`optidrive`, `sobre_diez`, `distancia_km`, `duracion_min`, `n_viajes`, `falta`,
  `peso_conduccion_pct`; `parcial_webfleet.py:129-156`), nunca la lista `trips` por viaje.
- `webfleetQueriedNoTrip` (Boolean, **no** nullable): `webfleet_consultado_sin_viaje` devuelve
  siempre `bool` (`parcial_webfleet.py:160`).
- `drivingNarrative` (Dict, `allow_none`): el dict de `narrativa_webfleet`; `puntos[].nivel` es un
  enum cerrado `bueno | regular | malo | neutro` (`narrativa_webfleet.py:23-37`). Aceptamos
  `puntos[].detalle` como frase en castellano (la escribe el backend y la pinta el cliente tal
  cual); si el backend prefiere números crudos, lo adaptamos.

Añadirlos como campos nuevos del schema, opcionales y `allow_none`. **No** cambiar ni renombrar
ningún campo existente: el cliente tiene tests que congelan el contrato actual
(`ContractEnumFreezeTests`, `AttemptDetailDTOTests`), pero corren contra fixtures locales, no
contra el servidor: un rename no se detectaría antes de publicar. El DTO decodifica con `Decodable`
sintetizado (ignora claves desconocidas, por eso lo aditivo es seguro); renombrar `scoreBreakdown`
o `events` rompe la decodificación entera, y renombrar cualquier otro campo lo deja en `nil` en
silencio.

**Alcance honesto de la ficha.** Estos cuatro no cierran la paridad de `/student/intento/<id>`: el
recorte del aspirante lo fija la lista exhaustiva y testeada `LO_QUE_VE_EL_ASPIRANTE`
(`student_service.py:97-119`: `identidad`, `vehiculo`, `estado_gates`, `nota_info`,
`fuentes_estado`, `explicacion_nota`, `narrativa_nota`, `freno_motor`, `optidrive_desglose`,
`velocidad_via`, `resumen_eventos`, `deducciones_familia`, `gps_status`, ...), y el endpoint móvil
hoy expone 10 claves desde el dict del manager (`get_intento_detail` + `remap_attempt`). En esta
ronda se piden **solo los cuatro bloques de conducción**; el resto del recorte queda registrado
como pendiente y, cuando se pida, debe partir de `get_student_intento` (el recorte del aspirante),
no del dict del manager.

### D. `GET /api/v1/me/routes/<route_code>`

Detalle por recorrido del aspirante. Equivale a `/student/ruta/<route_code>`
(`student/routes.py:213`).

- **Servicio existente:** `get_student_route_detail(route_code, student_id, org_id)`
  (`student_service.py:1274`). **No acepta `conv_id`**: resuelve la matrícula con
  `_active_enrollment(student_id, org_id)` (la `ACTIVE` más reciente), así que para el aspirante
  con dos inscripciones contestaría por la otra convocatoria; hay que añadirle el parámetro
  (cambio de servicio, no de dominio) o documentar aquí la excepción a la restricción 4.
- **Campos** (camelCase, fechas ISO 8601): `route{code, name, description, distanceKm,
  durationMin, active, required}` (`required` ← `exigida`, que decide el texto «este recorrido no
  entra en la nota oficial»), `waypoints[]{order, lat, lng, name}`, `attempts[]` con la misma forma
  que en el bloque A, `stats{closedAttempts, listedAttempts, bestScore, bestAttemptId, lastScore,
  lastAttemptId, lastAt}` (`ultima_fecha`/`ultima_hora` son dd/mm y HH:MM; deben viajar como un
  solo ISO), `candidate`, `convocatoria | null`. Fuente: `student_service.py:1389-1418`.

### E. `GET /api/v1/me/card`

Qué tarjeta le asignó el sistema al aspirante. **Confirmado en alcance por Antonio (2026-09-07).**

- **Servicios existentes:** `tarjeta_de_aspirante(org_id, student_id) -> str | None`
  (`manager/tarjetas_service.py:464`, devuelve el **UID** de la tarjeta activa no revocada,
  o `None` si no tiene) más `user.webfleet_driver_no`.
- **Es solo texto, no lectura NFC.** El cliente no abre Core NFC ni lee el chip: muestra lo que
  el sistema tiene registrado. El caso de uso está en el propio comentario del backend
  (`student/routes.py:127-130`, dentro de `dashboard()`; segunda mención en `:450-457`, dentro de
  `edit_profile()`): el día de la prueba, delante del camión, comprobar que el plástico que lleva
  encima es el que el sistema espera; y si no tiene tarjeta, avisarlo — sin tarjeta no se puede
  abrir un intento y enterarse allí es tarde.
- **Campos:**
  - `hasCard` (bool) — **el campo que de verdad cierra el caso de uso.** Es el que contesta
    «¿puedo abrir un intento hoy?» sin depender de que el aspirante sepa leer un UID.
  - `cardUid` (string, `allow_none`) — ver la pregunta abierta de abajo antes de decidir su forma.
  - `webfleetDriverNo` (string, `allow_none`).

#### Pregunta abierta que hay que contestar antes de implementar esto

`tarjeta_de_aspirante` devuelve el UID completo. De cómo se exponga depende el diseño del campo:

- **Paridad con la web:** devolverlo completo. Es lo único que permite la comparación visual que
  justifica la pantalla.
- **Endurecer en el móvil:** devolver `hasCard` más un UID enmascarado (últimos 4), y la pantalla
  se limita a «tenés tarjeta asignada» / «no tenés tarjeta — avisá a tu instructor antes de la
  prueba».

No implementéis el campo completo por defecto: es una decisión de exposición de datos y la
contesta Antonio con la evidencia del apartado siguiente, no el cliente.

**Lo que el backend ya decidió, para que la pregunta se conteste con evidencia y no con una visita
al almacén.** (a) La web del aspirante pinta el UID **completo** en el panel y en el perfil
(`student/routes.py:140` `tarjeta=tarjeta_de_aspirante(...)`, `:468` `tarjeta=tarjeta.uid`), y el
comentario de `edit_profile()` (`:455-456`) dice que «el código del plástico es el que se compara
con lo impreso en la tarjeta»: es decir, según el propio backend el UID va impreso. (b) El kiosko
define ese mismo UID como credencial (`kiosko/routes.py:477-478`: «El UID de la tarjeta ES la
credencial de esa vía: quien lo tenga entra como ese aspirante»), y la web audita la consulta del
PIN por esa razón (`KIOSK_PIN_VIEWED`) pero **no** la de la tarjeta. La decisión que queda, y es
de Antonio: (1) paridad con la web — `cardUid` completo — y, en ese caso, si `GET /me/card` se
audita como `/me/pin` (haría falta un `AuditAction` nuevo; hoy solo existen
`RFID_CARD_CREATED/ASSIGNED/REVOKED/DELETED`); o (2) el móvil endurece — `hasCard` + últimos 4.
(c) Fuente única: `tarjeta_de_aspirante` (scopea por organización y ordena por `assignedAt`,
`manager/tarjetas_service.py:464-475`). **No** copiar la consulta inline de `edit_profile()`
(`student/routes.py:459-463`: sin filtro por organización, ordena por `createdAt`): con dos
tarjetas activas dan resultados distintos.

### F. Cuenta del aspirante

**Requiere enmienda explícita de D-API-001 antes de empezar.** `memory/decision-mobile-api-v1.md:52`
fija «cero endpoints `POST/PUT/PATCH/DELETE` de dominio» y la enmienda de 2026-06-09 (`:62`) deja
escrito que «cualquier `POST/PUT/PATCH/DELETE` de recursos de dominio» sigue prohibido y que la
excepción de `/me/webfleet/sync` es «puntual y enumerada, no una apertura general».
`PATCH /me/password` y `PATCH /me/email` serían los primeros `PATCH` del blueprint
(`mobile_api/routes.py:61-383` solo tiene `GET` y tres `POST`). El argumento para la enmienda: son
escrituras de **cuenta**, no de dominio — no tocan nota, intento, inscripción ni convocatoria, y el
usuario ya puede hacerlas hoy por la web con el mismo JWT. Antonio tiene que enumerarlas como
excepción en el memo antes de que el backend las implemente.

**Pregunta abierta:** `student/routes.py:429-430` dice que «DNI, NSS y email son datos
administrativos — solo ADMIN puede cambiarlos», mientras `/auth/change-email` acepta cualquier rol
autenticado (`auth/routes.py:396-398`). Que el backend resuelva si el STUDENT puede cambiar su
email antes de exponer `PATCH /me/email`; si no puede, el bloque F se reduce a `/me/pin` y
`/me/password`.

Necesarias para que la app no obligue a abrir la web:

- `GET /api/v1/me/pin` — equivale a `/student/mi-pin` (`student/routes.py:310`),
  `@require_role(["STUDENT"])`. Es lectura pero **no es gratis**: la web escribe
  `AuditAction.KIOSK_PIN_VIEWED` vía `build_audit_log` en **cada** consulta, también cuando el PIN
  no se puede mostrar, con `delta={"mostrado": pin is not None}` (`routes.py:339-350`), porque
  PIN + número de inscripción permiten conducir en nombre de otro (`:318-323`). El endpoint móvil
  debe hacer lo mismo; sin el audit es una regresión respecto a la web. Respuesta: `pin` (string,
  `allow_none`; `user.kiosk_pin_claro` devuelve `None` tanto si no hay PIN como si la clave de
  cifrado no está disponible, `app/models/auth.py:168-176`, y la pantalla debe decir «no se puede
  mostrar» en ambos casos) y `enrollments[]{convocatoriaId, name, plaza}` desde
  `get_active_enrollments_summary` (`student_service.py:1422`), porque la tablet pide PIN + número
  de inscripción y el PIN solo no abre nada (`routes.py:324-327`). La web pasa esa lista como
  `plazas=` (`:357`): **no** copiar ese nombre al JSON (vocabulario prohibido por la restricción 1);
  `plaza` en singular sí, ver la nota añadida a esa restricción. Rate limit como el resto de
  credenciales: `5 per minute; 20 per hour`.
- `PATCH /api/v1/me/password` — equivale a `/auth/change-password` (`auth/routes.py:289`).
- `PATCH /api/v1/me/email` — equivale a `/auth/change-email` (`auth/routes.py:396`).

Estado actual, para no pedir lo que ya existe: `/auth/change-password` y `/auth/change-email`
**ya son JSON + JWT** (`auth/routes.py:289-291` y `:396-398`: `@jwt_required()`,
`@limiter.limit("5 per minute; 20 per hour")`, respuestas `jsonify` con 400/401/404/409/422; ningún
`flash()` ni `redirect()` entre las líneas 289 y 470). Lo que impide llamarlos desde el móvil es
que viven bajo el CSRF global (`app/__init__.py:216`) y solo `mobile_api_bp` está exento (`:349`);
además `change-email` devuelve solo `{"message"}` sin clave `error` (`:421-466`) y
`change-password` usa claves propias (`user_not_found`, `missing_fields`, `wrong_current_password`,
`passwords_do_not_match`, `password_too_short`, `password_unchanged`, `:314-346`). Se pide
montarlos bajo `/api/v1/me/...` con el **mismo** cuerpo (`currentPassword/newPassword/confirmPassword`;
`currentPassword/newEmail`), los mismos códigos HTTP, el mismo rate limit y el mismo audit, con las
claves de error en formato `error_response(code, error_key, message, details=None, retry_after=None)`
(`mobile_api/errors.py:7`; cuerpo `{"error": <error_key>, "message": ...}`). Para email,
propuestas: `invalid_email` 422, `email_unchanged` 422, `email_in_use` 409. Sin ese montaje, el
cliente nativo no puede consumir ninguno de los dos.

---

## Prioridad sugerida

| # | Bloque | Desbloquea | Coste estimado |
|---|--------|-----------|----------------|
| 1 | A — `/me/progress` | la pantalla que falta entera | medio (dos servicios, un schema, dos enums nuevos) |
| 2 | C — enriquecer `/attempts/<id>` | los cuatro bloques de conducción de la ficha | bajo-medio (cuatro campos, servicios ya existen; hay que remapear a camelCase y actualizar el docstring REQ-7) |
| 3 | B — `/attempts/<id>/gps` | mapa nativo | medio (el payload existe, pero es snake_case y hay que remapearlo, filtrar por `type` y no derivar `affectsScore` de `aplica_a_nota`) |
| 4 | E — `/me/card` | comprobar la tarjeta en campo | trivial — pero contestar la pregunta abierta antes |
| 5 | F — cuenta | que el aspirante no abra la web | bajo, tras la enmienda de D-API-001 |
| 6 | D — `/me/routes/<code>` | detalle por recorrido | bajo (añadir `conv_id` al servicio) |

---

## Lo que el cliente iOS aporta a cambio

- **Tests de contrato ya escritos.** `ContractEnumFreezeTests` congela las enumeraciones del
  backend que este cliente lee, para que un valor nuevo rompa la build acá en vez de quedar
  silencioso en pantalla. La promesa de avisar antes de añadir un valor vivía en un comentario
  en los dos lados; estos tests son la mitad de este repo. Los dos enums nuevos de este pedido
  (`state` y `trend` del bloque A, `nivel` del bloque C) se congelarán igual.
- **Payloads reales de staging como fixtures** (`SyncResultRealPayloadTests` congela el cuerpo
  real de `POST /me/webfleet/sync` del 2026-09-07 — que mezcla un entero y un string en el mismo
  diccionario, algo que un `[String: Int]` habría tirado entero).
- Si algún bloque de este pedido choca con algo del backend que no vemos desde acá, **preferimos
  saberlo antes** y adaptar el cliente que recibir un contrato que no encaje.

---

## Cómo se verificó este documento

La v1 se sometió a una revisión adversarial automatizada contra el código real de ambos repos:
52 afirmaciones extraídas, cada bloque atacado por dos refutadores independientes (literal y
semántico), más cuatro lentes buscando omisiones (cobertura de pantallas, GDPR, implementabilidad
desde el lado del backend, encaje con el cliente iOS). Resultado: 28 correcciones y 9 adiciones,
todas con `archivo:línea`. Las decisiones de producto no cambiaron; lo que cambió fue la precisión
de lo que se pide y el descubrimiento de tres premisas falsas (los nombres del bloque A ya existían
en `StandingSchema`; el builder de GPS citado era el del manager; los endpoints de `auth/` ya eran
JSON) y dos requisitos de proceso que faltaban (la enmienda de REQ-7 y la de D-API-001).

---

## Aviso de proceso

Este documento **no** abre issue ni PR contra el repo `training`. Lo escribe el agente del repo
iOS y lo entrega a Antonio, que decide si lo convierte en issue del lado del equipo.

Copia en engram: `project: "training-ios"`, topic `cross/api-needs/portal-aspirante`.
