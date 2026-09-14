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
if pgrep -f "xcodebuild test" >/dev/null 2>&1; then
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

# El simulador primero, que es la cura del cuelgue de hoy. Nunca matar
# CoreSimulatorService: apagar los dispositivos basta y es reversible.
xcrun simctl shutdown all >/dev/null 2>&1

echo "▸ Rol: $ROL · destino: $DESTINO"
echo "▸ Configuración: $CONFIGURACION · servidor: $HOST"
echo "▸ STAGING_REQUIRED=1: sin credenciales esto FALLA, no se salta."
echo

# `TEST_RUNNER_` lo reenvía xcodebuild al runner quitando el prefijo.
# Las variables van solo en el entorno de este proceso: no se imprimen, y el
# `set -x` está deliberadamente apagado para que no acaben en ningún log.
TEST_RUNNER_STAGING_EMAIL="$EMAIL" \
TEST_RUNNER_STAGING_PASSWORD="$PASSWORD" \
TEST_RUNNER_STAGING_REQUIRED=1 \
TEST_RUNNER_STAGING_ROLE="$ROL" \
# La salida CRUDA se guarda siempre, y el filtro se aplica a la copia.
#
# El filtro existía sin red de seguridad, y se comió la causa de un fallo: una
# corrida terminó con «TEST FAILED», cero tests ejecutados y nada más en
# pantalla, porque el motivo real no encajaba en ninguno de los patrones. Un
# envoltorio que esconde por qué falló es peor que no tenerlo: manda a quien lo
# lee a buscar el defecto en la app, que es donde no está.
CRUDO=$(mktemp -t staging-walkthrough)

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
