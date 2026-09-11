#!/usr/bin/env bash
#
# ¿A qué servidor apunta cada configuración, y existe?
#
# El recorrido automatizado se llama «staging» y corre contra el host de
# **Debug**; `Config/Staging.xcconfig` apunta a un host que no resuelve y que
# ningún esquema usa; y `Config/Release.xcconfig` —la configuración con la que
# se construye lo que se instala en el teléfono de un bombero— apunta a
# `training.dobacksoft.com`, que **tampoco resuelve**.
#
# Nada de eso lo detectaba ningún test, y no por descuido: los 755 tests
# unitarios y los seis recorridos usan Debug. Una build de producción podía
# apuntar a la nada y salir todo verde.
#
# Esto no adivina el host bueno. Solo dice cuál declara cada configuración y si
# existe, que es la pregunta que nadie estaba haciendo.
set -uo pipefail
cd "$(dirname "$0")/.."

# Configuraciones que DEBEN resolver para considerarse utilizables. `Staging`
# no está: hoy es un archivo desconectado, documentado como tal.
declare -a OBLIGATORIAS=(Debug Release)

fallos=0
faltan=()

for archivo in Config/*.xcconfig; do
  config=$(basename "$archivo" .xcconfig)

  host=$(rg -N '^BASE_URL' "$archivo" 2>/dev/null \
         | sd '\$\(\)' '' | sd '^.*//' '' | sd '/.*$' '')

  # Un .xcconfig sin BASE_URL está roto sea obligatorio o no: no hay nada que
  # comprobar y una build con él no sabe a dónde ir.
  if [ -z "${host:-}" ]; then
    printf '  %-10s %-38s %s\n' "$config" "(sin BASE_URL)" "✗"
    fallos=$((fallos + 1))
    continue
  fi

  if [ -n "$(dig +short "$host" 2>/dev/null)" ]; then
    printf '  %-10s %-38s %s\n' "$config" "$host" "resuelve"
  else
    printf '  %-10s %-38s %s\n' "$config" "$host" "NO RESUELVE"
    faltan+=("$config")
    for obligatoria in "${OBLIGATORIAS[@]}"; do
      [ "$config" = "$obligatoria" ] && fallos=$((fallos + 1))
    done
  fi
done

echo
if [ "$fallos" -gt 0 ]; then
  echo "✗ $fallos configuración(es) sin un servidor utilizable."
  echo
  echo "  Una build con esa configuración no puede hablar con nadie, y ningún"
  echo "  test lo dice porque todos corren contra Debug."
  exit 1
fi

if [ "${#faltan[@]}" -gt 0 ]; then
  echo "· Configuraciones no obligatorias sin host: ${faltan[*]}"
fi
echo "✓ Todas las configuraciones obligatorias resuelven."
