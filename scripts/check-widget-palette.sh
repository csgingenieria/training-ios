#!/bin/bash
#
# The widget's palette is a COPY of the app's, and a copy drifts.
#
# It has to be a copy: `Bundle.main` inside an app extension is the extension,
# so the app's asset catalog is not reachable from the widget. What is avoidable
# is the two drifting apart — the app shipping one blue and the widget another,
# with nothing failing.
#
# Checks two things per token:
#   1. It exists in the widget catalog and is byte-identical to the app's.
#   2. It declares a dark appearance. Seven hex literals were the original
#      defect: the widget was a cream card on a dark home screen, ignoring the
#      appearance the app honours everywhere.
#
# The control case is built in: a token missing from the app catalog is a bug in
# this script's own list, and it says so instead of passing.
#
set -uo pipefail
cd "$(dirname "$0")/.."

APP="Dobacksoft Training/Assets.xcassets/Colors"
WIDGET="Dobacksoft Training Widgets/Assets.xcassets/Colors"

# Los tokens que el widget usa de verdad. Añadir uno aquí sin copiarlo falla.
TOKENS=(Paper Ink Muted Brand BrandTint Success Danger)

fallos=0

# Control: cada token declarado tiene que existir en el catálogo de la app.
# Si no, la lista de arriba está mal y este script no está comparando nada.
for token in "${TOKENS[@]}"; do
  if [ ! -f "$APP/$token.colorset/Contents.json" ]; then
    echo "✗ «$token» no existe en el catálogo de la app."
    echo "  La lista de este script está mal: no hay contra qué comparar."
    fallos=$((fallos + 1))
  fi
done

# Y los tokens que el widget usa en el código tienen que estar en la lista.
usados=$(rg -o 'Color\("([A-Za-z]+)", bundle: \.main\)' -r '$1' \
            "Dobacksoft Training Widgets/SharedAssets.swift" | sort -u)
for token in $usados; do
  if ! printf '%s\n' "${TOKENS[@]}" | rg -qx "$token"; then
    echo "✗ El widget usa «$token» y este script no lo comprueba."
    fallos=$((fallos + 1))
  fi
done

for token in "${TOKENS[@]}"; do
  app_json="$APP/$token.colorset/Contents.json"
  widget_json="$WIDGET/$token.colorset/Contents.json"

  if [ ! -f "$widget_json" ]; then
    echo "✗ Falta «$token» en el catálogo del widget."
    fallos=$((fallos + 1))
    continue
  fi

  if ! diff -q "$app_json" "$widget_json" >/dev/null; then
    echo "✗ «$token» ha derivado: el widget y la app ya no dicen el mismo color."
    diff "$app_json" "$widget_json" | head -12
    fallos=$((fallos + 1))
  fi

  if ! rg -q '"value"\s*:\s*"dark"' "$widget_json"; then
    echo "✗ «$token» no tiene variante oscura: el widget no seguiría la apariencia."
    fallos=$((fallos + 1))
  fi
done

if [ "$fallos" -gt 0 ]; then
  exit 1
fi

echo "✓ Paleta del widget: ${#TOKENS[@]} tokens, iguales a los de la app y con variante oscura."
