#!/usr/bin/env bash
#
# Todo lo que tiene que estar verde antes de entregar o distribuir.
#
# Esto es la integración continua de este proyecto, y conviene explicar por qué
# no vive en GitHub Actions: el proyecto exige **Xcode 26.6** (Swift 6.3, iOS
# 26.4), y los runners públicos de macOS van varias versiones por detrás. Un
# workflow que falla siempre no es integración continua: es un semáforo en rojo
# permanente, y lo que enseña es a mirar para otro lado.
#
# Cuando los runners alcancen la versión, este script es lo que hay que llamar
# desde el workflow — no hay nada que reescribir.
#
# Uso:
#   bash scripts/verificar.sh            todo menos los recorridos
#   bash scripts/verificar.sh --todo     incluye los recorridos contra staging
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

SIMULADOR="${VERIFICAR_SIMULADOR:-iPhone 17 Pro}"
FALLOS=0
TOTAL=0

titulo () { printf "\n\033[1m── %s\033[0m\n" "$1"; }
paso () {
    TOTAL=$((TOTAL + 1))
    printf "  %-38s " "$1"
    shift
    if "$@" > /tmp/verificar-paso.log 2>&1; then
        printf "\033[32m✓\033[0m\n"
    else
        printf "\033[31m✗\033[0m\n"
        sed 's/^/      /' /tmp/verificar-paso.log | tail -8
        FALLOS=$((FALLOS + 1))
    fi
}

titulo "El árbol"
paso "sin cambios sin guardar" bash -c '[ -z "$(git status --porcelain)" ]'
paso "número de build alineado" bash scripts/check-build-number.sh

titulo "Las guardas"
for g in scripts/check-*.sh; do
    [ "$g" = "scripts/check-build-number.sh" ] && continue
    paso "$(basename "$g" .sh)" bash "$g"
done

titulo "Las pruebas"
# Una sola a la vez: dos `xcodebuild test` concurrentes se bloquean sobre la
# misma base de datos de compilación y el fallo no se parece en nada a su causa.
if pgrep -x xcodebuild > /dev/null; then
    echo "  ✗ Ya hay un xcodebuild corriendo. Una sola compilación a la vez."
    exit 1
fi
paso "suite unitaria" xcodebuild test \
    -project "Dobacksoft Training.xcodeproj" \
    -scheme "Dobacksoft Training" \
    -destination "platform=iOS Simulator,name=$SIMULADOR" \
    -only-testing:"Dobacksoft TrainingTests"

if [ "${1:-}" = "--todo" ]; then
    titulo "Los recorridos contra el servidor real"
    echo "  (necesitan credenciales en el llavero; degradan la máquina si se"
    echo "   repiten muchas veces seguidas)"
    paso "staging-walkthrough" bash scripts/staging-walkthrough.sh
fi

printf "\n"
if [ "$FALLOS" -eq 0 ]; then
    printf "\033[32m✓ %d de %d comprobaciones correctas.\033[0m\n" "$TOTAL" "$TOTAL"
    exit 0
fi
printf "\033[31m✗ %d de %d comprobaciones han fallado.\033[0m\n" "$FALLOS" "$TOTAL"
exit 1
