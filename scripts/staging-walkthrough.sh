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

DESTINO="${STAGING_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

# El simulador primero, que es la cura del cuelgue de hoy. Nunca matar
# CoreSimulatorService: apagar los dispositivos basta y es reversible.
xcrun simctl shutdown all >/dev/null 2>&1

echo "▸ Rol: $ROL · destino: $DESTINO"
echo "▸ STAGING_REQUIRED=1: sin credenciales esto FALLA, no se salta."
echo

# `TEST_RUNNER_` lo reenvía xcodebuild al runner quitando el prefijo.
# Las variables van solo en el entorno de este proceso: no se imprimen, y el
# `set -x` está deliberadamente apagado para que no acaben en ningún log.
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
  2>&1 | rg -v "CHHapticPattern" \
       | rg "error:|XCTAssert|XCTFail|Test skipped|Test Case .* (passed|failed|skipped)|Test run with|TEST (SUCCEEDED|FAILED)|Assertion Failure"

# El código de salida es el de xcodebuild, no el del filtro.
exit "${PIPESTATUS[0]}"
