# Progreso y Control de Cambios — Vía Justa MVP

**Última actualización:** 27 de octubre de 2026  
**Rama base inicial:** `main` (`c082ce81b51064bfbf630d558711fe226fc58434`)  
**Autor commit base:** AnotherFedeer (`Merge pull request #3 from j4gg-0531/feature/entrada-municipio`)  
**Repositorio remoto:** `https://github.com/j4gg-0531/via-justa.git`  
**Entorno de ejecución:** Windows 10/11 x64, PowerShell 5.1  
**Gradle Wrapper:** 9.3.1 (`android/gradle/wrapper/gradle-wrapper.properties`)  
**Android Gradle Plugin:** 9.1.0 (`android/settings.gradle.kts`)  
**Kotlin:** 2.4.0 (`android/settings.gradle.kts`)  
**JVM Target:** Java 17 (`android/app/build.gradle.kts`)  
**Flutter SDK:** No disponible en PATH en la terminal actual (registrado como bloqueo de ejecución local).

---

## 1. Tablero Maestro de Tareas (VJ-00 a VJ-21)

| ID | Prioridad | Rol | Tarea | Estado | Dependencias |
|---|---|---|---|---|---|
| **VJ-00** | P0 | Ambos | Inventario inicial, baseline reproducible y control de cambios | **HECHO-VERIFICADO** | Ninguna |
| **VJ-01** | P0 | Ambos | Decisiones, contrato con compañero, diagrama ER y gobierno | **PENDIENTE** | VJ-00 |
| **VJ-02** | P0 | Frontend | Higiene técnica, README, CI y accesibilidad base | **PENDIENTE** | VJ-00 |
| **VJ-03** | P0 | Frontend | Pantallas 7–9: shell con barra inferior de 5 pestañas | **PENDIENTE** | VJ-02 |
| **VJ-04** | P1 | Ambos | Motor visual de semáforo demo: pantallas 10 y 11 | **PENDIENTE** | VJ-03 |
| **VJ-05** | P1 | Frontend | Pantalla 12: aportar precio en 4 pasos demo | **PENDIENTE** | VJ-04 |
| **VJ-06** | P1 | Ambos | Cierre del primer avance: walkthrough, CI, docs | **PENDIENTE** | VJ-03, VJ-04, VJ-05 |
| **VJ-07** | P0 | Backend | Supabase: migración inicial, RLS, GRANT, seeds y ER | **BLOQUEADO-EXTERNO** | VJ-01, VJ-06 |
| **VJ-08** | P0 | Ambos | Supabase Auth real, sesión, perfil y consentimientos | **PENDIENTE** | VJ-07 |
| **VJ-09** | P0 | Frontend | Navegación por sesión, municipios reales y mapa oficial | **PENDIENTE** | VJ-08 |
| **VJ-10** | P0 | Backend | Función SQL de semáforo: única fuente de verdad | **PENDIENTE** | VJ-07 |
| **VJ-11** | P0 | Ambos | Reportes reales: aporte, límites, fuente y sincronización | **PENDIENTE** | VJ-10 |
| **VJ-12** | P1 | Frontend | Google Maps de precios, filtros y optimización | **BLOQUEADO-EXTERNO** | VJ-11 |
| **VJ-13** | P1 | Frontend | Captura de contratos: cámara, archivos y OCR local | **PENDIENTE** | VJ-06 |
| **VJ-14** | P1 | Ambos | Análisis de contratos con Gemini en Edge Function | **BLOQUEADO-EXTERNO** | VJ-13 |
| **VJ-15** | P2 | Ambos | Vista de ciudad de Valledupar: cultura verificada es/en | **PENDIENTE** | VJ-09 |
| **VJ-16** | P2 | Ambos | Registro de negocio en 4 pasos, RLS y moderación | **PENDIENTE** | VJ-08 |
| **VJ-17** | P2 | Frontend | Negocios: catálogo, detalle y acciones externas | **PENDIENTE** | VJ-16 |
| **VJ-18** | P0 | Ambos | Correcciones cruzadas de seguridad, privacidad y confiabilidad | **PENDIENTE** | VJ-07 a VJ-17 |
| **VJ-19** | P0 | Ambos | Suite de pruebas integrales: accesibilidad y robustez | **PENDIENTE** | VJ-18 |
| **VJ-20** | P0 | Frontend | Entrega Android real: applicationId, firma release, APK | **BLOQUEADO-EXTERNO** | VJ-19 |
| **VJ-21** | P0 | Ambos | Documentación final, sustentación y decisión Go/No-Go | **PENDIENTE** | VJ-20 |

---

## 2. Inventario de Código en Rama Base (`c082ce8`)

### Páginas y Widgets de Presentación (`lib/`)
- `lib/main.dart`: Bootstrap con `EasyLocalization` y `ProviderScope`.
- `lib/app/app.dart`: Configuración de `MaterialApp.router` con tema centralizado y delegados de localización.
- `lib/core/router/app_router.dart`: Rutas centralizadas con `GoRouter` (`/splash`, `/welcome`, `/login`, `/register`, `/onboarding`, `/map`, `/department/:code`, `/municipality/:code`, `/home`).
- `lib/core/session/session_providers.dart`: Estado en memoria para `userNameProvider` y `displayNameProvider` (demo).
- `lib/core/theme/`: `app_colors.dart`, `app_spacing.dart` (incluye `AppRadius`), `app_theme.dart`.
- `lib/core/widgets/`: `vj_button.dart`, `vj_card.dart`, `vj_badge.dart`, `vj_search_field.dart`, `vj_text_field.dart`.
- `lib/features/splash/presentation/pages/splash_page.dart`: Pantalla de inicio con temporizador de 1.8s (excepción temporal documentada en AGENTS.md).
- `lib/features/auth/presentation/pages/welcome_page.dart`: Opciones de ingreso (Google / correo).
- `lib/features/auth/presentation/pages/login_page.dart`: Formulario de inicio de sesión con validación local.
- `lib/features/auth/presentation/pages/register_page.dart`: Formulario de registro con validación de nombre, email, contraseña y términos.
- `lib/features/auth/presentation/state/`: `login_form_provider.dart`, `register_form_provider.dart`.
- `lib/features/auth/presentation/widgets/`: `auth_error_texts.dart`, `legal_text.dart`, `or_divider.dart`.
- `lib/features/onboarding/presentation/pages/profile_selection_page.dart`: Selección de perfiles (Visitante, Instalación, Residente).
- `lib/features/onboarding/presentation/state/profile_type_provider.dart`: Notifier con `autoDispose` para el perfil seleccionado.
- `lib/features/onboarding/presentation/widgets/profile_option_card.dart`: Tarjeta accesible de selección de perfil.
- `lib/features/map_colombia/presentation/pages/map_page.dart`: Mapa interactivo provisional con óvalos y buscador flotante.
- `lib/features/map_colombia/presentation/state/map_providers.dart`: Búsqueda de departamentos en provider.
- `lib/features/municipality/presentation/pages/municipality_selector_page.dart`: Lista con autocompletado de municipios de Cesar.
- `lib/features/municipality/presentation/pages/municipality_page.dart`: Detalle de municipio piloto (`20001`, Valledupar) vs. fuera de piloto.
- `lib/features/municipality/presentation/state/municipality_providers.dart`: Providers para repositorio, consulta por departamento, por código, búsqueda y registro de interés local.
- `lib/features/home/presentation/pages/home_placeholder_page.dart`: Pantalla provisional de inicio a reemplazar por Pantallas 7 y 8.

### Dominio (`domain/`)
- `lib/features/auth/domain/auth_validators.dart`: Validadores puros de nombre, email, longitud de contraseña.
- `lib/features/auth/domain/display_name.dart`: Lógica pura de extracción del primer nombre.
- `lib/features/onboarding/domain/profile_type.dart`: Enum `ProfileType` (`visitor`, `settler`, `resident`).
- `lib/features/map_colombia/domain/department.dart`: Entidad `Department` y catálogo de departamentos de muestra.
- `lib/features/map_colombia/domain/department_search.dart`: Función pura de filtrado de departamentos sin tildes ni mayúsculas.
- `lib/features/municipality/domain/municipality.dart`: Entidad `Municipality`.
- `lib/features/municipality/domain/municipality_repository.dart`: Interfaz abstracta del repositorio de municipios.
- `lib/features/municipality/domain/municipality_search.dart`: Función pura de filtrado de municipios.
- `lib/core/utils/text_normalizer.dart`: Función pura de normalización de cadenas (eliminación de diacríticos y conversión a minúsculas).

### Datos (`data/`)
- `lib/features/municipality/data/local_municipality_repository.dart`: Implementación local que lee `assets/data/municipalities_cesar.json`.

### Recursos y Assets
- `assets/data/municipalities_cesar.json`: 25 municipios del Cesar, Valledupar marcado con `isPilot: true`.
- `assets/translations/es.json` y `assets/translations/en.json`: 60 claves terminales en perfecta paridad.

### Ausencias Confirmadas
- `supabase/`: Inexistente en el repositorio.
- `.github/workflows/`: Inexistente en el repositorio.
- Dependencias de backend/mapas en `pubspec.yaml`: Ausentes (`supabase_flutter`, `google_maps_flutter`).

---

## 3. Matriz de Trazabilidad de Mockups (M01 a M21)

| ID | Pantalla | Ruta | Origen | Estado Actual | Adaptación UI/UX v1.1 |
|---|---|---|---|---|---|
| **M01** | Entrada | `/welcome` | `mockup_01.jpg` (izq.) | Demo implementada | Mantener estilo blanco, enlaces a términos/privacidad, Google como demo |
| **M02** | Onboarding perfil | `/onboarding` | `mockup_01.jpg` (cen.) | Demo implementada | Tres tarjetas (incluye Residente D11), saludo dinámico |
| **M03** | Mapa departamentos | `/map` | `mockup_01.jpg` (der.) | Demo provisional | Óvalos provisionales; pendiente agregar botón Volver y geometría DANE |
| **M04** | Inicio Instalación | `/home` | `mockup_02.jpg` (izq.) | Placeholder | Tarjeta principal, herramientas reales, "Próximamente" en trámites |
| **M05** | Inicio Visitante | `/home` | `mockup_02.jpg` (cen.) | Placeholder | Banner azul claro DEMO para evento, accesos a Escanear/Mapa/Negocios |
| **M06** | Escanear precio/contrato | `/scan` | `mockup_02.jpg` (der.) | Inexistente | Selector Precio/Contrato; "Próximamente" en shell inicial |
| **M07** | Resultado de análisis | `/prices/result` | `mockup_03.jpg` (izq.) | Inexistente | Reemplazar "promedio" por "referencia (mediana)", 3 colores + texto + ícono |
| **M08** | Mapa de precios | `/prices/map` | `mockup_03.jpg` (cen.) | Inexistente | Google Maps o estático rotulado, filtros por categoría |
| **M09** | Detalle negocio/servicio | `/businesses/:id` | `mockup_03.jpg` (der.) | Inexistente | Ficha de negocio verificado, acciones WhatsApp/Llamar/Llegar |
| **M10** | Aportar precio (4 pasos) | `/prices/contribute` | `mockup_04.jpg` (izq.) | Inexistente | Wizard en 4 pasos, validaciones en domain, confirmación rotulada DEMO |
| **M11** | Mis trámites | `/procedures` | `mockup_04.jpg` (cen.) | Fuera de MVP | Aplazado / Fase 2; no simular progreso |
| **M12** | Mis documentos | `/documents` | `mockup_04.jpg` (der.) | Fuera de MVP | Aplazado / Fase 2; no prometer almacenamiento cifrado no existente |
| **M13** | Selector municipios Cesar | `/department/20` | `mockup_05.jpg` (izq.) | Implementado | Cabecera azul oscuro, buscador sin tildes, 25 municipios |
| **M14** | Municipio piloto | `/municipality/20001`| `mockup_05.jpg` (cen.) | Demo implementada | Botón Entrar, insignia de piloto, aviso honesto |
| **M15** | Municipio no piloto | `/municipality/:code` | `mockup_05.jpg` (der.) | Demo implementada | Información no verificada, interés solo en memoria ("Te avisaremos") |
| **M16** | Login / Registro correo | `/login`, `/register` | Nuevo v1.1 | Demo implementada | Formularios rediseñados con validación en `domain/` |
| **M17** | Perfil y ajustes | `/profile` | Nuevo v1.1 | Inexistente | Cambio de idioma es/en, cambio de perfil, ciudad actual y logout |
| **M18** | Vista cultural Valledupar | `/city/20001` | Nuevo v1.1 | Inexistente | Cabecera hero, contenido cultural bilingüe es/en con fuentes citadas |
| **M19** | Registro negocio (4 pasos)| `/businesses/register`| Nuevo v1.1 | Inexistente | Wizard 4 pasos para dueños locales; estado inicial pending |
| **M20** | Estado insuficiente semáforo| `/prices/result` | Nuevo v1.1 | Inexistente | Estado neutro gris para N < 3 reportes, sin recomendación |
| **M21** | Directorio de negocios | `/businesses` | Nuevo v1.1 | Inexistente | Catálogo de negocios aprobados, buscador y filtros |

---

## 4. Trazabilidad Provisional de Requisitos (Plan de Trabajo v1.0)

> El PDF original cita un documento de requisitos v0.1 con 42 Requisitos Funcionales (RF), 10 Reglas de Negocio (RN), 13 Historias de Usuario (HU) y 11 Requisitos No Funcionales (RNF). Dicho documento externo no se encuentra en el repositorio ni en los insumos descargados. Para preservar la integridad y evitar invenciones, se marcan explícitamente con `[FUENTE FALTANTE]`.

| Conjunto | Cantidad Declarada en PDF | Estado en Repositorio | Trazabilidad |
|---|---|---|---|
| **Requisitos Funcionales (RF)** | 42 | Documento externo ausente | `[FUENTE FALTANTE]` (derivados operativamente del Plan Maestro VJ-00..VJ-21) |
| **Reglas de Negocio (RN)** | 10 | Parcialmente citadas en PDF | RN-10 (privacidad de contratos), semáforo (mediana, 15/40%, N=3, ventana 60 días). Restantes: `[FUENTE FALTANTE]` |
| **Historias de Usuario (HU)** | 13 | Documento externo ausente | `[FUENTE FALTANTE]` |
| **Requisitos No Funcionales (RNF)** | 11 | Parcialmente citados en PDF | RNF-09 (pruebas de límites del semáforo: 0%, 15%, 15.01%, 40%, 40.01%, N<3, -40%). Restantes: `[FUENTE FALTANTE]` |
| **Lineamientos del Proyecto** | v3 | Documento externo ausente | `[FUENTE FALTANTE]` |
| **Mockups de Referencia** | 17 (Figma) / 15 (JPGs) / 21 (Adaptados v1.1) | 5 JPGs en paquete descargado | Trazados en matriz M01 a M21 |

---

## 5. Auditoría de Seguridad y Detección de Secretos

- **Gitleaks Scan:** Ejecutado sobre los 6 commits de la historia Git (`gitleaks git --verbose`). Resultado: **0 leaks detectados**, 0 claves expuestas.
- **Rastreo de extensiones sensibles:** `git ls-files` no arrojó coincidencias con `.env`, `key.properties`, `.jks`, o credenciales.
- **Configuración de Gradle:** `android/app/build.gradle.kts` utiliza `com.example.via_justa` como `applicationId` provisional y firma release con la clave de debug (deuda técnica a subsanar en VJ-20).

---

## 6. Estado de Pruebas Automatizadas

- **Total de pruebas declaradas en código:** 66 pruebas distribuidas en 13 archivos dentro de `test/`.
- **Estado de ejecución actual:** **NO EJECUTADAS EN ESTA SESIÓN** debido a la ausencia del ejecutable `flutter` en el PATH de la terminal Windows.
- **Desglose de casos escritos:**
  - `test/auth_pages_test.dart`: 2 casos
  - `test/auth_validators_test.dart`: 16 casos
  - `test/department_search_test.dart`: 4 casos
  - `test/display_name_test.dart`: 5 casos
  - `test/local_municipality_repository_test.dart`: 4 casos
  - `test/login_form_provider_test.dart`: 5 casos
  - `test/municipality_interest_test.dart`: 3 casos
  - `test/municipality_page_test.dart`: 3 casos
  - `test/municipality_providers_test.dart`: 5 casos
  - `test/municipality_search_test.dart`: 11 casos
  - `test/register_form_provider_test.dart`: 5 casos
  - `test/session_providers_test.dart`: 2 casos
  - `test/translations_test.dart`: 1 caso
