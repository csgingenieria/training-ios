#!/bin/bash
#
# Corre el recorrido de staging leyendo las credenciales del Keychain.
#
# Por qué el Keychain y no un `.env`: la app tiene una regla firme —los tokens
# van al Keychain, nunca a un archivo plano— y guardar en texto claro las
# credenciales de dos cuentas reales de CMadrid, bajo NDA, contradiría su propia
# postura de seguridad. Además `.env` está en `.gitignore`, y un archivo que
# git ignora es un archivo que nadie revisa.
#
# LO QUE ESTO NO PROTEGE, dicho claro: si el script las lee sin preguntar, las
# lee cualquier cosa que corra como este usuario. El Keychain protege el disco
# en reposo y un backup, no a un proceso local. Es la contrapartida de poder
# correr los tests sin teclear nada; con `-A` al guardarlas se acepta, sin `-A`
# el sistema pide permiso una vez por corrida.
#
# Guardarlas (una sola vez, y NO desde un agente — que no pasen por su contexto
# ni por el historial que lee):
#
#   security add-generic-password -U -s training-ios-staging-student \
#     -a 'correo@del.aspirante' -w
#   security add-generic-password -U -s training-ios-staging-manager \
#     -a 'correo@del.instructor' -w
#
# `-w` sin valor hace que pida la contraseña por teclado, sin eco y sin dejarla
# en el historial del shell. La CUENTA (`-a`) es el correo; la contraseña es el
# secreto.
#
# Uso:
#   scripts/staging-walkthrough.sh student
#   scripts/staging-walkthrough.sh manager [-only-testing:…/testAttemptDetail]
#
set -uo pipefail
cd "$(dirname "$0")/.."

ROL="${1:-}"
case "$ROL" in
  student|manager) ;;
  *)
    echo "Uso: $0 student|manager [argumentos extra de xcodebuild]"
    echo
    echo "El rol no es opcional: sin declararlo, el recorrido se salta las"
    echo "pantallas que ese rol no tiene y NO distingue «este rol no la tiene»"
    echo "de «esta pantalla está rota». Las dos corridas dirían que todo va bien."
    exit 2
    ;;
esac
shift

# Contra QUÉ host corre esto, dicho en voz alta y comprobado.
#
# El script se llama «staging» y la configuración que lleva ese nombre
# —`Config/Staging.xcconfig`— apunta a `staging.cmadrid-training.com`, un host
# que NO resuelve y que ningún esquema usa. El esquema compila en Debug, así
# que el recorrido corre contra el host de Debug. Un verde de este script no
# decía nada del host cuyo nombre lleva, y nadie lo habría notado hasta el día
# en que alguien cambiara el esquema y la app apuntara a la nada.
CONFIGURACION="${STAGING_CONFIGURATION:-Debug}"
HOST=$(rg -N '^BASE_URL' "Config/$CONFIGURACION.xcconfig" 2>/dev/null \
       | sd '\$\(\)' '' | sd '^.*//' '' | sd '/.*$' '')

if [ -z "${HOST:-}" ]; then
  echo "✗ No se pudo leer BASE_URL de Config/$CONFIGURACION.xcconfig."
  exit 4
fi

if [ -z "$(dig +short "$HOST" 2>/dev/null)" ]; then
  echo "✗ El host de la configuración «${CONFIGURACION}» no resuelve: ${HOST}"
  echo
  echo "  Un recorrido que no puede llegar al servidor no falla por la app."
  echo "  Corregí el .xcconfig, o pasá STAGING_CONFIGURATION=<otra>."
  exit 4
fi

SERVICIO="training-ios-staging-$ROL"

EMAIL=$(security find-generic-password -s "$SERVICIO" 2>/dev/null \
        | rg -o '"acct"<blob>="(.*)"' -r '$1')
PASSWORD=$(security find-generic-password -s "$SERVICIO" -w 2>/dev/null)

if [ -z "${EMAIL:-}" ] || [ -z "${PASSWORD:-}" ]; then
  echo "✗ No hay credenciales de «${ROL}» en el Keychain (servicio: $SERVICIO)."
  echo
  echo "  Guardalas con:"
  echo "    security add-generic-password -U -s $SERVICIO -a 'correo@…' -w"
  echo
  echo "  El -w sin valor las pide por teclado: no quedan en el historial."
  exit 1
fi

# Una corrida a la vez, y esto no es una recomendación.
#
# Dos `xcodebuild test` sobre el mismo simulador se pelean por `testmanagerd`:
# el desmontaje del primero termina la app del segundo y sale «Test crashed
# with signal term». Y una corrida de iPad con la suite unitaria encima agota
# la máquina y sale «No session after 30 s» más «Result bundle saving failed …
# mkstemp: No such file or directory».
#
# Las dos cosas parecen defectos de la app y no lo son. Costaron cuatro
# diagnósticos falsos en una tarde, uno de ellos a punto de reportarse como
# hallazgo. Aislado, lo mismo pasa dos veces seguidas.
# `pgrep -x`, no `-f`: `-f` casa con CUALQUIER proceso cuya línea de comandos
# contenga «xcodebuild test», incluido un vigilante que compruebe si hay
# corridas en marcha. Así, el propio observador abortaba los recorridos que
# venía a observar, y el mensaje culpaba a una contención que no existía.
if pgrep -x xcodebuild >/dev/null 2>&1; then
  echo "✗ Ya hay un «xcodebuild test» corriendo."
  echo
  echo "  Dos corridas sobre el mismo simulador producen fallos que parecen de"
  echo "  la app: «signal term», «No session after 30 s», bundles a medio"
  echo "  escribir. Espere a que termine, o:"
  echo "    pkill -f 'xcodebuild test'; xcrun simctl shutdown all"
  echo
  echo "  Nunca matar CoreSimulatorService: apagar los dispositivos basta."
  exit 3
fi

DESTINO="${STAGING_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

# El simulador se BORRA, no solo se apaga.
#
# Apagar no quita el estado acumulado. Medido: el subsistema de accesibilidad
# de XCUITest se degrada POR RECORRIDO, no por dispositivo. Un iPad Air recien
# borrado paso los siete tests que le tocan; el segundo recorrido seguido sobre
# ese mismo simulador dio cinco fallos, todos «Failed to get matching
# snapshots», uno con la frase que lo explica: «Unable to perform work on main
# run loop». El bucle principal del proceso de test deja de responder.
#
# Eso confundio el diagnostico un buen rato: `erase` parecio no servir porque se
# hizo UNA vez y luego se corrieron DOS recorridos. La cura es borrar antes de
# cada uno.
#
# Nunca matar CoreSimulatorService: borrar el dispositivo basta y es reversible.
xcrun simctl shutdown all >/dev/null 2>&1

NOMBRE_DESTINO=$(echo "$DESTINO" | sd '.*name=' '')
# Literal primero (`-F`), y el UDID después. `rg` no soporta `\Q…\E`, y una
# expresión construida con el nombre del dispositivo dentro se rompe sola: «iPad
# Air 11-inch (M4)» lleva paréntesis. El « (» final distingue «iPhone 17 Pro»
# de «iPhone 17 Pro Max».
UDID=$(xcrun simctl list devices available 2>/dev/null \
       | rg -F "$NOMBRE_DESTINO (" \
       | rg -o '\(([0-9A-F-]{36})\)' -r '$1' | head -1)

# Por defecto NO se borra, y esto se midió en las dos direcciones.
#
# Borrar cura la degradación de accesibilidad, sí. Pero borra también la app
# instalada, así que el PRIMER test de cada recorrido arranca completamente en
# frío y se queda sin sesión a los 30 s. Medido en el mismo recorrido de
# instructor en iPhone: sin borrar 3 pasan y 0 fallan; con borrado 1 pasa y 2
# fallan. Se cambió un fallo intermitente al final de una sesión larga por uno
# fijo al principio de cada recorrido: peor negocio.
#
# Queda como opción, pero **no como cura de la degradación**, que es lo que se
# creyó al principio y resultó falso.
#
# Medido en el mismo recorrido, tras tres corridas seguidas en la máquina:
# sin borrar, dos tests fallan con «Failed to resolve query: Timed out»;
# CON `STAGING_ERASE=1`, el runner de UI no llega ni a arrancar —«Timed out
# while loading»— y se ejecutan cero tests. Borrar no mejora nada ahí.
#
# Lo que hay tras muchas horas y decenas de instalaciones es un límite de la
# máquina que `erase` no toca, porque el estado que estorba no vive en el
# dispositivo. Lo único que se ha visto funcionar es dejarla reposar.
#
# Entonces, ¿para qué sigue existiendo? Para partir de un simulador sin sesión
# ni app previa cuando eso es lo que se quiere probar. No para arreglar una
# corrida que va mal.
if [ -z "${STAGING_ERASE:-}" ]; then
  :
elif [ -n "${UDID:-}" ]; then
  xcrun simctl erase "$UDID" >/dev/null 2>&1 \
    && echo "▸ Simulador «${NOMBRE_DESTINO}» borrado a estado limpio." \
    || echo "▸ No se pudo borrar «${NOMBRE_DESTINO}»; se sigue."
else
  echo "▸ No se resolvio el UDID de «${NOMBRE_DESTINO}»; se sigue sin borrar."
fi

echo "▸ Rol: $ROL · destino: $DESTINO"
echo "▸ Configuración: $CONFIGURACION · servidor: $HOST"
echo "▸ STAGING_REQUIRED=1: sin credenciales esto FALLA, no se salta."
echo

# `TEST_RUNNER_` lo reenvía xcodebuild al runner quitando el prefijo.
# Las variables van solo en el entorno de este proceso: no se imprimen, y el
# `set -x` está deliberadamente apagado para que no acaben en ningún log.
# La salida CRUDA se guarda siempre, y el filtro se aplica a la copia.
#
# El filtro existía sin red de seguridad, y se comió la causa de un fallo: una
# corrida terminó con «TEST FAILED», cero tests ejecutados y nada más en
# pantalla, porque el motivo real no encajaba en ninguno de los patrones. Un
# envoltorio que esconde por qué falló es peor que no tenerlo: manda a quien lo
# lee a buscar el defecto en la app, que es donde no está.
CRUDO=$(mktemp -t staging-walkthrough)

# **Nada entre estas asignaciones y `xcodebuild`.** Van encadenadas con `\` y
# solo valen para el comando que sigue: meter un comentario en medio rompe la
# continuación y xcodebuild arranca SIN credenciales. Pasó exactamente eso al
# añadir el volcado de la salida cruda, y el recorrido entero se saltó.
TEST_RUNNER_STAGING_EMAIL="$EMAIL" \
TEST_RUNNER_STAGING_PASSWORD="$PASSWORD" \
TEST_RUNNER_STAGING_REQUIRED=1 \
TEST_RUNNER_STAGING_ROLE="$ROL" \
xcodebuild test \
  -project "Dobacksoft Training.xcodeproj" \
  -scheme "Dobacksoft Training" \
  -destination "$DESTINO" \
  -parallel-testing-enabled NO \
  "${@:--only-testing:Dobacksoft TrainingUITests/StagingWalkthroughUITests}" \
  > "$CRUDO" 2>&1
SALIDA=$?

rg -v "CHHapticPattern" "$CRUDO" \
  | rg "error:|XCTAssert|XCTFail|Test skipped|Test Case .* (passed|failed|skipped)|Test run with|TEST (SUCCEEDED|FAILED)|Assertion Failure"

# Una corrida que se SALTÓ todo no es una corrida verde.
#
# Este script siempre pasa credenciales y `STAGING_REQUIRED=1`, que existe para
# que su ausencia FALLE en vez de saltarse. Pero el entorno no siempre llega:
# si xcodebuild relanza la corrida —por ejemplo, porque el simulador se apagó
# debajo—, el segundo intento arranca sin las variables, los ocho tests se
# saltan «SIN CREDENCIALES» y xcodebuild dice `TEST SUCCEEDED` con salida 0.
#
# Pasó de verdad: una corrida de iPad iba a reportarse como verde habiendo
# probado exactamente nada. El propio mensaje del salto lo avisa —«esta corrida
# no prueba nada sobre él, aunque xcodebuild diga TEST SUCCEEDED»— y aun así el
# código de salida decía que sí.
#
# El guard tiene que vivir AQUÍ, donde sí se sabe que se pasaron credenciales.
if rg -q "SIN CREDENCIALES" "$CRUDO" 2>/dev/null; then
  echo
  echo "✗ Hubo tests saltados por falta de credenciales, y este script SÍ las pasó."
  echo
  echo "  Significa que el entorno no llegó al proceso de test —normalmente"
  echo "  porque xcodebuild relanzó la corrida—. Lo que xcodebuild diga de esa"
  echo "  segunda pasada no vale: no ejecutó el recorrido."
  echo "  Salida cruda completa en $CRUDO"
  SALIDA=1
fi

# Si falló SIN que el filtro haya explicado nada, se enseña el final crudo.
if [ "$SALIDA" -ne 0 ]; then
  ejecutados=$(rg -c "Test Case .* (passed|failed|skipped) \(" "$CRUDO" 2>/dev/null || echo 0)
  if [ "${ejecutados:-0}" -eq 0 ]; then
    echo
    echo "▸ Falló sin ejecutar un solo test. Final de la salida cruda:"
    echo "  (completa en $CRUDO)"
    tail -25 "$CRUDO" | sed 's/^/    /'
  fi
fi

exit "$SALIDA"
