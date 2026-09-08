#!/bin/bash
#
# Ningún `NavigationLink` de DESTINO en el target de la app.
#
# Con un `NavigationStack(path:)` de camino enlazado —que es lo que hace
# `DashboardRouter` para cada sección— una vista empujada por un enlace de
# destino queda FUERA de la pila gestionada, y todo lo que ella contenga deja de
# navegar: la pantalla se abre y por dentro está muerta.
#
# Apareció SEIS veces en un solo día, en seis archivos, y cada aparición costó
# una investigación entera: la tabla del instructor no abría nada, y el perfil
# tampoco. La segunda tanda se le escapó a un barrido a mano porque usaba la
# forma con el rótulo como primer argumento —`NavigationLink("Mi PIN") { … }`—
# y el patrón buscaba `NavigationLink {`. Un barrido que no cubre todas las
# formas deja el defecto y la sensación de haberlo barrido.
#
# Las tres formas de destino, todas prohibidas:
#   NavigationLink { destino } label: { … }
#   NavigationLink("rótulo") { destino }
#   NavigationLink(destination: destino) { … }
#
# La forma correcta es siempre por valor: `NavigationLink(value:)` más un
# `navigationDestination(for:)` en la RAÍZ del cuerpo — nunca dentro de una rama
# condicional, que es el defecto hermano de este.
#
# Se ignoran los comentarios: este guardián describe el defecto que persigue, y
# sin quitarlos se encontraría a sí mismo. Es el mismo cuidado que
# `check-ui-register.sh`, que solo mira literales.
#
set -uo pipefail
cd "$(dirname "$0")/.."

PATRON='NavigationLink[[:space:]]*\{|NavigationLink\("[^"]*"\)[[:space:]]*\{|NavigationLink\(destination:'

# Se buscan las líneas y luego se descartan las que solo lo mencionan en un
# comentario. Se quitan los dos estilos: `//` hasta fin de línea y `/* … */` en
# la misma línea. Con el primero solo, un `/* NavigationLink { x } */` daba
# falso positivo — y un guardián que da falsos positivos enseña a ignorarlo,
# que es peor que no tenerlo.
encontrados=$(rg --line-number --glob '*.swift' "$PATRON" "Dobacksoft Training" 2>/dev/null \
              | sd '/\*.*?\*/' '' \
              | sd '//.*$' '' \
              | rg "$PATRON" \
              || true)

if [ -n "$encontrados" ]; then
  echo "✗ Enlaces de navegación por DESTINO en el target de la app:"
  echo "$encontrados" | sed 's/^/  /'
  echo
  echo "  Con la pila de cada sección enlazada al router, estos empujan fuera"
  echo "  de ella y las pantallas que abren no pueden navegar por dentro."
  echo "  Use NavigationLink(value:) + navigationDestination(for:) en la raíz."
  exit 1
fi

echo "✓ Navegación: ningún enlace por destino, solo por valor."
