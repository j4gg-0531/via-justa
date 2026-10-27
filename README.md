# Vía Justa — App Móvil MVP

> Plataforma móvil Android para consulta de precios justos comunitarios, verificación de cláusulas de contratos con IA, exploración geográfica y directorio de negocios locales.

---

## 1. Visión del Proyecto

**Vía Justa** es una aplicación diseñada para que ninguna persona (turista, migrante en proceso de instalación o residente local) llegue o viva en una ciudad colombiana sin herramientas para contrastar precios frente a reportes reales o entender contratos de arrendamiento y servicios.

- **Ciudad Piloto:** Valledupar (Cesar).
- **Enfoque técnico:** Android-first, arquitectura en tres capas, bilingüe (`es` / `en`).
- **Núcleo de precios:** Regla estadística verificable (mediana comunitaria, ventana móvil de 60 días, mínimo $N \ge 3$ reportes), **no una caja negra de IA**.
- **Núcleo de contratos:** Análisis asistido por IA (Gemini vía Edge Functions) con detección de cláusulas abusivas y advertencias legales orientativas.

---

## 2. Pila Tecnológica

- **Framework:** Flutter (Dart 3.x), compilación orientada a Android.
- **Gestión de Estado:** Riverpod 3 (`Notifier`, `Provider`, `FutureProvider`).
- **Navegación:** `go_router` con rutas declarativas y centralizadas.
- **Internacionalización:** `easy_localization` con soporte simultáneo español e inglés.
- **Componentes Compartidos:** Atomic design (`VjButton`, `VjCard`, `VjBadge`, `VjSearchField`, `VjTextField`).
- **Backend (Planeado):** Supabase (PostgreSQL, PostGIS, Auth, Storage, Edge Functions).

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
│   ├── app/                         # Configuración raíz de MaterialApp
│   ├── core/                        # Infraestructura compartida
│   │   ├── demo/                    # Constantes de demostración
│   │   ├── router/                  # Definición centralizada de rutas (app_router.dart)
│   │   ├── session/                 # Proveedores de sesión en memoria
│   │   ├── theme/                   # Tokens de diseño (colores, espaciados, radios, tipografía)
│   │   ├── utils/                   # Utilidades puras (normalización de texto)
│   │   └── widgets/                 # Componentes UI reutilizables
│   └── features/                    # Módulos por funcionalidad (presentation, domain, data)
│       ├── auth/                    # Bienvenida, login y registro
│       ├── home/                    # Pantalla de inicio por perfil
│       ├── map_colombia/            # Explorador departamental
│       ├── municipality/            # Selector de municipios y detalle piloto/no piloto
│       ├── onboarding/              # Selección de perfil inicial
│       └── splash/                  # Bienvenida temporal con redirección
├── docs/                            # Documentación viva del proyecto
│   ├── arquitectura.md              # Principios de diseño y contratos entre capas
│   ├── decisiones.md                # Registro de decisiones de diseño (ADRs)
│   └── implementacion/              # Control de progreso y tablero de tareas
└── test/                            # Suite de pruebas automatizadas (unitarias y widgets)
```

---

## 4. Requisitos y Configuración del Entorno

### Requisitos Previos
1. **Flutter SDK:** Versión `>= 3.13.5` (compatible con Dart 3.x).
2. **Android SDK & Build Tools:** JDK 17, `platform-tools` (`adb`).
3. **Editor recomendado:** VS Code con extensiones oficiales de Flutter y Dart.

### Puesta en Marcha Local
```powershell
# 1. Clonar repositorio
git clone https://github.com/j4gg-0531/via-justa.git
cd via-justa

# 2. Descargar dependencias
flutter pub get

# 3. Análisis estático y pruebas
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

---

## 6. Estado Actual del Producto (Demostración Local)

El avance actual corresponde a un **prototipo funcional con datos de ejemplo locales** (`DEMO`):
- Los datos de precios, eventos y autenticación residen temporalmente en memoria o en archivos JSON locales.
- No se deben ingresar contraseñas reales ni documentos con información personal (PII) durante esta etapa.
- La conexión con Supabase, Google Maps real y la Edge Function de Gemini se incorporará progresivamente según las tareas del Plan Maestro de Implementación.
