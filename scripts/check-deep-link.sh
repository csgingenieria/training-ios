#!/bin/bash
#
# Verifies the one link in the widget→app chain that no unit test can reach:
# that the SYSTEM actually routes our URL scheme to this app.
#
# The unit tests cover the scheme constant, the parser, the inbox and the
# declaration in Info.plist. All four can be green while the tap still does
# nothing, because what decides whether `onOpenURL` ever fires is LaunchServices
# having registered the scheme from the INSTALLED bundle.
#
# The control case is the point. `simctl openurl` returning 0 means nothing on
# its own — so this script also opens two schemes that must NOT resolve. If they
# succeed, the check is not measuring anything and says so instead of passing.
#
set -uo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro}"
SCHEME="dobacksoft-training"
LINK="$SCHEME://mi-posicion"

udid=$(xcrun simctl list devices available | rg "$DEVICE \(" | rg -o "[0-9A-F-]{36}" | head -1)
if [ -z "$udid" ]; then
  echo "✗ No hay simulador «$DEVICE» disponible."
  exit 1
fi

app=$(xcodebuild -project "Dobacksoft Training.xcodeproj" \
                 -scheme "Dobacksoft Training" \
                 -destination "platform=iOS Simulator,name=$DEVICE" \
                 -showBuildSettings 2>/dev/null \
      | rg -o "BUILT_PRODUCTS_DIR = .*" | head -1 | sd "BUILT_PRODUCTS_DIR = " "")

bundle="$app/Dobacksoft Training.app"
if [ ! -d "$bundle" ]; then
  echo "✗ No hay app compilada en $bundle. Compile primero."
  exit 1
fi

xcrun simctl boot "$udid" >/dev/null 2>&1
xcrun simctl install "$udid" "$bundle" || exit 1

fallos=0

# El enlace real: tiene que entregarse.
if xcrun simctl openurl "$udid" "$LINK" >/dev/null 2>&1; then
  echo "✓ El sistema entrega $LINK a la app."
else
  echo "✗ El sistema NO entrega $LINK. ¿Está el esquema en CFBundleURLTypes?"
  fallos=$((fallos + 1))
fi

# Los controles: NO pueden entregarse. Si entregan, este script no mide nada.
for control in "$SCHEME-noexiste://mi-posicion" "esquema-inventado://mi-posicion"; do
  if xcrun simctl openurl "$udid" "$control" >/dev/null 2>&1; then
    echo "✗ Se entregó «$control», que no está registrado por nadie."
    echo "  El caso de control falla, así que el ✓ de arriba no prueba nada."
    fallos=$((fallos + 1))
  fi
done

if [ "$fallos" -gt 0 ]; then
  exit 1
fi

echo "✓ Enlace profundo: esquema registrado, y los controles no resuelven."
