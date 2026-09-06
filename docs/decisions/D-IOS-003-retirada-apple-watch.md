# Decisión D-IOS-003 — Se retira el Apple Watch del proyecto

**Tipo**: decision
**Autor**: Antonio Hermoso
**Fecha**: 2026-09-06
**Estado**: activa
**Enmienda a**: `D-IOS-001` (regla de plataformas), que admitía el reloj como target ligero

## Qué

Se eliminan del proyecto los cuatro targets del Apple Watch:

- `Dobacksoft Training Watch` (contenedor)
- `Dobacksoft Training Watch Watch App`
- `Dobacksoft Training Watch Watch AppTests`
- `Dobacksoft Training Watch Watch AppUITests`

Plataformas soportadas a partir de ahora: **iPhone y iPad**, más la extensión de widget. El código sigue en el historial de git si algún día se retoma.

## Por qué

El reloj llevaba desde abril mostrando datos inventados —puesto 5 de 42, nota 8,25— bajo el rótulo «Mi posición». Un aspirante lo leía en su muñeca, en el parque, delante de sus compañeros. En la fase 4 se le retiró esa afirmación falsa y quedó diciendo la verdad: que no tiene el dato y que se consulta en el iPhone.

Quedaba decidir si integrarlo de verdad. Se descarta, por tres razones que se refuerzan entre sí:

**1. No es un caso de «añadir una llamada más».** El reloj corre en otro dispositivo: no comparte contenedor de App Group ni Keychain con el iPhone. Integrarlo exige transporte por WatchConnectivity con toda su casuística —reloj sin iPhone cerca, sesión no activada, cargas fuera de orden— y una cirugía de targets: cambiar el bundle id (hoy `Com.Dobacksoft-Training-Watch.watchkitapp`, que no cuelga del de la app y por tanto no se distribuye con ella), retirar `WKWatchOnly`, añadir `WKApplication` y el companion, y eliminar el target contenedor.

**2. Nadie lo ha pedido.** No aparece en el documento de entrega a CMadrid ni en el flujo operativo de campo. El aspirante consulta su posición cuando quiere, no mientras conduce; el instructor trabaja desde la tablet del kiosko y el panel.

**3. Un target que no se entrega cuesta igual.** Se compila, se revisa y se mantiene al día con cada cambio del modelo. Ya provocó un incidente real: en la fase 3, borrar seis copias de una función dejó dos llaves huérfanas en el reloj y el target dejó de compilar sin que la suite lo detectara, porque los tests son del target de iOS.

## Momento

Ahora es cuando sale más barato. El reloj no está en ningún esquema compartido, no se archiva y no se distribuye: **el radio de impacto es cero**. Cada semana que pasa se estrecha ese margen, y en cuanto alguien lo enchufe al build de entrega, sacarlo pasa a ser una regresión visible.

## Qué se conserva

- El diseño visual de las dos páginas del reloj vive en el historial (`git show d683b45 -- "Dobacksoft Training Watch Watch App/"`), por si se retoma.
- La arquitectura que lo haría posible **ya está construida**: `StandingSnapshot` es Foundation puro, sin UIKit ni SwiftUI, así que compila igual en watchOS. Un reloj futuro recibiría exactamente el mismo tipo por WatchConnectivity, sin rediseñar el contrato.

## Cómo se retomaría

1. Recrear el target como watch app *companion*: bundle id colgando del de la app, `WKApplication = YES`, `WKCompanionAppBundleIdentifier`, sin target contenedor.
2. `WCSession.updateApplicationContext` transportando el mismo `StandingSnapshot` codificado — último valor gana y se fusiona solo, que es justo la semántica de una instantánea. Nunca un delta: un parche perdido dejaría el reloj mezclando datos de dos personas.
3. El reloj persiste lo recibido y descarta cargas con `generation` menor que la que ya tiene.
4. Estados propios para reloj sin iPhone cerca y para dato de más de 48 horas, con la misma regla: si no hay dato, se dice.

## Referencias

- `D-IOS-001` — regla de plataformas original (`repos/training/memory/decision-ios-platform-rule.md`)
- `D-IOS-002` — la app entra al entregable a CMadrid (`docs/decisions/D-IOS-002-entregable-cmadrid.md`)
