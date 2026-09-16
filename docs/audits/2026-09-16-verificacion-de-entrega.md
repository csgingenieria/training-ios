# Verificación de entrega — 2026-09-16

Comprobación del cliente antes de la entrega del proyecto. Todo lo que sigue se
midió el 2026-09-16 sobre `main` en `7a2b025`; nada se da por bueno de memoria.

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
