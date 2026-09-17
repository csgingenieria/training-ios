# Dobacksoft Training — cliente iOS

Cliente nativo iOS (Swift 6, SwiftUI; iPhone, iPad y widget) del sistema
Training: seguimiento de la prueba práctica de conducción de la Oposición de
Conductores del Cuerpo de Bomberos de la Comunidad de Madrid. Proyecto final de
Apple Coding Academy, etiquetado `entrega-2026-09-16`.

- **[ENTREGA.md](ENTREGA.md)** — el documento de entrega: qué es, decisiones
  técnicas con su porqué, cómo ejecutarlo y qué mirar para evaluarlo.
- `docs/audits/` y `docs/decisions/` — auditorías y decisiones registradas.
- `CLAUDE.md` y `AGENTS.md` — reglas del proyecto y del stack.

Las pruebas unitarias no necesitan red ni credenciales:

```bash
xcodebuild test -project "Dobacksoft Training.xcodeproj" \
                -scheme "Dobacksoft Training" \
                -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
                -only-testing:"Dobacksoft TrainingTests"
```

Todo junto —guardas, número de build y suite—: `bash scripts/verificar.sh`.

Los datos del sistema están bajo acuerdo de confidencialidad: este repositorio
no contiene credenciales ni capturas con datos reales.
