# CLAUDE.md — Cliente nativo iOS (entregable CMadrid)

> Este archivo guía a cualquier agente Claude que trabaje en este repo. Las instrucciones de este archivo **sobrescriben** comportamiento por defecto cuando hay conflicto.

## Estado del repo (CRÍTICO — leer primero)

App nativa iOS **dentro del entregable oficial a CMadrid** desde el 2026-09-05 (`D-IOS-002`). Repo separado, propietario único Antonio. Esta app:

- Consume el **API móvil v1** del repo `training/` (Flask, otro proyecto, otro track) vía Bearer JWT.
- La usan **bomberos aspirantes** (rol `STUDENT`) e **instructores** (rol `MANAGER`). El usuario final no es técnico y no tiene a quién preguntarle: un crash o un dato confuso es un incidente con el cliente, no un bug de andar por casa.
- Nació como track **paralelo** al sprint del equipo del backend — ver `D-DIR-001` en `/Users/antoniohermoso/repos/training/memory/decision-tracks-paralelos.md`. Sigue siendo un repo aparte, pero ya no es un experimento personal.

**Repos relevantes:**
- Este repo iOS (**público desde el 2026-09-16**, para la entrega académica; antes privado): [`csgingenieria/training-ios`](https://github.com/csgingenieria/training-ios)
- Repo backend del equipo (PRIVADO): [`csgingenieria/training`](https://github.com/csgingenieria/training)

> Ambos son privados y verificados el 2026-09-06. Hasta esa fecha este archivo citaba `cosigein/*`, una organización que **no existe**, y declaraba el backend como público. El repo iOS nunca había tenido remoto válido: dieciséis commits vivían solo en el disco de Antonio.
>
> El repo iOS es público desde el 2026-09-16 y el backend sigue privado. Eso **no relaja la confidencialidad, la endurece**: los datos de CMadrid siguen bajo NDA y lo que se escribe en un commit ahora lo lee cualquiera.

**Nada de este repo se commitea al repo training, ni viceversa.** El único acoplamiento permitido es el contrato del API móvil v1.

### El contrato del API vive en el código, no en un documento

`docs/MOBILE-API.md` fue **archivado** en el repo training (`docs/_archive/2026-05-13/`). Ya no se mantiene y no describe el contrato actual.

`docs/API.md` del repo training **tampoco es fiable** para móvil: documenta `GET /api/v1/auth/login` (es `POST`), cita `/api/v1/rankings` y `/api/v1/events` (no existen) y omite ocho endpoints reales.

**Única fuente de verdad:** `app/blueprints/mobile_api/{routes,schemas,services}.py` en el repo training. Leer el código. No adivinar campos, no confiar en la doc.

## Stack

- **Lenguaje:** Swift (iOS 26 SDK).
- **UI:** SwiftUI nativo. Nada de UIKit nuevo, nada de cross-platform (sin React Native, Flutter, KMM, Catalyst).
- **Plataformas soportadas:** iPhone + iPad (mismo target, layout adaptativo), más una extensión de widget. **Sin Apple Watch, sin macOS, sin visionOS.** `D-IOS-001` (`/Users/antoniohermoso/repos/training/memory/decision-ios-platform-rule.md`) admitía el reloj; `D-IOS-003` lo retira.
- **Concurrencia:** `async/await` + `actor` (ej: `APIClient` es un actor singleton).
- **HTTP:** `URLSession` directo. Sin Alamofire, sin Moya.
- **Persistencia local de tokens:** Keychain a través de `TokenStore`. **No** usar `UserDefaults` para tokens.
- **Build:** Xcode 26.6 (con el que se construyó y probó la entrega; el despliegue mínimo es iOS 26.4). El proyecto usa `PBXFileSystemSynchronizedRootGroup` — cualquier `.swift` dentro de `Dobacksoft Training/` se incluye automáticamente, no hace falta editar `pbxproj` para agregar archivos.

## Estructura

Carpetas sincronizadas: lo que está en el árbol está en el target, sin tocar el `pbxproj`.

```
Dobacksoft Training/
├── Dobacksoft_TrainingApp.swift     # @main
├── ContentView.swift                # RootView: arranque, bloqueo, privacidad, enlaces
├── Core/
│   ├── API/         # APIClient (actor), TrainingAPI (la costura), APIError, *Query
│   ├── Auth/        # AuthSession, TokenStore (llavero), AppLock + AppLockRules
│   ├── Models/      # 30 DTOs + reglas de dominio (GradeFinality, StatusVocabulary…)
│   └── Navigation/  # DeepLink, OpenStandingIntent, SecretRedaction
├── Features/        # 9 áreas: Login · Dashboard · Convocatorias · Standing · Progreso
│                    #          Attempt · Resultados · Manager · Cuenta
│   ├── Standing/    # StandingView + StandingViewModel + StandingCard + AttemptListTypes
│   └── Manager/     # ManagerPanelView + ManagerPanelViewModel + PanelRoute
└── Shared/
    ├── Theme/       # tokens, tipografía, GreetingCard, LoadingStateView
    ├── SnapshotPublisher, LastGoodStore, PrivacyGate, RefreshTicker, AppLog
SharedSnapshot/      # lo que comparten app y widget (sin depender de la app)
Dobacksoft Training Widgets/
Dobacksoft TrainingTests/   · Dobacksoft TrainingUITests/
scripts/             # 6 guardas check-*.sh · staging-walkthrough.sh · verificar.sh
```

Cada feature es una carpeta con `*View.swift` y, cuando hay algo que probar sin la vista,
un `*ViewModel.swift` (`@Observable`, con `init(api: TrainingAPI = APIClient.shared)`).
Diez modelos de vista, los diez con esa costura.

## Reglas firmes

### Plataforma
- iPhone + iPad, más la extensión de widget. **Nada más.** Si Xcode regenera `pbxproj` y mete `macOS`, `xrOS` o watchOS, sacarlos.
- El widget **no tiene credenciales y no hace red**: la app deposita un `StandingSnapshot` fechado en el App Group `group.Com.Dobacksoft-Training` y el widget solo lo lee. No darle nunca el token ni un cliente HTTP.
- El código que comparten app y widget vive en `SharedSnapshot/`, un grupo sincronizado propio añadido a ambos targets. **No** puede depender de nada del target de la app (por eso `SnapshotStore` usa su propio `Logger` y no `AppLog`).

### API
- Toda llamada HTTP pasa por `APIClient` (actor singleton). No instanciar `URLSession` ad-hoc en Views.
- El `accessToken` lo provee `AuthSession`. Las Views/ViewModels no leen `TokenStore` directo — pasan por `AuthSession`.
- Cuando el contrato del API cambie en el repo training, **el cambio se detecta leyendo el código del blueprint**: `/Users/antoniohermoso/repos/training/app/blueprints/mobile_api/{routes,schemas,services}.py`. No adivinar campos, y no confiar en `docs/API.md` (tiene errores) ni en `MOBILE-API.md` (archivado).
- Si necesitamos un endpoint nuevo o un cambio del contrato → **NO modificar el backend desde acá**. Notificar via engram (ver `AGENTS.md` § Cross-agent protocol) y esperar el PR del lado training.

### Auth
- Tokens **siempre** en Keychain (`TokenStore`). Nunca en `UserDefaults`, nunca en archivo plano.
- El access token es de vida corta — usar `AuthSession.refresh()` cuando llega 401.
- El refresh token vive más, pero también en Keychain.

### Estilo de código
- `async/await` + `actor`. **No** dispatch queues nuevas, **no** completion handlers nuevos en código que escribimos hoy.
- DTOs separados de modelos de dominio. `*DTO.swift` matchean el JSON del backend; si la View necesita una forma distinta, mappear en el ViewModel.
- Nombres en inglés para tipos/funciones; strings de UI en español castellano formal (cliente final son bomberos CMadrid).

### GDPR y vocabulario prohibido (NO NEGOCIABLE)

Training evalúa una **oposición pública**. El sistema calcula una nota objetiva; **no emite veredicto**. La admisión la decide CMadrid fuera del sistema, al cierre formal. Esto es el artículo 22 del RGPD (derecho a revisión humana), no una preferencia de producto.

La UI **nunca** puede mostrar, sugerir ni insinuar:

- `APTO` / `NO APTO`, «aprobado», «suspenso», «admitido», «excluido», ni ninguna variante.
- «línea de corte», «dentro/fuera de plaza», `withinCutoff`, ni marcar visualmente un umbral en el ranking.
- **`plazas` / `totalPlazas`.** El sistema dejó de gestionar cupos (#392). El backend ya no modela cupo ni capacidad —lo único con nombre parecido es `plazaNumber`, el identificador de inscripción del aspirante—, y `docs/CMADRID-ENTREGA.md` v1.1 declara al cliente que **«el sistema no gestiona plazas ni cupos»**. Mostrarlos contradice un documento contractual entregado.

Lo que sí se muestra: posición en el ranking, nota, número de participantes, intentos completados.

**La nota oficial** ya no es el promedio de los intentos: es la media del mejor intento por recorrido exigido, contando 0 los recorridos no conducidos (#845). Si una pantalla explica cómo se calcula la nota, tiene que decir esto.

### Confidencialidad
- Datos CMadrid bajo NDA. Para desarrollo, usar el VPS staging o seed local — nunca la base de producción.
- Sin capturas con datos reales en commits, issues, gists, screenshots públicos ni herramientas de terceros.
- El repo iOS es público y el backend privado; el listón es el mismo para los dos: los datos de CMadrid están bajo NDA y lo que se escribe en un commit, un issue o una captura no lleva datos reales ni credenciales. El historial público ya arrastra un commit de abril con cuentas de semilla (muertas, comprobado el 2026-09-17): que sea el último.

## Memoria persistente (engram)

**`project: "training-ios"`** para todo lo que es de este repo. **Nunca** guardes cosas iOS con `project: "training"` y al revés.

Antes de arrancar trabajo nuevo en una sesión:
1. `mem_search(query: "...", project: "training-ios")` — buscar contexto previo de este repo.
2. Si hay menciones a una decisión que lleva prefijo D-API-* o que afecta al backend, **también** buscar con `project: "training"` para leer la fuente.

Topic keys recomendados:
- `architecture/ios-app-state` — estado actual de la app (qué features están listas).
- `architecture/cross-agent-protocol` — cómo este repo se comunica con el agente del repo training (mismo topic key se replica en ambos projects).
- `cross/api-needs/<feature>` — cuando esta app necesita algo del backend; el agente del repo training busca este topic key con `project: "training-ios"`.
- `cross/api-changes/<feature>` — cuando el backend hace un cambio de contrato; el agente del repo training escribe acá con `project: "training-ios"` para que esta sesión lo vea.

Ver `AGENTS.md` para el protocolo completo.

## Comunicación con el equipo training

**No directa.** Antonio es el único enlace humano. Si trabajando en esta app descubrís algo que afecta al equipo (ej: un endpoint del API que estaría buenísimo), lo correcto es:

1. Guardar en engram con topic `cross/api-needs/<X>` y project `training-ios`.
2. Avisarle a Antonio en chat — él decide si abre issue/PR en el repo training.

**Nunca abrir issues, PRs ni comentarios directos contra el repo training desde acá.**

## Comandos del proyecto

```bash
# Abrir en Xcode
open "Dobacksoft Training.xcodeproj"

# Build CLI (sin abrir Xcode)
xcodebuild -project "Dobacksoft Training.xcodeproj" -scheme "Dobacksoft Training" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build

# Tests
xcodebuild test -project "Dobacksoft Training.xcodeproj" -scheme "Dobacksoft Training" -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

Backend local para desarrollo: `http://localhost:5000` (Flask del repo training corriendo). Ver `Shared/AppEnvironment.swift`.

## Idioma

- Antonio → español rioplatense (voseo).
- UI strings → castellano formal (los lee el bombero final).
- Comentarios de código → español rioplatense ok, o inglés si el contexto es técnico universal.

## Histórico

- 2026-04-30 · creado por agente Claude del repo training en sesión de dirección de Antonio. Track separado de Training equipo.
- 2026-09-06 · `D-IOS-003`: se retira el Apple Watch del proyecto. Ver `docs/decisions/D-IOS-003-retirada-apple-watch.md`.
- 2026-09-05 · `D-IOS-002`: la app entra al **entregable oficial a CMadrid** (decisión de Antonio). Se documenta el vocabulario prohibido por RGPD art. 22, se corrige la fuente de verdad del contrato del API (el blueprint, no la doc) y se registra la desalineación de `plazas` frente a `CMADRID-ENTREGA.md` v1.1. Ver `docs/decisions/D-IOS-002-entregable-cmadrid.md`.
