# Vía Justa — App Móvil MVP

> Plataforma móvil Android para consulta de precios justos comunitarios por zona, verificación orientativa de cláusulas de contratos con IA, exploración geográfica y directorio de negocios locales.

---

## 1. Visión del Proyecto

**Vía Justa** es una aplicación diseñada para que ninguna persona (turista, migrante en proceso de instalación o residente local) llegue o viva en una ciudad colombiana sin herramientas para contrastar precios frente a reportes reales o entender contratos de arrendamiento y servicios.

- **Ciudad Piloto:** Valledupar (Cesar), segmentada por zonas urbanas (`Zona Norte`, `Zona Centro`, `Zona Sur`, `Zona Oriente`, `Zona Occidente`).
- **Enfoque técnico:** Android-first, arquitectura estricta en tres capas (`presentation` → `domain` ← `data`), bilingüe (`es` / `en`).
- **Núcleo de precios:** Regla estadística verificable por zona del municipio (mediana comunitaria, ventana móvil de 60 días, mínimo $N \ge 3$ reportes), **nunca una caja negra de IA** *(Implementado en modo DEMO en `VJ-04` y `VJ-05`; conexión a RPC PostgreSQL en Semana 3)*.
- **Núcleo de contratos:** Análisis asistido por IA (Gemini vía Edge Functions) con detección de cláusulas abusivas y advertencias legales orientativas *(Demostración educativa rotulada en `VJ-04`; OCR y Edge Function en Semana 4)*.

---

## 2. Pila Tecnológica

- **Framework:** Flutter 3.47.7 (Dart 3.13.5), compilación orientada a Android.
- **Gestión de Estado:** Riverpod 3 (`Notifier`, `Provider`, `FutureProvider`).
- **Navegación:** `go_router` con rutas declarativas centralizadas y `StatefulShellRoute.indexedStack` de 5 pestañas.
- **Internacionalización:** `easy_localization` con paridad estricta español e inglés.
- **Componentes Compartidos:** Atomic design (`VjButton`, `VjCard`, `VjBadge`, `VjSearchField`, `VjTextField`) y extensión de tema `SemanticStatusColors`.
- **Backend (Planificado Semanas 2–5):** Supabase (PostgreSQL, PostGIS, Auth, Storage, Edge Functions).

---

## 3. Estructura del Proyecto

```text
via-justa/
├── android/                         # Configuración nativa Android y Gradle
├── assets/
│   ├── data/                        # Datos locales de muestra (DIVIPOLA Cesar)
│   ├── images/                      # Activos visuales autorizados
│   └── translations/                # Archivos es.json y en.json (paridad estricta)
├── lib/
│   ├── app/                         # Configuración raíz de MaterialApp.router
│   ├── core/                        # Infraestructura compartida
│   │   ├── demo/                    # Constantes de demostración
│   │   ├── navigation/              # Shell persistente de 5 pestañas (AppScaffold)
│   │   ├── router/                  # Definición centralizada de rutas (app_router.dart)
│   │   ├── session/                 # Controlador y proveedores de sesión en memoria
│   │   ├── theme/                   # Tokens de diseño y SemanticStatusColors
│   │   ├── utils/                   # Utilidades puras (normalización de texto)
│   │   └── widgets/                 # Componentes UI reutilizables
│   └── features/                    # Módulos por funcionalidad (presentation, domain, data)
│       ├── auth/                    # Bienvenida (M01), login y registro (M16)
│       ├── businesses/              # Directorio local de negocios de muestra (M21)
│       ├── contracts/               # Resumen educativo DEMO de contratos (M06 / RN-10)
│       ├── home/                    # Pantalla de inicio adaptada por perfil (M04 / M05)
│       ├── map_colombia/            # Explorador departamental de Colombia (M03)
│       ├── municipality/            # Selector de municipios (M13) y detalle piloto/no piloto (M14/M15)
│       ├── onboarding/              # Selección de perfil inicial (M02)
│       ├── prices/                  # Motor de semáforo por zonas (M06/M07/M20), mapa local (M08) y aporte en 4 pasos (M10)
│       ├── profile/                 # Perfil, cambio de idioma en vivo y cierre de sesión (M17)
│       ├── scan/                    # Contenedor de escaneo Precios vs. Contratos (M06)
│       └── splash/                  # Bienvenida inicial con redirección
├── docs/                            # Documentación viva del proyecto
│   ├── arquitectura.md              # Principios de diseño y contratos entre capas
│   ├── contrato-datos-v1.md         # Contrato de datos SQL, RLS y RPC evaluate_price_verdict
│   ├── decisiones.md                # Registro de decisiones de diseño (ADRs D1–D15)
│   ├── fuentes-y-licencias.md       # Atribución de datos e imágenes
│   ├── modelo-er.puml               # Diagrama Entidad-Relación en PlantUML
│   ├── seguridad-privacidad.md      # Políticas de privacidad (RN-10) y controles
│   └── implementacion/              # Tablero de progreso y guía de sustentación (VJ-06)
└── test/                            # Suite de 138 pruebas automatizadas (unitarias, widgets y E2E)
```

---

## 4. Requisitos y Configuración del Entorno

### Requisitos Previos
1. **Dart SDK:** Restricción declarada en `pubspec.yaml` como `sdk: ^3.13.5` (entorno exacto `dart: ">=3.13.5 <4.0.0"` registrado en `pubspec.lock`).
2. **Flutter SDK (Línea base reproducible):** **Flutter 3.47.7 (canal `stable`)**.  
   *Nota de compatibilidad oficial:* La versión histórica Flutter 3.13 (2023) incluía Dart 3.1 y no satisface la restricción del proyecto. De acuerdo con el archivo oficial de versiones del SDK de Flutter y el bloqueo en `pubspec.lock` (`sdks: flutter: ">=3.47.0"`), Dart 3.13.5 es empaquetado por la serie estable Flutter 3.47.x (Flutter 3.47.6 / 3.47.7). Esta versión queda fijada para desarrollo local y pipelines de GitHub Actions (`subosito/flutter-action@v2` con `flutter-version: '3.47.7'`).
3. **Compatibilidad de dependencias:** Todas las dependencias directas del proyecto en `pubspec.lock` (`flutter_riverpod: 3.4.3`, `go_router: 18.1.1`, `easy_localization: 3.0.8` y `flutter_lints: 6.0.0`) son plenamente compatibles con Flutter 3.47.7 y Dart 3.13.5.
4. **Android SDK & Build Tools:** JDK 17, Android SDK Command-line Tools y herramientas de plataforma (`adb`).
5. **Editor recomendado:** VS Code con extensiones oficiales de Flutter y Dart.

### Puesta en Marcha Local
```powershell
# 1. Clonar repositorio
git clone https://github.com/j4gg-0531/via-justa.git
cd via-justa

# 2. Descargar dependencias
flutter pub get

# 3. Análisis estático y pruebas (incluye recorrido E2E del Primer Avance)
flutter analyze
flutter test

# 4. Ejecución en emulador o dispositivo físico Android
flutter run -d <device-id>
```

---

## 5. Pruebas y Control de Calidad

El proyecto mantiene una estricta separación de responsabilidades:
- **Regla innegociable:** Prohibida la lógica de negocio en las vistas (`presentation/pages` y `presentation/widgets`).
- **Verificación de higiene arquitectónica:**
  ```powershell
  Get-ChildItem -Path "lib" -Recurse -Include *.dart | Where-Object { $_.FullName -match "\\presentation\\" -and $_.FullName -notmatch "\\presentation\\state\\" } | Select-String -Pattern 'normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed' -CaseSensitive
  ```
- **Pruebas de internacionalización:** Se valida que cada clave en español tenga su contraparte idéntica en inglés mediante `test/translations_test.dart`.
- **Recorrido E2E del Primer Avance:** `test/first_milestone_walkthrough_test.dart` verifica automáticamente el flujo completo de sustentación (`M01` → `M02` → `M03` → `M13` → `M15`/`M14` → Shell de 5 pestañas → `M06`/`M07`/`M20` → `M10` → `M17` → `signOut`).

---

## 6. Estado Actual del Producto (Cierre del Primer Avance — `VJ-06`)

El avance actual corresponde al **Primer Avance completo y navegable con datos de ejemplo locales** (`DEMO`):
- Incluye el flujo completo de entrada, onboarding de 3 perfiles, mapa departamental, selector de 25 municipios del Cesar, shell de 5 pestañas, mapa local de precios y servicios (`M08`), motor estadístico del semáforo por zonas del municipio con autodetección por permiso GPS o selección manual en mapa (`M06`, `M07`, `M20`), asistente en 4 pasos para aportar precios (`M10`), resumen educativo de contratos (`RN-10`), directorio de negocios (`M21`) y cambio de idioma en vivo (`es` / `en`).
- Consulta [`docs/implementacion/walkthrough-primer-avance.md`](docs/implementacion/walkthrough-primer-avance.md) para el guion de sustentación de 7 minutos y la tabla de rutas del código por funcionalidad.
