# AGENTS.md

Flutter app for "Vía Justa" (Android-first). The product is built incrementally from `doc/Via_Justa_Plan_de_trabajo.pdf`; implement only the numbered step being requested. Do not add screens, features, or dependencies beyond that step.

## Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/municipality_search_test.dart   # single file
flutter run -d <device-id> --no-pub
```

- Jump straight to a screen while iterating: `flutter run -d <device-id> --route=/department/20 --no-pub`. `initialLocation` is `/splash`, which auto-navigates to `/welcome` after 1.8 s.
- `adb` is not on PATH; use `C:\Android\Sdk\platform-tools\adb.exe`. List devices with `flutter devices` or `flutter emulators --launch Pixel_8`.
- `flutter analyze` and `flutter test` must both pass. There is no CI config in the repo.

## Architecture

- Entrypoint: `lib/main.dart` (`EasyLocalization` > `ProviderScope`) -> `lib/app/app.dart` (`MaterialApp.router`) -> `routerProvider` in `lib/core/router/app_router.dart`.
- `lib/core/` is shared infrastructure: `router/`, `theme/`, `widgets/` (`VjButton`, `VjCard`, `VjBadge`, `VjSearchField`), `utils/`, `demo/`.
- Features live in `lib/features/<feature>/{domain,data,presentation/{pages,state}}/`. Current features: `auth`, `home`, `onboarding`, `splash`, `map_colombia`, `municipality`.
- Routes and `AppRoutes` path helpers are centralized in `app_router.dart`. Add routes there, not inline. Splash uses `context.go` (no back to splash); drill-down uses `context.push`.
- State is Riverpod 3: `ConsumerWidget`/`ConsumerStatefulWidget`, `Provider`, `FutureProvider.family`, `NotifierProvider`. The concrete municipality repository is only referenced by `municipalityRepositoryProvider` so it can be swapped for Supabase later.

## Conventions

- Imports must be `package:via_justa/...`; relative imports are not used.
- All user-visible text goes through `'clave'.tr()`. Every key must exist in both `assets/translations/es.json` and `en.json`; `test/translations_test.dart` fails otherwise. Spanish is the fallback locale.
- Use `AppColors` (`core/theme/app_colors.dart`), `AppSpacing`, and `AppRadius` instead of raw colors/spacing/radii. **`AppRadius` is defined in `core/theme/app_spacing.dart`** — there is no `app_radius.dart`.
- Text styles come from the `Theme` text theme (`headlineMedium`, `bodyLarge`, etc.) rather than ad-hoc `TextStyle`s where possible.
- Assets are registered by directory in `pubspec.yaml` (`assets/translations/`, `assets/images/`, `assets/data/`). A new top-level asset directory needs a pubspec entry.
- Do not change `applicationId`, the theme setup, or platform folders (`android/`, `ios/`, `web/`, etc.) unless the task explicitly says so.
- Do not add dependencies on your own; versions are resolved with `flutter pub add`.

## Implementation caveats

- Municipality data is local sample data in `assets/data/municipalities_cesar.json`; `LocalMunicipalityRepository` only serves department code `20` (Cesar) and returns an empty list for others. DIVIPOLA codes have not been verified against DANE.
- Department shapes on the map are provisional `Path` ovals, not real geography; the map is labeled as a sample.
- `home_placeholder_page.dart` es un inicio temporal; el Paso 7 lo reemplaza.
- Layout screens are tested at narrow widths and large system font scales; prefer content-sized/scrollable layouts over fixed header heights.

## Verification

Report only commands actually run. For UI fixes, verify on an Android device/emulator when available (screenshots via `adb shell screencap` + `adb pull`), including overflow/logcat checks (`adb logcat -d | Select-String "overflowed|RenderFlex"`) and a large `font_scale` pass. If no device is available, say so explicitly instead of claiming visual verification.

# REGLAS DE ARQUITECTURA DEL PROYECTO "VÍA JUSTA" (obligatorias en cada tarea)

Estas reglas existen porque el profesor revisa en la sustentación que NO haya lógica en las vistas y pregunta en qué parte del código ocurre cada funcionalidad. Cumplirlas es parte de la definición de terminado.

## 1. Capas y responsabilidades
Cada funcionalidad vive en `lib/features/<nombre>/` con tres capas:
- `presentation/`: `pages/` y `widgets/` (lo que se ve y se toca) y `state/` (providers de Riverpod).
- `domain/`: entidades, reglas de negocio, validaciones y repositorios abstractos. Dart puro: sin Flutter, sin Supabase, sin `BuildContext`.
- `data/`: implementaciones de repositorios, lectura de assets, red y conversión de JSON.
Lo compartido por varias funcionalidades va en `lib/core/`. Las dependencias van hacia adentro: presentation → domain ← data. Las vistas NUNCA importan `data/`.

## 2. Qué puede y qué NO puede haber en una vista (`presentation/pages` y `presentation/widgets`)
**Puede:** componer widgets, aplicar estilos del tema, textos con `'clave'.tr()`, animaciones, foco y controladores de texto (estado puramente de interfaz), leer providers con `ref.watch`, llamar métodos de providers en eventos (`onTap`, `onChanged`, `onPressed`), navegar, mostrar SnackBars o diálogos, y dibujar (por ejemplo `CustomPainter` y saber qué forma se tocó).
**NO puede:**
- filtrar, ordenar, agrupar, calcular o transformar datos de negocio (`.where`, `.sort`, `.map` sobre datos, porcentajes, totales);
- aplicar reglas o umbrales (disponibilidad, niveles del semáforo, límites, tope recomendado);
- validar formularios (correo, contraseña, montos);
- acceder a repositorios, assets (`rootBundle`), red, `jsonDecode` ni base de datos;
- decidir a dónde ir según el estado de sesión o de datos (eso es del router y de los providers);
- usar `Timer`, `Future.delayed` o `Stream` para lógica (solo para animaciones). Excepción temporal aceptada: el `Timer` del splash, que se mueve al router en la semana 2.

**Prueba rápida:** ¿puedo probar esta regla sin dibujar ninguna pantalla? Si no, está en el lugar equivocado.

## 3. Dónde va cada cosa
- Reglas, cálculos, filtros y validaciones: funciones puras en `domain/` (fáciles de probar).
- Estado y orquestación: `Notifier`/`NotifierProvider`, `Provider` y `FutureProvider` en `presentation/state/`. Con Riverpod 3 NO uses `StateProvider`, `StateNotifierProvider` ni `ChangeNotifierProvider`. Usa `.autoDispose` para estado de una pantalla que debe reiniciarse al salir.
- Acceso a datos: repositorios (interfaz en `domain/`, implementación en `data/`). Solo el provider del repositorio conoce la implementación concreta; cambiarla (ejemplo → Supabase) no debe tocar ninguna pantalla.
- Formularios: las validaciones son funciones de `domain/`; el estado del formulario (valores, errores, enviando, éxito, falla) lo lleva un `Notifier`; la página solo muestra el estado y llama a `submit()`.
- Un provider por responsabilidad. Si una pantalla necesita más de dos o tres providers distintos, probablemente falta un provider que los combine.

## 4. Reglas generales del proyecto (se mantienen)
- Imports `package:via_justa/...`. Identificadores en inglés; comentarios y documentación en español.
- Todo texto visible por `'clave'.tr()` con las mismas claves en `assets/translations/es.json` y `en.json` (hay un test que lo exige). Los nombres propios (municipios, departamentos) son datos y no se traducen.
- Colores, espaciados y radios solo desde `AppColors`, `AppSpacing`, `AppRadius`. Verde, ámbar y rojo se reservan para el semáforo.
- Los datos de ejemplo se rotulan como tales en pantalla y en el código; nunca se presentan como reales.
- Sin overflows a 360 dp ni con texto grande; áreas táctiles de al menos 48 dp; el semáforo nunca depende solo del color.
- Navegación: `push` cuando debe poder volver atrás; `go` solo para saltos de raíz. El botón atrás nunca debe cerrar la app por error.
- Libera `Timer`, controladores y `TextEditingController` en `dispose()`. Sin `withOpacity`, sin el widget `Radio`. Sin dependencias nuevas salvo que la tarea lo pida.
- Sin secretos en el repositorio.

## 5. Antes de dar una tarea por terminada
1. `flutter analyze` sin errores y `flutter test` en verde.
2. Busca en `lib/**/presentation/` (excluyendo `presentation/state/`) la expresión regular `normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed`. Cada coincidencia debe justificarse (animación, dibujo o excepción temporal) o moverse a `domain/` o a un provider. Ejecuta la búsqueda sensible a mayúsculas (`Select-String -CaseSensitive` en PowerShell o la opción `Aa` en VS Code) para no capturar nombres de widgets como `VjSearchField(`.
3. Toda regla nueva en `domain/` tiene su prueba unitaria; los providers con lógica tienen prueba con `ProviderContainer` y un repositorio falso.
4. Nunca afirmes haber ejecutado un comando, una prueba o una verificación visual que no ejecutaste.

## 6. Formato obligatorio de cada reporte final
1. Archivos creados, modificados y eliminados (rutas).
2. Comandos ejecutados y su resultado real, incluida la búsqueda del punto 5.2.
3. Problemas, decisiones y pendientes.
4. **Ruta del código** de cada funcionalidad nueva o modificada: pantalla → provider → función de dominio → repositorio o fuente de datos. Ejemplo: "Buscar un municipio: `MunicipalitySelectorPage` → `filteredMunicipalitiesProvider` → `searchMunicipalities` (domain) → `LocalMunicipalityRepository` → `municipalities_cesar.json`".
5. Una línea con el siguiente paso.