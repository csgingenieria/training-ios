#!/bin/bash
#
# Enforces the formal peninsular Spanish register ("usted") across every UI
# string literal in the app and widget targets.
#
# Why a script and not a unit test: the offending string was inside a SwiftUI
# `Text(...)` literal in a View body. The unit tests only reach strings exposed
# through a type's API — `APIError.userMessage` and friends — so the register
# test passed for months while the logout dialog addressed the user as "tú".
# The reader is a Madrid firefighter reading an official process. Register is
# not a style preference here.
#
# Scans string literals only, so Swift identifiers and comments are ignored.
#
set -uo pipefail
cd "$(dirname "$0")/.."

TARGETS=("Dobacksoft Training" "Dobacksoft Training Widgets")

# Informal second person singular: peninsular tuteo and Rioplatense voseo.
BANNED='\b(vas|vais|irás|tendrás|podrás|deberás|harás|verás|sabrás|querrás|puedes|debes|tienes|quieres|sabes|tu|tus|ti|contigo|tuyo|tuya|tuyos|tuyas|pulsa|toca|revisa|comprueba|introduce|escribe|elige|selecciona|vuelve|inténtalo|intenta|espera|avisa|mira|haz|tenés|podés|querés|sabés|probá|revisá|fijate|andá|vos|dale)\b'

hallazgos=0
for objetivo in "${TARGETS[@]}"; do
  [ -d "$objetivo" ] || continue
  while IFS= read -r linea; do
    echo "  $linea"
    hallazgos=$((hallazgos + 1))
  done < <(rg --no-heading --line-number --only-matching '"[^"\\]{4,}"' \
              --glob '*.swift' "$objetivo" \
           | rg --ignore-case "$BANNED")
done

if [ "$hallazgos" -gt 0 ]; then
  echo
  echo "✗ $hallazgos UI string(s) address the user informally."
  echo "  Use the formal register: «Vuelva a iniciar sesión», not «Vuelve a iniciar sesión»."
  exit 1
fi

echo "✓ UI register: formal throughout."
