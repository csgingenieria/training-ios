# Decisión D-IOS-002 — El cliente iOS entra al entregable oficial a CMadrid

**Tipo**: decision
**Autor**: Antonio Hermoso
**Fecha**: 2026-09-05
**Estado**: activa
**Sustituye a**: la cláusula de `CLAUDE.md` que declaraba la app «fuera del entregable a CMadrid»

## Qué

El cliente nativo iOS deja de ser una herramienta personal de Antonio y pasa a formar parte del **entregable oficial al Cuerpo de Bomberos de la Comunidad de Madrid**.

Usuarios finales:

- **Bomberos aspirantes** (rol `STUDENT`) — consultan su posición, su nota y su historial de intentos.
- **Instructores** (rol `MANAGER`) — operativa diaria: panel, ranking, matriz, alertas Webfleet, sincronización manual.

El repo sigue siendo privado y separado (`csgingenieria/training-ios`). No cambia la regla de no commits cruzados con `csgingenieria/training`.

> Nota del 2026-09-06: hasta esa fecha esta decisión citaba `cosigein/*`, una organización inexistente. El repo iOS se creó ese día y recibió sus primeros dieciséis commits.

## Por qué

El `CLAUDE.md` del repo dejó escrita la condición desde el día uno:

> «Hoy está fuera del entregable a CMadrid. Si algún día entra al entregable oficial, hay que crear una decisión nueva que lo declare explícito.»

Este documento es esa decisión.

## Qué cambia al cruzar esa línea

El cambio de destinatario cambia el estándar de calidad exigible. Deja de ser aceptable lo que se toleraba en una herramienta de uso propio.

### 1. Cumplimiento contractual y RGPD

`docs/CMADRID-ENTREGA.md` v1.1 (repo training, septiembre 2026) declara al departamento técnico del cliente que **el sistema no gestiona plazas ni cupos**, que **no emite veredicto APTO / NO APTO** y que **no existe línea de corte**.

La app, congelada el 2026-04-30, se construyó sobre el modelo anterior y **muestra `plazas`**. Eso contradice un documento contractual ya entregado. Corregirlo no es cosmética: es alineación con lo firmado.

El vocabulario prohibido queda documentado en `CLAUDE.md` § GDPR.

### 2. Robustez

El usuario final no es técnico y no tiene a quién preguntarle. Un `fatalError` por configuración ausente, o una sesión que expira y deja la pantalla atascada, es un incidente con el cliente.

### 3. Honestidad del producto

Los targets Watch y Widgets muestran datos `.sample` hardcodeados. El widget anuncia «Mi posición» en la pantalla de bloqueo y no existe ni App Group ni Keychain compartido. **Entregar un widget que muestra datos falsos a un cliente público no es una feature incompleta: es información incorrecta.** O se integran de verdad, o salen del build de entrega.

> **Resuelto (2026-09-06).** El widget se integró: la app deposita un `StandingSnapshot` fechado en el App Group y el widget lo lee, sin credenciales ni red propias. El reloj se retiró del proyecto — ver `D-IOS-003`.

### 4. Trazabilidad

Una suite de tests que no compila no es cobertura. Arreglada en Fase 0 (48 tests en verde).

## Consecuencias operativas

- **Fuente de verdad del contrato**: `app/blueprints/mobile_api/{routes,schemas,services}.py` en el repo training. `MOBILE-API.md` está archivado y `docs/API.md` tiene errores en la sección móvil. Documentado en `CLAUDE.md` y `AGENTS.md`.
- **Datos**: desarrollo contra VPS staging o seed local. Nunca producción.
- **Deuda conocida al momento de esta decisión**: sin refresh-on-401 en runtime, `APIClient` no protocolizado (impide testear ViewModels), `fatalError` en `AppEnvironment`, `TokenStore` ignora `OSStatus`, `StandingView.swift` con 721 líneas y responsabilidades mezcladas.
- **Dominio no cubierto**: recorridos de examen vs prácticas (`CategoriaRecorrido`), nota oficial D10-W con pesos por recorrido, `rutasExigidas`.

## Nota para el repo training

`memory/contexto-cmadrid.md` (fecha 2026-04-28) sigue documentando el modelo obsoleto: «Plazas limitadas y conocidas de antemano», «Decisión APTO / NO_APTO», «doble validación». Ese archivo indujo el modelo mental sobre el que se construyó esta app y **sigue induciendo a error a cualquier agente que lo lea**. Debe actualizarse o marcarse como superseded.

Esa corrección corresponde al repo training y la decide Antonio; desde este repo solo se deja constancia.

## Referencias

- `D-DIR-001` — tracks paralelos (`repos/training/memory/decision-tracks-paralelos.md`)
- `D-IOS-001` — regla de plataformas iPhone/iPad/Watch (`repos/training/memory/decision-ios-platform-rule.md`)
- `D-API-001` — API móvil v1 read-only por fases, con enmienda del 2026-06-09 (`repos/training/memory/decision-mobile-api-v1.md`)
- `docs/CMADRID-ENTREGA.md` v1.1 — documento de entrega técnica al cliente
