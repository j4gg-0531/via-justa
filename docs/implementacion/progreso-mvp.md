# Progreso y Control de Cambios — Vía Justa MVP

**Última actualización:** 29 de octubre de 2026 (VJ-07 backend: migraciones, RLS, GRANT y seeds; prueba local pendiente por Docker)  
**Rama base actual:** `main` — PRs #4 a #9 en integración; rama actual `feature/vj-06-cierre-primer-avance`  
**Repositorio remoto:** `https://github.com/j4gg-0531/via-justa.git`  
**Entorno de ejecución:** Windows 10/11 x64, PowerShell 5.1  
**Gradle Wrapper:** 9.3.1 (`android/gradle/wrapper/gradle-wrapper.properties`)  
**Android Gradle Plugin:** 9.1.0 (`android/settings.gradle.kts`)  
**Kotlin:** 2.4.0 (`android/settings.gradle.kts`)  
**JVM Target:** Java 17 (`android/app/build.gradle.kts`)  
**Flutter SDK:** Flutter 3.47.7 (canal `stable`, Dart 3.13.5) instalado en `C:\Users\JUAN\flutter` y añadido al PATH de usuario.  
**Suite de pruebas:** 138 pruebas automatizadas ejecutadas y 138 aprobadas (100% éxito), incluyendo el recorrido E2E del Primer Avance (`test/first_milestone_walkthrough_test.dart`).

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
| **VJ-07** | P0 | Backend | Supabase: migración inicial, RLS, GRANT, seeds y ER | **HECHO-SIN-PRUEBA** (migraciones/seeds/RLS creados; `supabase test db` pendiente por Docker) | VJ-01, VJ-06 |
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

## 6. VJ-07 — Backend Supabase (29 de octubre de 2026)

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
- **Estado:** `HECHO-SIN-PRUEBA`. El daemon de Docker no estaba disponible en el entorno local, por lo que `supabase db reset` y `supabase test db` no se pudieron ejecutar. **No se ha aplicado al proyecto remoto.**
- **Siguiente paso:** levantar Docker Desktop, ejecutar `supabase db reset` y `supabase test db`, corregir cualquier error y luego abrir el PR.
