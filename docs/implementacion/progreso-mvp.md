# Progreso y Control de Cambios — Vía Justa MVP

**Última actualización:** 29 de octubre de 2026 (VJ-14 avance parcial app móvil; VJ-07, VJ-08 y VJ-13 integrados en `main`)  
**Rama base actual:** `main` — PRs #4 a #16 integrados; rama actual `feature/vj-14-analisis-contratos-app`  
**Repositorio remoto:** `https://github.com/j4gg-0531/via-justa.git`  
**Entorno de ejecución:** Windows 10/11 x64, PowerShell 5.1  
**Gradle Wrapper:** 9.3.1 (`android/gradle/wrapper/gradle-wrapper.properties`)  
**Android Gradle Plugin:** 9.1.0 (`android/settings.gradle.kts`)  
**Kotlin:** 2.4.0 (`android/settings.gradle.kts`)  
**JVM Target:** Java 17 (`android/app/build.gradle.kts`)  
**Flutter SDK:** Flutter 3.47.7 (canal `stable`, Dart 3.13.5) instalado en `C:\Users\JUAN\flutter` y añadido al PATH de usuario.  
**Suite de pruebas:** 209 pruebas automatizadas ejecutadas y 209 aprobadas (100% éxito), incluyendo el recorrido E2E del Primer Avance (`test/first_milestone_walkthrough_test.dart`), las pruebas de autenticación Supabase (`test/auth_controller_test.dart`) y las pruebas completas de análisis de contratos (`test/contract_analysis_repository_test.dart`, `test/contract_analysis_view_test.dart`).

---

## 1. Tablero Maestro de Tareas (VJ-00 a VJ-21)

| ID | Prioridad | Rol | Tarea | Estado | Dependencias |
|---|---|---|---|---|---|
| **VJ-00** | P0 | Ambos | Inventario inicial, baseline reproducible y control de cambios | **INTEGRADO (PR #4)** | Ninguna |
| **VJ-01** | P0 | Ambos | Decisiones, contrato con compañero, diagrama ER y gobierno | **INTEGRADO (PR #5)** | VJ-00 |
| **VJ-02** | P0 | Frontend | Higiene técnica, README, CI y accesibilidad base | **INTEGRADO (PR #6)** | VJ-00, VJ-01 |
| **VJ-03** | P0 | Frontend | Navegación principal: ShellRoute con 5 pestañas persistentes y mapa local M08 | **HECHO-VERIFICADO (PR #7 / fix)** | VJ-02 |
| **VJ-04** | P1 | Ambos | Motor visual de semáforo demo por zonas (GPS + mapa): pantallas M06, M07 y M20 | **HECHO-VERIFICADO (`feature/vj-04-semaforo-demo`)** | VJ-03 |
| **VJ-05** | P1 | Frontend | Pantalla M10: aportar precio en 4 pasos demo por zona | **HECHO-VERIFICADO (`feature/vj-05-aportar-precio-demo`)** | VJ-04 |
| **VJ-06** | P1 | Ambos | Cierre del primer avance: walkthrough E2E, CI y documentación de sustentación | **HECHO-VERIFICADO (`feature/vj-06-cierre-primer-avance`)** | VJ-03, VJ-04, VJ-05 |
| **VJ-07** | P0 | Backend | Supabase: migración inicial, RLS, GRANT, seeds y ER | **INTEGRADO (PR #15)** | VJ-01, VJ-06 |
| **VJ-08** | P0 | Ambos | Supabase Auth real, sesión, perfil y consentimientos | **INTEGRADO (PR #16)** | VJ-07 |
| **VJ-09** | P0 | Frontend | Navegación por sesión, municipios reales y mapa oficial | **PENDIENTE** | VJ-08 |
| **VJ-10** | P0 | Backend | Función SQL de semáforo: única fuente de verdad | **PENDIENTE** | VJ-07 |
| **VJ-11** | P0 | Ambos | Reportes reales: aporte, límites, fuente y sincronización | **PENDIENTE** | VJ-10 |
| **VJ-12** | P1 | Frontend | Google Maps de precios, filtros y optimización | **BLOQUEADO-EXTERNO** | VJ-11 |
| **VJ-13** | P1 | Frontend | Captura de contratos: cámara, archivos y OCR local | **INTEGRADO (PR #14)** | VJ-06 |
| **VJ-14** | P1 | Ambos | Análisis de contratos con Gemini en Edge Function | **avance parcial (app); backend pendiente** | VJ-13 |
| **VJ-15** | P2 | Ambos | Vista de ciudad de Valledupar: cultura verificada es/en | **PENDIENTE** | VJ-09 |
| **VJ-16** | P2 | Ambos | Registro de negocio en 4 pasos, RLS y moderación | **PENDIENTE** | VJ-08 |
| **VJ-17** | P2 | Frontend | Negocios: catálogo, detalle y acciones externas | **PENDIENTE** | VJ-16 |
| **VJ-18** | P0 | Ambos | Correcciones cruzadas de seguridad, privacidad y confiabilidad | **PENDIENTE** | VJ-07 a VJ-17 |
| **VJ-19** | P0 | Ambos | Suite de pruebas integrales: accesibilidad y robustez | **PENDIENTE** | VJ-18 |
| **VJ-20** | P0 | Frontend | Entrega Android real: applicationId, firma release, APK | **BLOQUEADO-EXTERNO** | VJ-19 |
| **VJ-21** | P0 | Ambos | Documentación final, sustentación y decisión Go/No-Go | **PENDIENTE** | VJ-20 |

---

## 2. Inventario de Código en el Cierre del Primer Avance (`VJ-06`)

### Páginas y Widgets de Presentación (`lib/`)
- `lib/main.dart`: Bootstrap con `EasyLocalization` y `ProviderScope`.
- `lib/app/app.dart`: Configuración de `MaterialApp.router` con tema centralizado, `SemanticStatusColors` y delegados de localización.
- `lib/core/router/app_router.dart`: Rutas centralizadas con `GoRouter` (`StatefulShellRoute.indexedStack` con 5 pestañas: `/home`, `/map`, `/scan`, `/businesses`, `/profile` y rutas de detalle `/departments`, `/department/:code`, `/municipality/:code`, `/prices/result`, `/prices/contribute`).
- `lib/core/navigation/app_scaffold.dart`: Shell persistente con `NavigationBar` y manejo del botón atrás de Android vía `BackButtonListener`.
- `lib/features/home/presentation/pages/home_page.dart`: Inicio dinámico según perfil (`M04` Settler, `M05` Visitor, `M02` adaptado Resident).
- `lib/features/prices/presentation/pages/price_map_page.dart`: Mapa local `M08` de precios, servicios y consulados del municipio activo con acceso a `ContributePricePage`.
- `lib/features/scan/presentation/pages/scan_page.dart`: Contenedor `M06` con selector segmentado Precios (`PriceScanPage`) vs. Contratos (`DemoContractSummary`).
- `lib/features/prices/presentation/pages/price_scan_page.dart` y `lib/features/prices/presentation/widgets/zone_map_picker_card.dart`: Evaluación de precios por zona del municipio con detección automática por permiso GPS o selección interactiva en mapa.
- `lib/features/prices/presentation/pages/price_result_page.dart` y `lib/features/prices/presentation/widgets/price_verdict_card.dart`: Resultado estadístico del semáforo (`M07` verde/ámbar/rojo y `M20` muestra insuficiente $N < 3$).
- `lib/features/prices/presentation/pages/contribute_price_page.dart`: Asistente en 4 pasos (`M10`) para aportar un precio ciudadano por zona con confirmación DEMO.
- `lib/features/contracts/presentation/widgets/demo_contract_summary.dart`: Resumen educativo DEMO de cláusulas contractuales (`RN-10`).
- `lib/features/businesses/presentation/pages/businesses_page.dart`: Directorio `M21` de comercios de muestra en Valledupar con buscador y categorías.
- `lib/features/profile/presentation/pages/profile_page.dart`: Perfil de usuario `M17`, selector de perfil en memoria, conmutador de idioma y logout limpio.
- `lib/features/map_colombia/presentation/pages/map_page.dart`: Mapa departamental `M03` (`/departments`) con botón volver condicional.

### Capa de Dominio (`domain/`)
- `lib/features/prices/domain/price_verdict.dart`: Reglas puras del semáforo (`evaluatePriceSample`, `calculateMedianCop`, umbrales `+15%`/`+40%`, muestra mínima $N = 3$, alerta `<-40%` y contexto de evento).
- `lib/features/prices/domain/municipality_zone.dart`: Entidad `MunicipalityZone`, `LocationPermissionStatus` y función pura `resolveNearestZoneByNormalizedPoint`.
- `lib/features/prices/domain/price_contribution.dart`: Validaciones puras del wizard de 4 pasos (`isValidContributionCategory`, `validateContributionAmount`, `isValidContributionZone`, `sanitizeContributionNote`) y `PriceContributionRecord`.
- `lib/features/prices/domain/price_map_filter.dart`: Filtrado puro de marcadores del mapa local `M08`.
- `lib/features/contracts/domain/contract_analysis_demo.dart`: Entidades inmutables para el resumen educativo de contratos.
- `lib/features/businesses/domain/business.dart` y `business_filter.dart`: Entidad `Business` y función pura `filterBusinesses`.

### Capa de Datos (`data/`)
- `lib/features/prices/data/demo_price_verdict_repository.dart`: Muestras locales por zona de Valledupar (`vup_norte`, `vup_centro`, `vup_sur`, `vup_oriente`, `vup_occidente`) y cálculo con `evaluatePriceSample`.
- `lib/features/prices/data/demo_price_contribution_repository.dart`: Almacenamiento en memoria de sesión para los aportes ciudadanos DEMO (`M10`).
- `lib/features/prices/data/local_price_map_repository.dart`: Pines de precios, servicios y consulados del mapa local `M08`.
- `lib/features/contracts/data/demo_contract_analysis_repository.dart`: Caso educativo bilingüe de contrato de arrendamiento urbano (`Ley 820 de 2003`).
- `lib/features/businesses/data/local_business_repository.dart`: Repositorio local de muestra para comercios en Valledupar.
- `lib/features/municipality/data/local_municipality_repository.dart`: Implementación local que lee `assets/data/municipalities_cesar.json`.

---

## 3. Matriz de Trazabilidad de Mockups (M01 a M21)

| ID | Pantalla | Ruta | Origen | Estado Actual (`VJ-06`) | Adaptación UI/UX v1.1 |
|---|---|---|---|---|---|
| **M01** | Entrada | `/welcome` | `mockup_01.jpg` (izq.) | **Implementado DEMO** | Estilo claro, enlaces a términos/privacidad, Google como demo |
| **M02** | Onboarding perfil | `/onboarding` | `mockup_01.jpg` (cen.) | **Implementado DEMO** | Tres tarjetas (incluye Residente D11), saludo dinámico |
| **M03** | Mapa departamentos | `/departments` | `mockup_01.jpg` (der.) | **Implementado DEMO** | Óvalos provisionales, buscador sin micrófono, botón volver condicional |
| **M04** | Inicio Instalación | `/home` | `mockup_02.jpg` (izq.) | **Implementado DEMO** | Tarjeta principal de instalación, accesos rápidos, "Próximamente" en trámites |
| **M05** | Inicio Visitante | `/home` | `mockup_02.jpg` (cen.) | **Implementado DEMO** | Banner azul claro DEMO para evento, accesos a Escanear/Mapa/Negocios |
| **M06** | Escanear precio/contrato | `/scan` | `mockup_02.jpg` (der.) | **Implementado DEMO** | Selector Precio/Contrato; selector de zona GPS/Mapa y resumen de contrato DEMO |
| **M07** | Resultado de análisis | `/prices/result` | `mockup_03.jpg` (izq.) | **Implementado DEMO (`VJ-04`)** | "Referencia en la zona (mediana)", 3 colores + ícono + texto + tope `+15%` |
| **M08** | Mapa de precios | `/map` | `mockup_03.jpg` (cen.) | **Implementado DEMO (`VJ-03`)** | Lienzo urbano local rotulado DEMO, filtros por categoría y botón Aportar precio |
| **M09** | Detalle negocio/servicio | `/businesses/:id` | `mockup_03.jpg` (der.) | Planificado (`VJ-17`) | Ficha de negocio verificado, acciones WhatsApp/Llamar/Llegar |
| **M10** | Aportar precio (4 pasos) | `/prices/contribute` | `mockup_04.jpg` (izq.) | **Implementado DEMO (`VJ-05`)** | Wizard en 4 pasos por zona, validaciones en `domain/`, confirmación DEMO |
| **M11** | Mis trámites | `/procedures` | `mockup_04.jpg` (cen.) | Fuera de MVP | Aplazado / Fase 2; no simular progreso |
| **M12** | Mis documentos | `/documents` | `mockup_04.jpg` (der.) | Fuera de MVP | Aplazado / Fase 2; no prometer almacenamiento cifrado no existente |
| **M13** | Selector municipios Cesar | `/department/20` | `mockup_05.jpg` (izq.) | **Implementado DEMO** | Cabecera azul oscuro, buscador sin tildes, 25 municipios |
| **M14** | Municipio piloto | `/municipality/20001`| `mockup_05.jpg` (cen.) | **Implementado DEMO** | Botón Entrar, insignia de piloto, aviso honesto |
| **M15** | Municipio no piloto | `/municipality/:code` | `mockup_05.jpg` (der.) | **Implementado DEMO** | Información no verificada, interés solo en memoria ("Te avisaremos") |
| **M16** | Login / Registro correo | `/login`, `/register` | Nuevo v1.1 | **Implementado DEMO** | Formularios rediseñados con validación en `domain/` |
| **M17** | Perfil y ajustes | `/profile` | Nuevo v1.1 | **Implementado DEMO** | Cambio de idioma es/en, cambio de perfil, ciudad actual y logout |
| **M18** | Vista cultural Valledupar | `/city/20001` | Nuevo v1.1 | Planificado (`VJ-15`) | Cabecera hero, contenido cultural bilingüe es/en con fuentes citadas |
| **M19** | Registro negocio (4 pasos)| `/businesses/register`| Nuevo v1.1 | Planificado (`VJ-16`) | Wizard 4 pasos para dueños locales; estado inicial pending |
| **M20** | Estado insuficiente semáforo| `/prices/result` | Nuevo v1.1 | **Implementado DEMO (`VJ-04`)** | Estado neutro gris para $N < 3$ reportes en la zona, sin color ni tope |
| **M21** | Directorio de negocios | `/businesses` | Nuevo v1.1 | **Implementado DEMO** | Catálogo de negocios aprobados de muestra, buscador y filtros |

---

## 4. Trazabilidad Provisional de Requisitos (Plan de Trabajo v1.0)

> El PDF original cita un documento de requisitos v0.1 con 42 Requisitos Funcionales (RF), 10 Reglas de Negocio (RN), 13 Historias de Usuario (HU) y 11 Requisitos No Funcionales (RNF). Dicho documento externo no se encuentra en el repositorio ni en los insumos descargados. Para preservar la integridad y evitar invenciones, se marcan explícitamente con `[FUENTE FALTANTE]`.

| Conjunto | Cantidad Declarada en PDF | Estado en Repositorio | Trazabilidad |
|---|---|---|---|
| **Requisitos Funcionales (RF)** | 42 | Documento externo ausente | `[FUENTE FALTANTE]` (derivados operativamente del Plan Maestro VJ-00..VJ-21) |
| **Reglas de Negocio (RN)** | 10 | Parcialmente citadas en PDF | RN-10 (privacidad de contratos), semáforo por zona (mediana, 15/40%, N=3, ventana 60 días). Restantes: `[FUENTE FALTANTE]` |
| **Historias de Usuario (HU)** | 13 | Documento externo ausente | `[FUENTE FALTANTE]` |
| **Requisitos No Funcionales (RNF)** | 11 | Parcialmente citados en PDF | RNF-09 (pruebas de límites del semáforo: 0%, 15%, 15.01%, 40%, 40.01%, N<3, -40%). Restantes: `[FUENTE FALTANTE]` |
| **Lineamientos del Proyecto** | v3 | Documento externo ausente | `[FUENTE FALTANTE]` |
| **Mockups de Referencia** | 17 (Figma) / 15 (JPGs) / 21 (Adaptados v1.1) | 5 JPGs en paquete descargado | Trazados en matriz M01 a M21 |

---

## 5. Auditoría de Seguridad y Detección de Secretos

- **Gitleaks Scan:** 0 leaks detectados.
- **Rastreo de extensiones sensibles:** Sin `.env`, `.key`, `*.jks`, `*.keystore` en el repositorio.
- **Configuración de Gradle:** `android/app/build.gradle.kts` utiliza firma release con clave debug para desarrollo local (deuda técnica VJ-20).

---

## 6. Implementación y Cierre de VJ-13 (Captura y OCR Local de Contratos)

- **Estado:** **HECHO — verificado en dispositivo (moto_g22, release); PDF diferido** en rama `feature/vj-13-captura-contratos-ocr` (PR #14 integrado en `main`).
- **Alcance MVP:**
  - Soporte de formatos: **JPG, PNG y TXT** (archivos de hasta 10 MB).
  - **Soporte de PDF diferido:** Marcado honestamente como "Próximamente" (`pdfComingSoon`); ML Kit Text Recognition procesa imágenes (bitmaps).
  - **OCR Local en el dispositivo:** `google_mlkit_text_recognition` con script latino. Inferencia 100% on-device.
  - **Texto nativo consolidado de ML Kit (`recognized.text`):** Se utiliza directamente el texto nativo entregado por ML Kit (`recognized.text`), preservando los párrafos, bloques y orden de lectura original generado por el modelo de visión en el dispositivo, sin algoritmos de reordenamiento manual.
  - **Consentimiento propio en la app (RN-10):** Diálogo de consentimiento antes de invocar la cámara o el selector de archivos, informando que el procesamiento se realiza localmente y no se almacena en servidores. La decisión de exhibición reside íntegramente en el provider (`ContractCaptureNotifier`), sin solicitar permisos intrusivos del sistema operativo (CAMERA).
  - **Cumplimiento estricto de RN-10 (No retención):** Eliminación inmediata de archivos temporales en caché generados por `image_picker` y `file_picker` en bloque `finally`, tanto tras el OCR exitoso como en caso de falla, cancelación o descarte del documento (`discardDocument()`).
  - **Reglas mínimas de R8 / Proguard:** Configuración en `android/app/proguard-rules.pro` para preservar los constructores de `ComponentRegistrar` requeridos por la instanciación reflectiva de ML Kit en modo `--release`, suprimiendo advertencias de scripts no empaquetados.
  - **Editor y límite de 15.000 caracteres:** El texto extraído es editable en memoria sin truncamiento silencioso; se advierte y exige recorte manual si excede el límite máximo.
  - **Catálogo de contratos sintéticos:** 3 muestras bilingües (ES/EN) sin datos personales reales para pruebas y demostración segura.

---

## 7. VJ-07 — Backend Supabase (29 de octubre de 2026)

- **D4 ratificada:** Supabase es el backend del MVP (ver `docs/decisiones.md`).
- **Migraciones creadas:**
  - `supabase/migrations/20261027151907_extensions_and_geography.sql`
  - `supabase/migrations/20261027151910_profiles_and_consents.sql`
  - `supabase/migrations/20261029100000_price_catalog.sql`
  - `supabase/migrations/20261029101000_price_reports_and_events.sql`
  - `supabase/migrations/20261029102000_businesses_and_content.sql`
- **Seeds creadas:** 33 departamentos, 25 municipios del Cesar (Valledupar piloto), 5 zonas de Valledupar, 4 categorías de precio, configuración del semáforo y evento DEMO.
- **RLS/GRANT:** 16 tablas con RLS; catálogos públicos de solo lectura; perfiles y consentimientos privados; `ai_usage` exclusivo de `service_role`; columnas de auditoría no editables por el cliente.
- **Pruebas:** `supabase/tests/rls.sql` con 21 aserciones pgTAP.
- **Verificación local (29 de octubre de 2026, CLI 2.101.0 + Docker 29.5.2):**
  - `supabase start` → servicios arriba (PostgreSQL 17, Auth, Storage, Studio).
  - `supabase db reset` → 5 migraciones aplicadas y 6 seeds cargadas (exit 0).
  - `supabase test db` → `Files=1, Tests=21`, `Result: PASS` (21/21 aserciones pgTAP).
- **Estado:** `HECHO-VERIFICADO` (local; PR #15 integrado en `main`). **No se ha aplicado al proyecto remoto** `vjehsjqmwibmiqmxlsou`; requiere aprobación explícita antes de `supabase db push`.

---

## 8. VJ-08 — Autenticación real, sesión, perfil y consentimientos (29 de octubre de 2026)

### 8.1 Dependencia y configuración

- `supabase_flutter ^2.18.3` agregado con `flutter pub add` (31 dependencias transitivas, incluida `gotrue 2.27.3`). Los registrantes de plugins de `linux/`, `macos/` y `windows/` fueron regenerados automáticamente por la herramienta.
- Las credenciales se inyectan en tiempo de compilación y **nunca** se versionan:

```powershell
flutter run -d <device-id> --no-pub `
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-o-publishable-key>
```

- Solo se usa la clave pública (`anon`/`publishable`). La `service_role` es exclusiva de procesos de servidor y no aparece en la app.
- Sin `--dart-define`, `SupabaseSettings.fromEnvironment()` devuelve `null`, `supabaseClientProvider` queda en `null` y `authRepositoryProvider` entrega `DemoAuthRepository`: la app sigue funcionando en modo DEMO y las pantallas rotulan el acceso como tal (`auth.demo_note`).

### 8.2 Capas

- **`domain/` (Dart puro):** `auth_failure.dart`, `auth_session.dart`, `user_profile.dart`, `consent_document.dart`, `sign_up_result.dart` y el contrato `auth_repository.dart`.
- **`data/`:** `supabase_auth_repository.dart` (Auth + `profiles` + `consents`), `demo_auth_repository.dart` (memoria), `auth_failure_mapper.dart` (GoTrue/PostgREST → `AuthFailureKind`), `profile_mapper.dart` (fila → entidad).
- **`presentation/state/`:** `auth_controller.dart` (único `Notifier` que orquesta sesión, perfil, idioma y consentimientos) y `auth_state.dart`.
- **`core/supabase/`:** `supabase_settings.dart`, `supabase_bootstrap.dart` y `supabase_providers.dart`; `main.dart` sobreescribe el provider del cliente solo si la inicialización funciona.
- **Vistas:** `login_page.dart` y `register_page.dart` delegan por completo en `AuthController`; `profile_page.dart` muestra el correo real, permite editar el nombre y persiste idioma y tipo de perfil; `profile_selection_page.dart` persiste la elección del onboarding.

### 8.3 Reglas y decisiones aplicadas

- **Consentimientos:** al registrarse se insertan las dos filas de `public.consents` (`terms_and_conditions`, `privacy_policy`) con `version = 'v1.0'`, alineadas con el CHECK de la migración `20261027151910_profiles_and_consents.sql`.
- **D11 (`resident`) sigue PROPUESTA:** el CHECK de `profiles.profile_type` solo admite `visitor` y `settler`, así que `ProfileType.isPersistable` marca `resident` como no persistible. La app lo conserva en memoria y avisa con `auth.error.profile_type_pending`; no se inventó un valor nuevo en la base.
- **D14 (confirmación de correo) sigue PENDIENTE:** el código ya soporta ambos escenarios. Si Supabase no devuelve sesión tras `signUp`, el controlador expone `AuthFailureKind.emailConfirmationRequired` en lugar de tratarlo como error del usuario. La configuración local mantiene `enable_confirmations = false`.
- **Errores:** ninguno de los nueve `AuthFailureKind` se resuelve en la vista; `auth_failure_text.dart` solo traduce el enum a `'auth.error.*'.tr()`.
- **Sincronización local:** `AuthController._syncLocalProfile` hidrata `userNameProvider` y `profileTypeProvider` con lo que el servidor confirmó, pero no los borra al perder la sesión, para no romper `session_lifecycle_test` ni el flujo DEMO del primer avance.

### 8.4 Verificación ejecutada

- `flutter analyze` → `No issues found!`.
- `flutter test` → **173/173 pruebas aprobadas**, incluidas las 23 nuevas de autenticación.
- Barrido del punto 5.2 sobre `lib/**/presentation/` excluyendo `presentation/state/` → 0 coincidencias de `normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed`.
- **No verificado:** ejecución en dispositivo/emulador Android y `supabase db push` al proyecto remoto. Pendiente de aprobación explícita.

### 8.5 Ruta del código

- **Iniciar sesión:** `LoginPage` → `authControllerProvider.signIn()` → `AuthRepository.signIn()` → `SupabaseAuthRepository` → Supabase Auth (GoTrue).
- **Crear cuenta:** `RegisterPage` → `AuthController.signUp()` → `registerConsents()` + `saveDisplayName()` → `SupabaseAuthRepository` → `consents` / `profiles`.
- **Editar nombre desde Perfil:** `ProfilePage` → `AuthController.saveDisplayName()` → `SupabaseAuthRepository.saveDisplayName()` → `profiles.display_name`.
- **Cambiar idioma:** `ProfilePage` → `AuthController.saveLanguage()` → `SupabaseAuthRepository.saveLanguage()` → `profiles.language`.
- **Elegir tipo de perfil:** `ProfileSelectionPage` → `AuthController.persistProfileType()` → `saveProfileType()` → `profiles.profile_type` (con `resident` bloqueado por D11).

### 8.6 Pendientes de VJ-08

1. Aprobar y ejecutar `supabase db push` contra `vjehsjqmwibmiqmxlsou` (VJ-07 + VJ-08 comparten backend).
2. Resolver D11 (`resident`) y D14 (confirmación de correo) en `docs/decisiones.md`.
3. Probar el recorrido real en emulador Android con `--dart-define` y revisar overflows/logcat.
4. VJ-09: navegación por sesión en el router.

---

## 9. Avance Parcial de VJ-14 (Análisis de Contratos en la Aplicación Móvil)

- **Estado:** **Avance parcial (app); backend pendiente** en rama `feature/vj-14-analisis-contratos-app`.
- **Alcance completado en el cliente móvil:**
  - **Dominio puro y validaciones estrictas:** Entidad `ContractAnalysisResult` (§4.4 de `contrato-datos-v1.md`) con niveles semánticos `green`, `yellow`, `red`, recomendación general, puntos clave y cláusulas analizadas (cita literal, alerta, recomendación y referencia legal nullable). Validación estricta con `FormatException` ante datos incompletos o fuera de límites (máx. 5 puntos clave, máx. 10 cláusulas, textos vacíos). Errores tipados `ContractAnalysisError` (§4.5) con extensiones puras `translationKey` e `isRetryable`.
  - **Gateway y desacoplamiento de arquitectura:** Interfaz `ContractAnalysisGateway` en `domain/` y `DefaultContractAnalysisRepository` en `data/`. La aplicación móvil no contiene dependencias de red prematuras, claves de Gemini ni SDKs directos de IA. Implementación `DemoContractAnalysisGateway` con simulación local rotulada visiblemente como `[DEMO]` y escenarios controlados de éxito y error con reconocimiento automático de los 3 contratos sintéticos (verde, amarillo y rojo).
  - **Control de estado y ciclo de vida (`ContractAnalysisNotifier`):** Estados reactivos `idle`, `analyzing`, `result`, `error`. Bloqueo de doble toque, descarte de respuestas tardías u obsoletas mediante identificador secuencial de petición, reinicio automático ante descarte de documento en `contractCaptureProvider` y reinicio con revocación de consentimiento en `SessionController.signOut`.
  - **Segundo consentimiento informado:** Flujo de consentimiento específico y diferenciado del OCR de RN-10, advirtiendo que el texto saldrá del dispositivo hacia un servicio externo de IA y recomendando el uso de contratos sintéticos en pruebas. La decisión de solicitarlo reside en el provider.
  - **Interfaz estructurada y accesible (`ContractAnalysisResultView`):** Triple canal semántico (color + ícono + texto traducido) integrado con `SemanticStatusColors`. Ocultamiento estricto de referencias legales nulas. Banner visible de demostración. Reintento seguro ante errores transitorios. Adaptación responsiva verificada en dispositivo real (`moto_g22`), a 360 dp y 1.5x de escala de texto sin desbordamientos.
- **Pendiente para cierre definitivo:**
  - Implementación y despliegue de la Edge Function en Supabase con Google Gemini (backend pendiente).
