# Dobacksoft Training

**Proyecto final · Apple Coding Academy**\
Antonio Hermoso González · 16 de septiembre de 2026

---

## En un minuto

Cliente **nativo iOS** para el seguimiento de la prueba práctica de conducción de
una oposición real de bombero conductor de la Comunidad de Madrid.

Los aspirantes conducen recorridos en un camión instrumentado con telemetría GPS
y sensores de estabilidad. De esos datos sale una calificación objetiva. La
aplicación da acceso desde el móvil a ese expediente: posición, calificación y su
desglose, progreso por recorrido, detalle de cada vuelta y el trazado GPS sobre
el mapa. Los instructores ven la tabla de resultados de su convocatoria.

No es un ejercicio: **forma parte del entregable oficial a la Comunidad de
Madrid** desde el 5 de septiembre de 2026.

> **Estado actual.** El sistema está en **fase de pruebas** y entra en
> producción en el cuerpo de **Bomberos de la Comunidad de Madrid dentro de
> aproximadamente un mes**. Los datos que se ven hoy son de una convocatoria de
> prueba; a partir de la entrada en producción serán expedientes reales de
> opositores, sujetos a acuerdo de confidencialidad.

| | |
|---|---|
| Repositorio | <https://github.com/csgingenieria/training-ios> |
| Revisión entregada | `ba302b3` en `main` |
| Swift | **6.0**, aislamiento estricto (`-default-isolation=MainActor`) |
| Interfaz | SwiftUI · iPhone y iPad, una sola base de código |
| Despliegue mínimo | iOS 26.4 · `TARGETED_DEVICE_FAMILY = 1,2` |
| Dependencias de terceros | **cero** |
| Código de aplicación | 15 561 líneas · 113 ficheros |
| Código de pruebas | 12 864 líneas · **45 % del repositorio** |
| Pruebas | **757** casos · 103 suites · 0 fallos |
| Extensiones | WidgetKit · AppIntents |

---

## Si solo hay diez minutos

Cuatro ficheros que concentran lo que este proyecto tiene de particular:

| Fichero | Por qué |
|---|---|
| `Core/API/TrainingAPI.swift` | La costura de red, y su comentario explica que sin ella *«los tests acababan comprobando asignaciones que ellos mismos hacían»* |
| `Core/Models/LenientDecoding.swift` | Decodificación tolerante **con frontera**: tolera tipos, se niega a inventar datos |
| `Core/Auth/AppLock.swift` | Biometría disponible ≠ biometría inscrita. Un fallo que solo aparece en dispositivo real |
| `scripts/check-deep-link.sh` | Una guarda que además **abre dos esquemas que no deben resolver**: si resuelven, se declara sin valor a sí misma |

Y un documento: `docs/audits/2026-09-07-calidad-nativa.md` — auditoría de 57
puntos con cinco lentes independientes y un escéptico por hallazgo. Cerrada 57/57.

---

## Decisiones técnicas

### Cero dependencias, a propósito

Sin SPM remoto, sin CocoaPods, sin Alamofire. Todo con frameworks de Apple:
`URLSession` con `async/await`, llavero vía `SecItem*`, MapKit, WidgetKit,
LocalAuthentication, AppIntents, Swift Testing.

El coste es real —cliente HTTP, decodificación tolerante, envoltorio de llavero y
sistema de diseño propios, unas 1 500 líneas— y se asume por tres razones: en un
entregable a una administración, cada dependencia es código de terceros que
alguien puede tener que auditar; la vida útil se mide en años de convocatorias y
una biblioteca abandonada es una migración forzosa; y sin paquetes remotos no hay
riesgo de cadena de suministro.

### Concurrencia verificada por el compilador

Toda la asincronía es `async/await` con aislamiento por `actor`. `APIClient` es un
actor único: ninguna vista instancia su propia `URLSession`.

La migración a Swift 6 dejó una lección documentada en el repositorio: el primer
intento anotó tipos en bloque **todavía en modo Swift 5** y produjo 494 fallos de
aislamiento en ejecución que el compilador no señalaba, porque en Swift 5 esas
anotaciones no se verifican. Se revirtió por completo y se rehízo ya en modo
Swift 6, anotando solo lo que el compilador exigía.

### Tipos en lugar de cadenas

Los conceptos del dominio son tipos con nombre, no `String` ni `Bool`. Un tipo se
puede probar, se puede buscar y no se confunde con otro:

```
NotFoundReason      por qué no hay dato: no inscrito / sin clasificar / inexistente
LogoutReason        por qué terminó la sesión, para poder explicárselo al usuario
GradeFinality       provisional o definitiva, con el aviso legal que le corresponde
StatusVocabulary    el punto único donde se controla el vocabulario del RGPD
DecodingFailure     qué campo falló y cómo, sin registrar jamás su valor
SecretRedaction     cómo escribir algo sensible en un log sin escribirlo
APISentinel         los valores centinela del backend, para no confundirlos con datos
BiometryCapability  qué puede hacer este dispositivo: biometría, solo código, nada
```

### Decodificación tolerante, con una frontera explícita

Un campo mal tipado **no puede invalidar la respuesta entera**. Se aprendió por las
malas: el backend declaraba como texto un campo de confianza de cada punto GPS que
llegaba como número, y con decodificación estricta **un punto entre miles
invalidaba el mapa completo** — trazado, recorrido previsto e incidencias.

Pero la tolerancia tiene un límite, y es la parte que importa:

```swift
/// El espejo de `lenientDouble`. Aquel se niega a inventar una cifra a partir
/// de «MODERADO»; este se niega a inventar una etiqueta a partir de `0.9`.
func lenientLabel(forKey key: Key) -> String? {
    try? decodeIfPresent(String.self, forKey: key)
}
```

Un campo que no se entiende es un campo que **no consta**, y la interfaz sabe
decir que algo no consta. Nunca se infiere.

### El widget no tiene credenciales

Arquitectura de un solo escritor: la app deposita una instantánea fechada en el
App Group y el widget solo lee. **No hace red y no conoce el token.** La
instantánea es una proyección: omite identificadores, nombre y correo — lo que no
hace falta para dibujar no sale del contenedor de la app.

Si el dato es viejo, el widget **lo dice** (umbrales de 6 y 48 h) en lugar de
mostrar una cifra sin fundamento. Y un error de carga nunca sobrescribe la última
instantánea buena. Las cifras van marcadas `privacySensitive()`.

### iPad de verdad

Una base de código, dos navegaciones: pestañas en compacto, `NavigationSplitView`
en regular, decidido **por clase de tamaño y no por modelo** — un iPad en
multitarea estrecha usa correctamente el diseño compacto. Enrutador compartido con
una `NavigationPath` por sección y ancho legible limitado a 680 pt.

Conviene decirlo: el panel lateral **nunca había funcionado**. Estaba escrito de
una forma que el sistema no reconoce como selección de panel. Ninguna revisión de
código lo detectó; apareció al ejecutar en un iPad real.

### Accesibilidad como requisito, no como extra

Dynamic Type en **todos** los roles tipográficos (`relativeTo:`, ninguna fuente de
tamaño fijo); los diseños conmutan de horizontal a vertical en tamaños de
accesibilidad. Etiquetas que describen el significado: un pin del mapa dice qué
ocurrió, no `EVT_01`; una posición se pronuncia «Puesto 12 de 40» como una sola
frase; una nota, «8,5 sobre 10». Objetivos táctiles de 44 pt, movimiento reducido
respetado, contraste ≥ 4,5:1 en claro y en oscuro.

---

## Arquitectura

```
Features/           9 áreas · 36 ficheros · 8 298 líneas   SwiftUI + ViewModels
├── Core/Navigation    rutas y enlaces profundos      188
├── Core/Models        30 DTOs y reglas de dominio  3 122
├── Core/Auth          sesión, llavero, bloqueo       793
└── Core/API           actor de red, errores          697
Shared/             tema, publicación, utilidades   1 191
          ▲                              ▲
    ┌─────┴──────┐              ┌────────┴────────┐
    │ App (iOS)  │              │ Widget (ext.)   │
    └─────┬──────┘              └────────┬────────┘
          └──────── SharedSnapshot/ ─────┘
                    641 líneas · App Group
```

`SharedSnapshot/` está en **ambos targets**, así que no puede depender de nada de
la app: por eso lleva su propio `Logger` en lugar de usar el de la aplicación.

**Sesión:** ante un `401` renueva y reintenta una vez; solo cierra sesión si la
renovación es rechazada. Un fallo de transporte **conserva** los tokens — echar a
alguien de la app porque entró en un túnel es un error de producto, no una medida
de seguridad.

---

## Verificación

Tres niveles con propósitos distintos, porque cada uno tiene un punto ciego:

| Nivel | Qué demuestra | Qué no |
|---|---|---|
| **757 pruebas unitarias** | Que una regla es correcta en todos sus casos | Que esté conectada a la pantalla |
| **4 recorridos XCUITest** | La app real contra un servidor real, 2 roles × 2 tamaños | Los casos límite |
| **5 guardas de proyecto** | Propiedades estructurales que ningún test alcanza | Comportamiento |

Cada guarda existe porque el defecto que vigila **ocurrió**:

| Guarda | Por qué ningún test la sustituye |
|---|---|
| `check-navigation-links` | Un `NavigationLink` de destino deja la vista fuera de la pila gestionada: la pantalla se abre y por dentro está muerta. Apareció **seis veces en un día** |
| `check-ui-register` | Los tests solo alcanzan cadenas expuestas por la API de un tipo. El diálogo de cierre de sesión tuteó al usuario durante meses con los tests en verde |
| `check-widget-palette` | `Bundle.main` dentro de una extensión **es** la extensión: la paleta tiene que ser copia, y una copia deriva |
| `check-deep-link` | Constante, parser, buzón e `Info.plist` pueden estar verdes y el toque no hacer nada: quien decide es LaunchServices |
| `check-hosts` | Todos los tests corren en Debug. `Release.xcconfig` apuntaba a un host inexistente y nada lo detectaba |

### El principio que lo gobierna todo

> **Una comprobación que nunca se ha visto fallar no ha demostrado nada.**

Cada guarda lleva un **caso de control**: rompe a propósito lo que vigila y
verifica que falla. `check-deep-link` no se limita a comprobar que el esquema
propio abre — abre además dos que **no deben** resolver, y si alguno responde
éxito, la comprobación entera se declara sin valor.

El método encontró una prueba que verificaba un texto evaluando la misma expresión
que lo construía, y que por tanto no podía fallar nunca.

---

## Cómo ejecutarlo para evaluarlo

**Las 757 pruebas unitarias no necesitan red ni credenciales.** Es la vía para
evaluar el proyecto sin acceso al servidor:

```bash
git clone https://github.com/csgingenieria/training-ios.git
cd training-ios

xcodebuild test -project "Dobacksoft Training.xcodeproj" \
                -scheme "Dobacksoft Training" \
                -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
                -only-testing:"Dobacksoft TrainingTests"
```

Las guardas tampoco necesitan credenciales, y una de ellas muestra el caso de
control en funcionamiento:

```bash
for g in scripts/check-*.sh; do bash "$g"; done
```

Requiere **Xcode 26.4**. El proyecto usa carpetas sincronizadas
(`PBXFileSystemSynchronizedRootGroup`): los ficheros del árbol entran solos, sin
tocar el `pbxproj`.

> Un solo `xcodebuild test` a la vez.

### Acceso con datos reales

Para ver la aplicación funcionando de verdad se facilitan **credenciales de
evaluación de los dos perfiles** —instructor y aspirante— **junto con esta
entrega**.

**No están en este repositorio, y no deben publicarse ni redistribuirse.** Dan
acceso al servidor del proyecto, que hoy sirve una convocatoria de prueba y en un
mes servirá expedientes reales de opositores de Bomberos de la Comunidad de
Madrid. Son para evaluar este proyecto, y para nada más.

Con ellas se pueden ejecutar también los cuatro recorridos automatizados, que
leen las credenciales del llavero y nunca de un fichero:

```bash
security add-generic-password -U -s training-ios-staging-student -a '<correo>' -w
security add-generic-password -U -s training-ios-staging-manager -a '<correo>' -w
bash scripts/staging-walkthrough.sh
```

El código de esos recorridos está en el repositorio
(`StagingWalkthroughUITests.swift`, 1 650 de las 1 817 líneas de pruebas de
interfaz) y se lee perfectamente como muestra de trabajo aunque no se ejecute: la
disciplina de toques que no se tragan, la espera a que un elemento deje de
moverse y la comprobación de que no lo tapa el cromo del sistema.

---

## Cumplimiento normativo

Lo que más ha condicionado el diseño no es técnico: el **artículo 22 del RGPD**
reconoce el derecho a no ser objeto de decisiones exclusivamente automatizadas con
efectos jurídicos. Acceder a un puesto en la función pública lo es.

El sistema calcula una nota objetiva, pero **no emite un veredicto**: la admisión
la decide la administración, con intervención humana. La consecuencia es concreta:
hay un vocabulario que la interfaz **no puede pronunciar** — `APTO`, «aprobado»,
«suspenso», «admitido», «excluido», «línea de corte», «plazas» — ni sugerirlo
visualmente, de ahí que las posiciones **no se coloreen**: un juicio visual es un
juicio.

Se verifica por **tres vías con puntos ciegos distintos**: pruebas unitarias sobre
los textos que exponen los tipos; una guarda sobre **todos** los literales de
interfaz de app y widget (cubre las cadenas dentro de un `Text(...)`, que los
tests no alcanzan); y una comprobación sobre la **pantalla renderizada** durante
el recorrido con datos reales (cubre lo que llega del servidor).

Por el **artículo 25.2**, el widget está **desactivado de fábrica**: muestra
posición y nota en una pantalla que ve cualquiera que mire el teléfono.

---

## Lo que este proyecto me enseñó

Los cuatro defectos más graves **no los encontró ninguna revisión de código**:

1. Un campo mal tipado invalidaba **once mapas de once**
2. Una contraseña mal escrita **cerraba la sesión** — todo `401` se trataba como caducidad
3. El panel lateral del iPad **nunca había funcionado**
4. La configuración de distribución apuntaba a un **servidor inexistente**

Los cuatro aparecieron al **ejecutar**: contra un servidor real, en un dispositivo
real, con una configuración real. Leer el código no los habría encontrado, porque
cada uno era código correcto interactuando con una realidad distinta de la
supuesta. El defecto no vivía en el código: vivía entre el código y el mundo.

De ahí el 45 % de pruebas, de ahí las guardas, y de ahí que cada guarda lleve su
caso de control.

---

## Documentación en el repositorio

```
ENTREGA.md                                  este documento
CLAUDE.md                                   reglas del proyecto y del stack
docs/audits/2026-09-07-calidad-nativa.md    auditoría de 57 puntos, cerrada
docs/audits/2026-09-16-verificacion…        verificación previa a la entrega
docs/decisions/D-IOS-002…                   entrada en el entregable a CMadrid
docs/decisions/D-IOS-003…                   retirada del Apple Watch, y por qué
```

Y la **memoria del proyecto**: 49 páginas con contexto, requisitos, arquitectura,
modelo de datos, interfaz, seguridad, pruebas, despliegue y seis casos de estudio
de defectos reales con su causa, su síntoma y su corrección.

---

## Pendientes declarados

Porque forman parte del resultado:

1. **Distribución.** TestFlight quedó inutilizable por un problema de la cuenta.
   El canal correcto para un entregable institucional es **Custom App** vía Apple
   Business Manager.
2. **Numeración de versiones.** Dos compilaciones distintas llegaron a convivir
   como `2.0 (1)`. Hay que incrementar `CFBundleVersion` en cada build que salga
   del equipo, o es imposible saber qué se está probando.
3. **Integración continua.** Los recorridos se ejecutan a mano.
