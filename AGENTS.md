# AGENTS.md — Protocolo cross-agent

> Este archivo define cómo los agentes que operan en `Dobacksoft Training/` (iOS) y en `training/` (Flask) se comunican sin pisarse y sin acoplar repos. Lo lee cualquier agente (Claude, Codex, otro) al arrancar sesión en cualquiera de los dos repos.

## Contexto

Hay dos repos físicamente separados, owner único Antonio:

| Repo | Local | GitHub | Visibilidad | Stack | Engram project |
|------|-------|--------|-------------|-------|----------------|
| Training (equipo) | `/Users/antoniohermoso/repos/training` | [`cosigein/training`](https://github.com/cosigein/training) | PUBLIC | Flask + Postgres | `training` |
| Dobacksoft Training (iOS personal) | `/Users/antoniohermoso/IOS/Dobacksoft Training` | [`cosigein/training-ios`](https://github.com/cosigein/training-ios) | PRIVATE | Swift + SwiftUI | `training-ios` |

La decisión que separa los dos tracks: `D-DIR-001`, en `/Users/antoniohermoso/repos/training/memory/decision-tracks-paralelos.md`.

El único acoplamiento permitido es **el contrato del API móvil v1**. La app iOS lo consume; el backend lo expone.

> ⚠️ **El contrato ya no vive en un documento.** `docs/MOBILE-API.md` fue archivado en el repo training (`docs/_archive/2026-05-13/`) y `docs/API.md` contiene errores para la parte móvil (método equivocado en login, dos endpoints inexistentes, ocho reales sin documentar). La fuente de verdad es el código: `app/blueprints/mobile_api/{routes,schemas,services}.py`.

## Principios

1. **Memoria aislada por `project`.** Detalles de implementación iOS → `project: "training-ios"`. Detalles del backend → `project: "training"`. Nunca cruzados.
2. **Comunicación por engram con topic keys conocidos** (sección siguiente). Sin IPC en vivo, sin sockets, sin archivos compartidos. Engram es el canal **primario**.
3. **GitHub Issues como canal secundario formal.** Cuando una necesidad cross-track tenga que ser visible para humanos del equipo training (Jesús, Alejandro, Joel) o requiera tracking más allá de la sesión actual, se abre issue en `cosigein/training` con label `cross-ios` (a crear cuando haga falta). Engram sigue siendo la fuente de verdad para los agentes; GitHub es para humanos.
4. **El humano (Antonio) es el único canal síncrono.** Si algo es urgente, se le dice a él; él decide.
5. **Sin commits cruzados.** Ningún archivo `.swift` entra al repo training. Ningún archivo `.py` entra al repo iOS. Sólo metadocumentación (este AGENTS.md, decisiones D-XXX, etc.).
6. **Cuidado con el repo training siendo PUBLIC.** El repo backend `cosigein/training` es PUBLIC en GitHub. Cualquier issue, comentario o commit es visible. **Cero datos reales CMadrid, cero capturas con info confidencial, cero credenciales.**

## Topic keys del protocolo

Estos topic keys son contrato. **No reinventar nombres.** Si necesitás uno nuevo, agregalo a este archivo primero.

### Compartidos en ambos projects (escribir en los dos)

| Topic key | Quién escribe | Qué guarda |
|-----------|---------------|------------|
| `architecture/cross-agent-protocol` | el primero que toque, después upserts | este protocolo, en versión engram |
| `architecture/api-contract-snapshot` | agente del repo training | snapshot del estado actual de `MOBILE-API.md` (versión + endpoints expuestos) |

### En `project: "training-ios"` (los lee el agente del repo training cuando necesita saber qué pide la app)

| Topic key | Quién escribe | Qué guarda | Cuándo lo lee el otro lado |
|-----------|---------------|------------|----------------------------|
| `cross/api-needs/<feature>` | agente iOS | "necesito endpoint X que devuelva Y" — con justificación, mock de la respuesta esperada, fecha | el agente training revisa al arrancar sesión y le avisa a Antonio si hay pedidos nuevos |
| `cross/api-bugs/<id>` | agente iOS | "el endpoint X devuelve Z y no matchea el contrato" — con repro, cuerpo recibido | igual que arriba |
| `architecture/ios-app-state` | agente iOS | qué features están listas, qué endpoints consume hoy, qué falta | cuando el agente training quiera saber el impacto de un cambio de contrato |

### En `project: "training"` (los lee el agente iOS cuando arranca sesión)

| Topic key | Quién escribe | Qué guarda | Cuándo lo lee el iOS |
|-----------|---------------|------------|----------------------|
| `cross/api-changes/<feature>` | agente training | "endpoint X cambió: ahora devuelve Y, breaking yes/no, fecha" | el agente iOS revisa al arrancar sesión |
| `cross/api-deprecations/<feature>` | agente training | "endpoint X queda deprecado, alternativa Y, dropdate Z" | igual |

## Procedimiento para necesidades cross-track

### Caso A — la app iOS necesita algo del backend

1. **Agente iOS** guarda en engram:
   ```
   mem_save(
     title: "API need: <verbo corto>",
     type: "discovery",
     scope: "project",
     project: "training-ios",
     topic_key: "cross/api-needs/<feature>",
     content: "**What**: ...\n**Why**: ...\n**Mock response esperada**: ...\n**Bloquea a**: <feature iOS>"
   )
   ```
2. **Agente iOS** avisa a Antonio en el chat: *"Guardé un cross/api-needs/X. Cuando tengas un momento del lado training, lo evaluamos."*
3. **Antonio** abre sesión en repo training (eventual).
4. **Agente training** corre `mem_search(query: "cross/api-needs/", project: "training-ios")` al arrancar y reporta los pedidos pendientes.
5. **Antonio + agente training** deciden: implementar / postergar / rechazar. Si se implementa, va por **PR normal** al repo training (área `be` o `cross`), con review del owner del área.
6. Cuando el cambio mergea, **agente training** guarda `cross/api-changes/<feature>` en `project: "training"` con el detalle.
7. **Agente iOS** en su próxima sesión lee `cross/api-changes/*` y actualiza el cliente.

### Caso B — el backend hace un cambio de contrato

1. **Agente training** detecta o produce el cambio.
2. Antes de mergear: guardar en engram:
   ```
   mem_save(
     title: "API change: <verbo corto>",
     type: "decision",
     scope: "project",
     project: "training",
     topic_key: "cross/api-changes/<feature>",
     content: "**What**: ...\n**Breaking?**: yes/no\n**Antes**: ...\n**Después**: ...\n**Drop date**: ..."
   )
   ```
3. **Agente training** avisa a Antonio.
4. **Agente iOS** en su próxima sesión lee este topic y, si el cambio es breaking, ajusta el cliente antes de release.

### Caso C — bug detectado en el contrato (la respuesta real ≠ documentada)

Igual que Caso A pero con topic `cross/api-bugs/<id>` y `type: "bugfix"`. La urgencia depende del impacto en la demo.

## Qué NO hacer

- **No** abrir issues, PRs ni comentarios directos contra el repo training desde el agente iOS. Ni al revés.
- **No** modificar archivos del otro repo (ni siquiera `MOBILE-API.md` desde iOS). El que tenga la responsabilidad del repo lo edita.
- **No** persistir credenciales, tokens reales, datos de producción CMadrid en engram. Cero PII, cero tokens vivos.
- **No** romper la regla de `project` aislados — un descuido contamina la memoria a futuro.
- **No** asumir que el otro agente leyó algo. Si es importante, decirle a Antonio.

## Comunicación con el equipo Training (humanos)

**Sólo Antonio.** Jesús, Alejandro y Joel **no** saben (ni necesitan saber, hoy) que existe esta app iOS personal. Si algún feature de esta app llega a reflejarse en el sprint del equipo, será porque Antonio lo decidió y lo introduce con un issue/PR normal en el repo training.

## Histórico

- 2026-04-30 · creado por agente Claude del repo training en sesión de dirección de Antonio.
