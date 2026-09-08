#!/bin/bash
#
# Enforces two things across every UI string literal in the app and widget
# targets: the formal peninsular Spanish register ("usted"), and the vocabulary
# that GDPR article 22 forbids this product from using.
#
# Why a script and not a unit test: the offending string was inside a SwiftUI
# `Text(...)` literal in a View body. The unit tests only reach strings exposed
# through a type's API — `APIError.userMessage` and friends — so the register
# test passed for months while the logout dialog addressed the user as "tú".
# The reader is a Madrid firefighter reading an official process. Register is
# not a style preference here.
#
# That same argument is why the vocabulary scan lives here TOO, and not only in
# `UICopyVocabularyTests`. The forbidden phrase «asignación de plaza» sat in two
# View bodies for months; a test that enumerates copy reachable through a type
# could not see it, and still cannot. The two guardians have different reach and
# neither replaces the other:
#
#   - This script sees every literal, including the ones typed straight into a
#     View body, but it can only match patterns.
#   - `UICopyVocabularyTests` cannot see View bodies, but it pins the exact
#     wording and the meaning — that the notice still names who decides and
#     that it happens outside the app, which no regular expression can check.
#
# Scans string literals only, so Swift identifiers and comments are ignored.
#
set -uo pipefail
cd "$(dirname "$0")/.."

TARGETS=("Dobacksoft Training" "Dobacksoft Training Widgets")

# Informal second person singular: peninsular tuteo and Rioplatense voseo.
REGISTRO='\b(vas|vais|irás|tendrás|podrás|deberás|harás|verás|sabrás|querrás|puedes|debes|tienes|quieres|sabes|tu|tus|ti|contigo|tuyo|tuya|tuyos|tuyas|pulsa|toca|revisa|comprueba|introduce|escribe|elige|selecciona|vuelve|inténtalo|intenta|espera|avisa|mira|haz|tenés|podés|querés|sabés|probá|revisá|fijate|andá|vos|dale)\b'

# GDPR art. 22: the system computes an objective mark and issues NO verdict.
# Admission is decided by CMadrid, outside the system, at the formal close.
#
# Phrases and plurals, deliberately NOT the bare root «plaza». The kiosk
# enrolment number is also called «plaza» — «Nombre o plaza» is the search field
# an instructor uses, and «Plaza 118» is a persistent identifier the candidate
# types into the tablet. Banning the root would forbid the legitimate use and
# teach everyone to ignore this check. The QUOTA sense is what is forbidden, and
# it shows up as the plural or inside a phrase.
VOCABULARIO='asignación de plaza|adjudicación de plaza|\bplazas\b|\bcupos?\b|línea de corte|nota de corte|(dentro|fuera) de plaza|\bno aptos?\b|\baptos?\b|\baprobad[oa]s?\b|\bsuspens[oa]s?\b|\badmitid[oa]s?\b|\bexcluid[oa]s?\b'

# One noun for the person the app is about: «aspirante».
#
# The product called them three things at once — «Alumno» in the attempt
# summary, «candidatos» in the convocatoria metrics, «alumno» in the manager
# profile — and the share sheet, the one piece of copy that leaves the app,
# used a fourth. They are candidates in a public examination, and «alumno»
# describes a course.
#
# «candidate»/«candidato» stays legitimate in DTO field names, comments and
# fixtures, which this scan does not read: it only sees UI literals.
PERSONA='\b(alumn[oa]s?|candidat[oa]s?)\b'

# Extracts UI string literals from the Swift sources of a target.
literales() {
  rg --no-heading --line-number --only-matching '"[^"\\]{4,}"' \
     --glob '*.swift' "$1"
}

# Reports every literal matching a pattern. Uses process substitution, not a
# pipe, so the counter survives the loop.
escanear() {
  local patron="$1" encontrados=0 linea
  for objetivo in "${TARGETS[@]}"; do
    [ -d "$objetivo" ] || continue
    while IFS= read -r linea; do
      echo "  $linea"
      encontrados=$((encontrados + 1))
    done < <(literales "$objetivo" | rg --ignore-case "$patron")
  done
  return "$encontrados"
}

fallos=0

escanear "$REGISTRO"
registro=$?
if [ "$registro" -gt 0 ]; then
  echo
  echo "✗ $registro UI string(s) address the user informally."
  echo "  Use the formal register: «Vuelva a iniciar sesión», not «Vuelve a iniciar sesión»."
  echo
  fallos=$((fallos + registro))
fi

escanear "$VOCABULARIO"
vocabulario=$?
if [ "$vocabulario" -gt 0 ]; then
  echo
  echo "✗ $vocabulario UI string(s) use vocabulary GDPR art. 22 forbids here."
  echo "  The system computes a mark and issues no verdict: no «apto», no"
  echo "  «aprobado», no «asignación de plaza», no «línea de corte»."
  echo "  Say who decides and that it happens elsewhere — see LegalNotice."
  echo "  «Plaza 118» and «Nombre o plaza» are the enrolment number and are fine."
  echo
  fallos=$((fallos + vocabulario))
fi

escanear "$PERSONA"
persona=$?
if [ "$persona" -gt 0 ]; then
  echo
  echo "✗ $persona UI string(s) call the person something other than «aspirante»."
  echo "  They are candidates in a public examination, not students on a course:"
  echo "  «Aspirante», «aspirantes» — never «alumno» or «candidatos»."
  echo
  fallos=$((fallos + persona))
fi

if [ "$fallos" -gt 0 ]; then
  exit 1
fi

echo "✓ UI strings: formal register, one noun for the person, no forbidden vocabulary."
