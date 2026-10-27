# Progreso y Control de Cambios — Vía Justa MVP

**Última actualización:** 27 de octubre de 2026  
**Rama base actual:** `main` (`3df5c7b`) — PR #4, PR #5 y PR #6 integrados.  
**Rama de trabajo VJ-03:** `feature/vj-03-navegacion-shell`  
**Repositorio remoto:** `https://github.com/j4gg-0531/via-justa.git`  
**Entorno de ejecución:** Windows 10/11 x64, PowerShell 5.1  
**Gradle Wrapper:** 9.3.1 (`android/gradle/wrapper/gradle-wrapper.properties`)  
**Android Gradle Plugin:** 9.1.0 (`android/settings.gradle.kts`)  
**Kotlin:** 2.4.0 (`android/settings.gradle.kts`)  
**JVM Target:** Java 17 (`android/app/build.gradle.kts`)  
**Flutter SDK:** Flutter 3.47.7 (canal `stable`, Dart 3.13.5) instalado en `C:\Users\JUAN\flutter` y añadido al PATH de usuario.  
**Suite de pruebas:** 93 pruebas automatizadas ejecutadas y 93 aprobadas (100% éxito).

---

## 1. Tablero Maestro de Tareas (VJ-00 a VJ-21)

| ID | Prioridad | Rol | Tarea | Estado | Dependencias |
|---|---|---|---|---|---|
| **VJ-00** | P0 | Ambos | Inventario inicial, baseline reproducible y control de cambios | **INTEGRADO (PR #4)** | Ninguna |
| **VJ-01** | P0 | Ambos | Decisiones, contrato con compañero, diagrama ER y gobierno | **INTEGRADO (PR #5)** | VJ-00 |
| **VJ-02** | P0 | Frontend | Higiene técnica, README, CI y accesibilidad base | **INTEGRADO (PR #6)** | VJ-00, VJ-01 |
| **VJ-03** | P0 | Frontend | Navegación principal: ShellRoute con 5 pestañas persistentes | **HECHO-VERIFICADO (PR #7)** | VJ-02 |
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

## 2. Inventario de Código en Rama Base (`3df5c7b`)

### Páginas y Widgets de Presentación (`lib/`)
- `lib/main.dart`: Bootstrap con `EasyLocalization` y `ProviderScope`.
- `lib/app/app.dart`: Configuración de `MaterialApp.router` con tema centralizado y delegados de localización.
- `lib/core/router/app_router.dart`: Rutas centralizadas con `GoRouter` (`StatefulShellRoute.indexedStack` con 5 pestañas: `/home`, `/map`, `/scan`, `/businesses`, `/profile`).
- `lib/core/navigation/app_scaffold.dart`: Shell persistente con `NavigationBar` y manejo del botón atrás de Android vía `BackButtonListener`.
- `lib/features/home/presentation/pages/home_page.dart`: Inicio dinámico según perfil (M04 Settler, M05 Visitor, M02 adaptado Resident).
- `lib/features/scan/presentation/pages/scan_page.dart`: Pantalla de escaneo M06 con selector segmentado Precio vs Contrato y visor simulado.
- `lib/features/businesses/presentation/pages/businesses_page.dart`: Directorio M21 de comercios de muestra en Valledupar con buscador y categorías.
- `lib/features/profile/presentation/pages/profile_page.dart`: Perfil de usuario M17, selector de perfil en memoria, conmutador de idioma y logout.
- `lib/features/map_colombia/presentation/pages/map_page.dart`: Mapa departamental con botón volver condicional.

### Capa de Dominio (`domain/`)
- `lib/features/businesses/domain/business.dart`: Entidad inmutable `Business` y enum `BusinessCategory`.
- `lib/features/businesses/domain/business_filter.dart`: Función pura `filterBusinesses` para filtrado por texto y categoría.
- `lib/features/businesses/domain/business_repository.dart`: Interfaz abstracta del repositorio de negocios.

### Capa de Datos (`data/`)
- `lib/features/businesses/data/local_business_repository.dart`: Repositorio local de muestra para comercios en Valledupar.
- `lib/features/municipality/data/local_municipality_repository.dart`: Implementación local que lee `assets/data/municipalities_cesar.json`.

### Recursos y Assets
- `assets/data/municipalities_cesar.json`: 25 municipios del Cesar, Valledupar marcado con `isPilot: true`.
- `assets/translations/es.json` y `assets/translations/en.json`: Claves terminales sincronizadas en 100% de paridad.

### Ausencias Confirmadas
- `supabase/`: Migraciones a cargo de Isaac en `feature/supabase-init`; no tocadas en frontend.
- `.github/workflows/ci.yml`: Pipeline activo en GitHub Actions.

---

## 3. Matriz de Trazabilidad de Mockups (M01 a M21)

| ID | Pantalla | Ruta | Origen | Estado Actual | Adaptación UI/UX v1.1 |
|---|---|---|---|---|---|
| **M01** | Entrada | `/welcome` | `mockup_01.jpg` (izq.) | Demo implementada | Mantener estilo blanco, enlaces a términos/privacidad, Google como demo |
| **M02** | Onboarding perfil | `/onboarding` | `mockup_01.jpg` (cen.) | Demo implementada | Tres tarjetas (incluye Residente D11), saludo dinámico |
| **M03** | Mapa departamentos | `/map` | `mockup_01.jpg` (der.) | Demo provisional | Óvalos provisionales, botón volver condicional integrado |
| **M04** | Inicio Instalación | `/home` | `mockup_02.jpg` (izq.) | Implementado (M04) | Tarjeta principal de instalación, accesos rápidos, "Próximamente" en trámites |
| **M05** | Inicio Visitante | `/home` | `mockup_02.jpg` (cen.) | Implementado (M05) | Banner azul claro DEMO para evento, accesos a Escanear/Mapa/Negocios |
| **M06** | Escanear precio/contrato | `/scan` | `mockup_02.jpg` (der.) | Implementado (M06) | Selector Precio/Contrato; visor de encuadre y estado "Próximamente" |
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
| **M17** | Perfil y ajustes | `/profile` | Nuevo v1.1 | Implementado (M17) | Cambio de idioma es/en, cambio de perfil, ciudad actual y logout |
| **M18** | Vista cultural Valledupar | `/city/20001` | Nuevo v1.1 | Inexistente | Cabecera hero, contenido cultural bilingüe es/en con fuentes citadas |
| **M19** | Registro negocio (4 pasos)| `/businesses/register`| Nuevo v1.1 | Inexistente | Wizard 4 pasos para dueños locales; estado inicial pending |
| **M20** | Estado insuficiente semáforo| `/prices/result` | Nuevo v1.1 | Inexistente | Estado neutro gris para N < 3 reportes, sin recomendación |
| **M21** | Directorio de negocios | `/businesses` | Nuevo v1.1 | Implementado (M21) | Catálogo de negocios aprobados de muestra, buscador y filtros |

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

- **Gitleaks Scan:** 0 leaks detectados.
- **Rastreo de extensiones sensibles:** Sin `.env`, `.key`, `*.jks`, `*.keystore` en el repositorio.
- **Configuración de Gradle:** `android/app/build.gradle.kts` utiliza firma release con clave debug para desarrollo local (deuda técnica VJ-20).
