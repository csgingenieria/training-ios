# Verificación de entrega — 2026-09-16

Comprobación del cliente antes de la entrega del proyecto. Todo lo que sigue se
midió el 2026-09-16 sobre `main`, en la revisión `7a2b025`, que este documento
y la corrección del recuento de la auditoría convierten en `9374342`. Nada se da
por bueno de memoria.

## Resultado

| Comprobación | Resultado |
|---|---|
| Pruebas unitarias | **757 pasadas · 0 fallidas** · 103 suites |
| Avisos del compilador | **0** |
| `check-hosts` | ✅ |
| `check-navigation-links` | ✅ |
| `check-ui-register` | ✅ |
| `check-widget-palette` | ✅ |
| `check-deep-link` | ✅ (y los dos esquemas de control **no** resuelven) |
| Recorridos contra servidor real | **no ejecutados** en esta verificación |
| Auditoría de calidad nativa | ✅ 57 / 57 |
| Arranque en dispositivo real | ✅ iPhone 16 Pro, iOS 26.6, con sesión iniciada |
| Servidor de Release | ✅ `200` en 0,2 s · certificado válido hasta 2026-12-08 |

Sobre el recuento de pruebas: 757 casos ejecutados frente a 756 funciones
`@Test` contadas estáticamente. La diferencia es una prueba parametrizada, no un
descuadre.

El clon del simulador se comprobó: **uno solo**. El conteo de pruebas sobre un
log con dos clones suma dos corridas y da una cifra inventada, y ya ocurrió una
vez en este repo.

## Incidente: pantalla blanca al arrancar

### Qué pasó

Con una build de desarrollo **anterior** instalada en el iPhone, la aplicación
arrancaba y se quedaba en blanco: nunca aparecía el acceso. Desinstalar y
reinstalar lo resolvía por completo.

### Qué se descartó, y con qué evidencia

| Sospechoso | Cómo se descartó |
|---|---|
| Caída al arrancar | El proceso estaba vivo y en primer plano (`FBApplicationProcess`, `FG-Active`) |
| Servidor o certificado | `200` en 0,2 s; certificado válido |
| Colores ausentes en Release | Los 14 *colorsets* están en `Assets.car` |
| Bloqueo biométrico atascado | `appLock.enabled = false`, leído del dispositivo |
| Estado persistido (App Group, instantánea, llavero) | `hasRestoredSession` no se persiste: `LaunchView` tiene que pintarse siempre |
| El paso a Swift 6 (`7a2b025`) | **Reproducido y refutado**: instalada la versión anterior, iniciada sesión, navegado y actualizada encima — arranca bien |
| Cambio de firma desarrollo → distribución | `application-identifier` y App Group son idénticos; solo cambia `get-task-allow` |

### Lo que sí quedó establecido

`UILaunchScreen` es un diccionario vacío, de modo que la pantalla de arranque de
iOS es blanco liso. Lo que se veía **no era una pantalla rota de la aplicación**:
era la pantalla del sistema, que la aplicación no llegaba a sustituir.

### Estado

**Sin reproducir y cerrado por ahora.** La build entregada arranca
correctamente en dispositivo real con sesión iniciada, verificado el 2026-09-16.
La instalación que fallaba era una build de desarrollo antigua que ya no existe.

Queda escrito porque un incidente que no se reproduce, si no se documenta, se
vuelve a investigar entero la próxima vez.

### Dos hipótesis que se comunicaron antes de verificarlas

Conviene dejarlas por escrito porque el error de método importa más que las
hipótesis:

1. **«Solo ocurre en Release.»** Falso. El control —la misma prueba con la build
   de Debug— dio idéntico resultado. La supuesta reproducción era un diálogo
   «¿Abrir en…?» que `check-deep-link.sh` dejó atascado en el simulador, tapando
   la aplicación.
2. **«La instalación está corrupta.»** Falso. El `-10814` («not installed») fue
   transitorio, con el disco de desarrollo sin montar. Se verificó antes de
   comunicarlo.

Cinco hipótesis cayeron durante la investigación, y **las cinco cayeron por un
caso de control**, ninguna por casualidad.

## Pendientes conocidos

- **TestFlight no es utilizable por el propietario del proyecto**: el código de
  verificación de la cuenta no llega, así que la build subida no se ha podido
  instalar desde ese canal. Afecta a la distribución a probadores, no al
  producto. El canal adecuado para el entregable institucional es Custom App vía
  Apple Business Manager.
- **Numeración de versiones**: dos binarios distintos han convivido como
  `2.0 (1)`. Incrementar `CFBundleVersion` en cada build que salga del equipo,
  o no hay forma de saber qué se está probando.
- Los recorridos automatizados se ejecutan a mano, no en integración continua.

## Estado final sobre el tag `entrega-2026-09-16`

Lo de arriba se midió sobre `7a2b025` la mañana del 16. Desde entonces hubo una
tanda de trabajo y una revisión adversarial de la entrega (ocho revisores
independientes, refutación por tres lentes). Esto es lo que hay en el árbol
etiquetado, medido de nuevo:

| Comprobación | Resultado |
|---|---|
| Pruebas unitarias | **794 casos · 0 fallidas** (793 funciones `@Test` en 90 ficheros) |
| Guardas de proyecto (`check-*`) | **6 de 6**, incluida `check-build-number` |
| Número de build | derivado del historial; `verificar.sh` lo comprueba |
| Recorrido · aspirante en iPhone | 6 pasadas · 0 fallidas contra el servidor real |
| Recorrido · instructor en iPhone | entra, navega y pinta la tabla de resultados; el detalle del intento se salta por datos (la convocatoria de prueba no tiene celdas con nota) |
| Recorridos en iPad | sin ejecutar |
| Arranque en dispositivo real | iPhone 16 Pro · iOS 26.6 · con sesión iniciada |

### Dos defectos encontrados y corregidos después de la primera verificación

1. **El desbloqueo con Face ID entraba en bucle.** `leftForegroundAt = nil`
   significaba «arranque en frío» y también «acabo de desbloquear»; el diálogo
   del sistema devuelve el foco, eso cuenta como activación, y se volvía a
   pedir. Corregido con `resolvedInThisForeground` y `shouldAsk(alreadyResolved:)`
   sin valor por defecto. Rojo verificado antes del arreglo.
2. **El segundo bucle, el de la autenticación fallida.** Con la tapa puesta tras
   un intento que no salió, el foco relanzaba el diálogo y dejaba «Desbloquear»
   y «Cerrar sesión» sin poder pulsarse. Lo encontró la revisión adversarial,
   no un usuario. Corregido: `sceneBecameActive` no hace nada si la tapa ya
   está puesta; la decisión es de la persona.

### Lo que la revisión adversarial corrigió en los documentos

- Las tablas por carpeta de la memoria y del documento de entrega arrastraban
  el desglose de una revisión anterior (113 ficheros · 15 598) con el titular
  ya actualizado (15 750). Regeneradas desde el árbol entregado.
- La memoria daba tres cifras distintas de pruebas (765 / 788 / 790) y 133
  commits; el árbol etiquetado tiene 793 funciones, 794 casos, y tantos commits como número de build —la guarda `check-build-number.sh` lo comprueba en cada verificación, así que la cifra exacta se lee en el propio árbol y no aquí, donde envejecería con el siguiente commit.
- `GreetingCard` no usaba `GreetingCopy`: siete pruebas verificaban un tipo que
  ninguna pantalla pintaba. Ahora la vista pinta lo que se prueba.
- `MyAttemptsViewModel` era el décimo modelo de vista y el único sin costura
  de pruebas; la memoria decía «cuatro de cuatro» contando solo cuatro.
- El widget declaraba iOS 26.5 como mínimo y la app 26.4. Unificados a 26.4.
- Los documentos decían «requiere Xcode 26.4»; se construyó y probó con 26.6,
  y eso es lo que ahora dicen.
- Anexo A: `/convocatorias` y `/convocatorias/{id}` son solo de instructor;
  `/attempts/{id}` y `/attempts/{id}/gps` los ven los dos roles.
- La memoria y `CLAUDE.md` decían que el repositorio es privado; es público
  desde la entrega.

### Historial público: cuentas de semilla

El cuerpo del commit `7168625` (2026-04-30) enumera cuatro cuentas de semilla
del backend (`@cmadrid.com`) con sus contraseñas de desarrollo. El árbol no las
contiene, pero el historial es público. Se probaron las cuatro contra el
servidor el 2026-09-17: **las cuatro rechazadas (401)**. No se reescribe el
historial —rompería los clones— y queda anotado para que nadie las reutilice.
