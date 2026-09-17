#!/usr/bin/env bash
#
# ¿Este binario se puede distinguir del anterior?
#
# El 2026-09-16 convivieron DOS binarios distintos llamados `2.0 (1)`: uno
# instalado en un teléfono y otro recién compilado. Cuando uno de los dos falló,
# no había forma de saber cuál se estaba ejecutando, y media mañana se fue en
# descartar hipótesis que un número de build habría resuelto en diez segundos.
#
# `CURRENT_PROJECT_VERSION` se deriva del número de commits: es monotónico, no
# hay que acordarse de subirlo, y dos árboles distintos no pueden compartirlo
# salvo que sean el mismo commit.
#
# Esta guarda NO modifica nada. Dice si el proyecto está desalineado y cómo
# alinearlo, porque tocar el `pbxproj` en automático a mitad de una entrega es
# peor que el problema que resuelve.
#
# Uso:
#   bash scripts/check-build-number.sh          comprueba
#   bash scripts/check-build-number.sh --fix    alinea y lo dice
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
PROYECTO="Dobacksoft Training.xcodeproj/project.pbxproj"
[ -f "$PROYECTO" ] || { echo "✗ No encuentro $PROYECTO"; exit 2; }

ESPERADO=$(git rev-list --count HEAD 2>/dev/null)
if [ -z "$ESPERADO" ]; then
    # Un árbol exportado (la carpeta de entrega) no tiene historia. La guarda
    # no es aplicable ahí, y «no aplicable» no es «fallo»: quien evalúa desde
    # esa carpeta no debe ver un rojo por algo que no puede corregir.
    echo "· Sin historia de git: esta guarda no es aplicable fuera del repositorio."
    exit 0
fi

# Todas las configuraciones tienen que llevar el MISMO número. Si una se queda
# atrás, Debug y Release dejan de ser comparables — que es justo el escenario
# que se pagó.
# Sin `mapfile`: el bash de macOS es 3.2 y no lo trae.
ACTUALES=$(grep -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PROYECTO" | grep -o '[0-9]*$' | sort -u)
DISTINTOS=$(echo "$ACTUALES" | grep -c .)

if [ "${1:-}" = "--fix" ]; then
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $ESPERADO;/g" "$PROYECTO"
    echo "✓ CURRENT_PROJECT_VERSION = $ESPERADO en todas las configuraciones."
    echo "  Inclúyalo en el commit que está preparando con \`git commit --amend\`."
    echo "  Si lo confirma como commit NUEVO, el árbol pasa a $((ESPERADO + 1)) y la"
    echo "  guarda volverá a pedir --fix: es lo que pasó dos veces el 16/09."
    exit 0
fi

if [ "$DISTINTOS" -ne 1 ]; then
    echo "✗ Las configuraciones NO comparten número de build: $(echo $ACTUALES | tr '\n' ' ')"
    echo "  Debug y Release dejan de ser comparables. Alinee con:"
    echo "      bash scripts/check-build-number.sh --fix"
    exit 1
fi

ACTUAL="$ACTUALES"
if [ "$ACTUAL" != "$ESPERADO" ]; then
    echo "✗ El número de build es $ACTUAL y este árbol va por el commit $ESPERADO."
    echo ""
    echo "  Distribuir así repite un número ya usado, y entonces «me falla la app»"
    echo "  deja de ser una frase accionable: no se sabe qué binario es."
    echo ""
    echo "  Alinee con:"
    echo "      bash scripts/check-build-number.sh --fix"
    exit 1
fi

echo "✓ Número de build $ACTUAL, alineado con la historia ($ESPERADO commits)."
