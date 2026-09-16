# Documento de entrega

**Dobacksoft Training** — Cliente nativo iOS
Antonio Hermoso González · 16 de septiembre de 2026

---

## Qué se entrega

Aplicación nativa para iPhone y iPad que da acceso desde el móvil al expediente
de la prueba práctica de conducción de la oposición de bombero conductor de la
Comunidad de Madrid. Consume el API móvil v1 del sistema Training.

Dos roles: **aspirante** (su posición, su progreso, sus vueltas y el mapa de
cada una) e **instructor** (tabla de resultados y ficha individual). Incluye una
extensión de *widget* para la pantalla de inicio.

| | |
|---|---|
| Repositorio | <https://github.com/csgingenieria/training-ios> (privado) |
| Revisión entregada | `9374342` en `main` |
| Lenguaje | Swift 6, aislamiento estricto |
| Interfaz | SwiftUI |
| iOS mínimo | 26.4 · iPhone y iPad |
| Dependencias externas | **ninguna** |
| Memoria del proyecto | `memoria-dobacksoft-training.pdf` (49 páginas) |

---

## Acceso al código

El repositorio es **privado**. Para dar acceso a un revisor hay que añadirlo
como colaborador desde GitHub:

> Settings → Collaborators → Add people

```bash
git clone https://github.com/csgingenieria/training-ios.git
cd training-ios
open "Dobacksoft Training.xcodeproj"
```

Requiere **Xcode 26.4** o posterior. El proyecto usa carpetas sincronizadas: no
hay que añadir ficheros al proyecto a mano, basta con que estén en el árbol.

---

## Servidor

La aplicación habla con un único servidor, declarado en los ficheros de
configuración y no en el código:

```
Config/Debug.xcconfig     https://dobacksoft-training.duckdns.org
Config/Release.xcconfig   el mismo servidor
Config/Staging.xcconfig   desconectada (documentada en el propio fichero)
```

**No existe un servidor de producción independiente.** Debug y Release hablan
con el mismo, de modo que una compilación de distribución toca los mismos datos
que una de desarrollo. No hay red de seguridad técnica entre ambos entornos: la
disciplina de no tocar datos reales es humana.

Comprobar que responde:

```bash
curl -s https://dobacksoft-training.duckdns.org/api/v1/health
# {"status":"ok","time":"…","version":"v1"}
```

---

## Credenciales

**Este documento no contiene credenciales, y no debe contenerlas.** Los datos
corresponden a personas identificables en un proceso selectivo público y están
sujetos a acuerdo de confidencialidad. Un documento de entrega se reenvía, se
adjunta y se archiva; una credencial escrita en él deja de estar bajo control en
cuanto sale del primer correo.

Las cuentas de prueba se guardan en el **llavero de macOS**, no en un fichero.
El motivo está escrito en el propio script que las usa: la aplicación tiene la
regla firme de que los tokens van al llavero y nunca a un fichero plano, y
guardar en texto claro las credenciales de dos cuentas reales contradiría su
propia postura de seguridad.

Para registrarlas en una máquina nueva:

```bash
security add-generic-password -U -s training-ios-staging-student \
    -a 'correo-del-aspirante'  -w
security add-generic-password -U -s training-ios-staging-manager \
    -a 'correo-del-instructor' -w
```

El comando pide la contraseña de forma interactiva: **no la escriba en la línea
de comandos**, o quedará en el historial del intérprete.

Las credenciales en sí se transmiten por un canal aparte de este documento.

---

## Cómo ejecutar y comprobar

**Compilar y ejecutar**

```bash
xcodebuild -project "Dobacksoft Training.xcodeproj" \
           -scheme "Dobacksoft Training" \
           -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
```

**Pruebas unitarias** — 757 casos, sin red ni credenciales:

```bash
xcodebuild test -project "Dobacksoft Training.xcodeproj" \
                -scheme "Dobacksoft Training" \
                -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
                -only-testing:"Dobacksoft TrainingTests"
```

**Guardas del proyecto** — comprueban propiedades que ninguna prueba alcanza
(vocabulario del RGPD en los literales, enlaces de navegación, paleta del
widget, host de cada configuración, enlace profundo registrado en el sistema):

```bash
for g in scripts/check-*.sh; do bash "$g"; done
```

**Recorridos contra el servidor real** — requieren las credenciales del llavero
y ejercen la aplicación completa en los dos roles y los dos tamaños:

```bash
bash scripts/staging-walkthrough.sh
```

> Un solo `xcodebuild test` a la vez. Ejecutar varios en paralelo produce
> resultados que no significan nada.

---

## Estado verificado el 16 de septiembre de 2026

Medido sobre la revisión entregada, no recordado de ejecuciones anteriores:

| Comprobación | Resultado |
|---|---|
| Pruebas unitarias | **757 pasadas · 0 fallidas** · 103 suites |
| Avisos del compilador | **0** |
| Guardas de proyecto (`check-*`) | **5 de 5** correctas |
| Recorridos contra servidor real | no ejecutados en esta verificación |
| Auditoría de calidad nativa | **57 / 57** cerrados |
| Arranque en dispositivo real | iPhone 16 Pro · iOS 26.6 · con sesión iniciada |
| Servidor | `200` en 0,2 s · certificado válido hasta 08/12/2026 |

Detalle completo en `docs/audits/2026-09-16-verificacion-de-entrega.md`.

---

## Cumplimiento normativo

La aplicación está sujeta al **artículo 22 del RGPD**: el sistema calcula una
nota objetiva, pero **no emite un veredicto**. La admisión la decide la
administración fuera del sistema, con intervención humana.

En consecuencia, la interfaz no puede mostrar ni sugerir `APTO`, «aprobado»,
«suspenso», «admitido», «excluido», «línea de corte» ni «plazas». Sí muestra
puesto, calificación, número de participantes y vueltas completadas.

Esa prohibición **se verifica de forma automática por tres vías** con puntos
ciegos distintos: pruebas unitarias sobre los textos expuestos por los tipos,
una guarda sobre todos los literales de interfaz, y una comprobación sobre la
**pantalla renderizada** durante el recorrido con datos reales.

Por aplicación del **artículo 25.2**, el *widget* está desactivado de fábrica:
muestra posición y nota en una pantalla que ve cualquiera que mire el teléfono.

---

## Documentación incluida en el repositorio

```
ENTREGA.md                                   este documento
CLAUDE.md                                    reglas del proyecto y del stack
docs/decisions/D-IOS-002…                    entrada en el entregable a CMadrid
docs/decisions/D-IOS-003…                    retirada del Apple Watch
docs/audits/2026-09-07-calidad-nativa.md     auditoría de 57 puntos, cerrada
docs/audits/2026-09-16-verificacion…         verificación previa a la entrega
docs/api-needs/…                             necesidades pendientes del API
```

---

## Pendientes conocidos

Se declaran porque forman parte del resultado:

1. **TestFlight no es utilizable por el propietario del proyecto**: el código de
   verificación de la cuenta no llega, de modo que la compilación subida no se
   ha podido instalar por ese canal. Afecta a la distribución a probadores, no
   al producto. El canal adecuado para un entregable institucional es **Custom
   App** a través de Apple Business Manager.
2. **Numeración de versiones**: dos compilaciones distintas han convivido como
   `2.0 (1)`. Debe incrementarse `CFBundleVersion` en cada compilación que salga
   del equipo, o no hay forma de saber qué se está probando.
3. Los recorridos automatizados se ejecutan a mano, no en integración continua.
