# Registro de Decisiones de Arquitectura y Producto (ADRs)

Este documento formaliza el registro de decisiones técnicas y de producto para el proyecto **Vía Justa MVP**, estableciendo su estado, justificación, alternativas e impacto entre frontend y backend.

---

## Índice de Decisiones

| ID | Decisión | Estado | Responsable | Fecha Evidencia |
|---|---|---|---|---|
| **D1** | Soporte bilingüe español/inglés desde el día 1 | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D2** | Internacionalización con `easy_localization` | **ACORDADA** | Frontend | 19 de octubre de 2026 |
| **D3** | Google Maps (`google_maps_flutter`) y Places | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D4** | Backend en Supabase (PostgreSQL, PostGIS, Auth, Storage, Edge Functions) | **PROPUESTA** | Backend | 19 de octubre de 2026 |
| **D5** | Estado con Riverpod 3 y navegación con `go_router` | **ACORDADA** | Frontend | 19 de octubre de 2026 |
| **D6** | Negocios sin pedidos internos (enlace externo) | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D7** | Contacto por WhatsApp externo sin chat propio | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D8** | Arquitectura en capas ligeras y reglas en `AGENTS.md` | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D9** | Gemini en Edge Function como proveedor LLM para contratos | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D10**| Repositorio único, ramas cortas por tarea y PR revisado | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D11**| Tercer perfil de usuario: Local / Residente (`resident`) | **PROPUESTA** | Backend / Ambos | 25 de octubre de 2026 |
| **D12**| Barra inferior fija de cinco pestañas | **ACORDADA** | Frontend | 27 de octubre de 2026 |
| **D13**| Categorías de precio estrictamente comparables | **PROPUESTA** | Ambos | 28 de octubre de 2026 |
| **D14**| Política de contraseñas y confirmación de correo | **PENDIENTE** | Backend | — |
| **D15**| Medianas de precios por zonas del municipio y selección híbrida (GPS / Mapa) | **ACORDADA** | Ambos | 28 de octubre de 2026 |

---

## D1 · Soporte bilingüe en español e inglés desde el primer día
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 19 de octubre de 2026 (Plan de trabajo v1.0, sección 2.2).
- **Descripción:** La aplicación debe soportar español e inglés en todos los textos de la interfaz desde el inicio. No se admite texto estático sin clave de traducción.
- **Justificación técnica:** Los usuarios objetivos abarcan turistas internacionales (inglés), migrantes (inglés/español) y residentes locales (español). La paridad temprana evita costosas refactorizaciones posteriores.
- **Alternativas consideradas:** Español único en MVP y traducción en Fase 2 (descartada por no satisfacer el requisito de inclusión internacional).
- **Impacto Frontend:** Uso exclusivo de `'clave'.tr()`. Test automatizado `translations_test.dart` que exige paridad exacta de claves entre `es.json` y `en.json`.
- **Impacto Backend:** Las entidades con contenido descriptivo curado (`city_content`, `businesses`) deben almacenar versiones en ambos idiomas (`description_es`, `description_en`) o columnas por idioma.

---

## D2 · Gestión de internacionalización con `easy_localization`
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** Adopción del paquete `easy_localization` para cargar recursos JSON en tiempo de ejecución y permitir el cambio de idioma dinámico sin reiniciar la aplicación.
- **Justificación técnica:** API concisa basada en extensiones sobre `String`, soporte inmediato de archivos JSON estructurados y persistencia automática de la preferencia del usuario.
- **Alternativas consideradas:** `flutter_localizations` nativo con archivos `.arb` (más complejo de mantener manualmente) o providers propios con mapas en memoria (propenso a errores).
- **Impacto Frontend:** `EasyLocalization` envuelve la app en `main.dart`. Pantalla de perfil modifica el idioma vía `context.setLocale()`.
- **Impacto Backend:** Ninguno directo.

---

## D3 · Uso de Google Maps (`google_maps_flutter`) y Places
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes (GCP Billing y Android SDK).
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** Visualización de precios y ubicación de negocios mediante Google Maps SDK en Android.
- **Justificación técnica:** Familiaridad para el usuario final, precisión cartográfica en Colombia y cobertura completa de lugares con Places API.
- **Alternativas consideradas:** OpenStreetMap / MapLibre (descartadas por menor detalle urbano y carencia de Places nativo sin servicios terceros).
- **Impacto Frontend:** Requiere clave de API restringida en `AndroidManifest.xml` por `applicationId` y huella SHA-1.
- **Impacto Backend:** Almacenar únicamente `place_id` y coordenadas geográficas (`ST_Point`), evitando almacenar datos propietarios de Google protegidos por términos de servicio.
- **Plan de contingencia:** Si la clave o facturación no están disponibles en avances preliminares, se utilizará un mapa estático debidamente rotulado como DEMO.

---

## D4 · Supabase como plataforma de Backend (BaaS)
- **Estado:** **PROPUESTA** *(Pendiente de ratificación explícita del compañero de backend)*
- **Responsable:** Compañero de backend.
- **Fecha de evidencia:** 19 de octubre de 2026 (registrada como propuesta en el Plan de trabajo).
- **Descripción:** Adopción de Supabase (PostgreSQL 15+, PostGIS, Supabase Auth, Storage y Edge Functions con Deno) como infraestructura única de backend.
- **Justificación técnica:**
  1. Base de datos relacional robusta con soporte geoespacial PostGIS nativo para radios y cuadrantes de precios.
  2. Seguridad a nivel de fila (RLS) que garantiza aislamiento de datos privados directamente en la base de datos.
  3. Edge Functions para encapsular la invocación de Gemini API sin exponer la clave en el cliente móvil.
  4. Cero necesidad de aprovisionar y mantener servidores Linux dedicados.
- **Alternativas consideradas:**
  - Firebase Firestore: No relacional; dificulta el cálculo eficiente de medianas estadísticas ponderadas sobre ventanas de 60 días; sin PostGIS nativo.
  - Backend propio en Node.js/Python: Sobrecarga operativa inasumible para un equipo de 2 personas con 6 semanas de plazo.
- **Impacto Frontend:** Integración de `supabase_flutter` a partir de VJ-07/VJ-08 mediante adaptadores en `data/` controlados por Riverpod.
- **Impacto Backend:** El compañero de backend gestiona las migraciones SQL numeradas, políticas RLS, roles y la configuración de Edge Functions.
- **Condición de activación:** No aplicar migraciones ni instanciar clientes de red hasta la confirmación formal del compañero.

---

## D5 · Gestión de estado con Riverpod 3 y navegación con `go_router`
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** Riverpod 3 como gestor de estado e inyección de dependencias (`Notifier`, `Provider`, `FutureProvider`). `go_router` como enrutador declarativo centralizado.
- **Justificación técnica:** Cero acoplamiento a `BuildContext` para lógica de negocio; recarga y prueba aislada de providers con `ProviderContainer`. `go_router` permite deep-linking y guardas de redirección por sesión.
- **Alternativas consideradas:** `Provider` tradicional (propenso a `ProviderNotFoundException`), `BLoC` (demasiada ceremonia de eventos para un MVP ágil).
- **Impacto Frontend:** Todas las rutas viven en `lib/core/router/app_router.dart`. Estado efímero usa `.autoDispose`.
- **Impacto Backend:** Ninguno.

---

## D6 · Negocios sin pedidos ni transacciones internas
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** La plataforma no gestiona carritos de compras, pasarelas de pago ni cobros a comisiones.
- **Justificación técnica:** Evita implicaciones legales de recaudo, pasarelas bancarias y gestión transaccional de pagos, concentrándose en el valor núcleo de transparencia y contacto.
- **Alternativas consideradas:** Integración de Wompi / PSE (pospuesto a Fase 2).
- **Impacto Frontend:** Botón "Pedir" opcional que redirige mediante `url_launcher` al enlace externo configurado por el comercio.
- **Impacto Backend:** Campo opcional `order_url TEXT` en la tabla `businesses`.

---

## D7 · Contacto por WhatsApp externo sin chat propio
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** La comunicación entre usuarios y dueños de negocio se canaliza vía WhatsApp externo mediante URLs `https://wa.me/<numero>?text=<mensaje>`.
- **Justificación técnica:** Aprovecha el canal comercial estándar en Colombia. Ahorra semanas de desarrollo de WebSockets, notificaciones push de mensajería y almacenamiento de chats.
- **Alternativas consideradas:** Chat en tiempo real basado en Supabase Realtime (descartado por esfuerzo excesivo y falta de moderación de contenido).
- **Impacto Frontend:** Lanzamiento de intent externo con consentimiento del usuario.
- **Impacto Backend:** Columna `whatsapp TEXT` y registro de fecha de consentimiento `whatsapp_consent_at TIMESTAMPTZ` en `businesses`.

---

## D8 · Arquitectura en tres capas ligeras y reglas de higiene en `AGENTS.md`
- **Estado:** **ACORDADA** *(Propuesta en plan original; ratificada en código y documentación)*
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** Estructura modular `presentation/`, `domain/` y `data/` por funcionalidad. Prohibición estricta de lógica de negocio, filtros o acceso a datos en widgets visuales.
- **Justificación técnica:** Facilita la defensa técnica ante el evaluador académico y asegura pruebas unitarias rápidas e independientes del framework.
- **Alternativas consideradas:** Arquitectura por tipo de componente (separar todos los widgets juntos, todos los modelos juntos) — descartada por dificultar el escalamiento por funcionalidad.
- **Impacto:** Cumplimiento continuo de la regla 5.2 de `AGENTS.md` y verificación por regex.

---

## D9 · Gemini como proveedor LLM para análisis de contratos
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** Empleo del modelo Gemini (familia Flash) mediante invocación segura desde una Edge Function para evaluar cláusulas abusivas en contratos de arrendamiento y servicios.
- **Justificación técnica:** Excelente capacidad de razonamiento en español jurídico, soporte de salidas estructuradas en JSON (`responseSchema`), latencia reducida y cuota gratuita adecuada para pruebas.
- **Alternativas consideradas:** OpenAI GPT-4o-mini (descartado por conveniencia de lineamientos del proyecto).
- **Impacto Frontend:** Envío de texto extraído por OCR a la Edge Function; renderizado de semáforo de contrato (`green|yellow|red`) con advertencia legal explícita.
- **Impacto Backend:** Edge Function valida autenticación, aplica límite diario (`ai_usage`), sanitiza el prompt contra inyecciones y valida el esquema JSON retornado. La API Key nunca se incluye en el cliente móvil.

---

## D10 · Repositorio único, ramas cortas por tarea y PR revisado
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 19 de octubre de 2026.
- **Descripción:** Trabajo colaborativo sobre un único repositorio Git. Cada tarea del plan opera en una rama específica (`feature/vj-XX-...` o `fix/vj-XX-...`) y se integra a `main` tras validación.
- **Justificación técnica:** Mantiene sincronizados los contratos entre frontend y backend y previene colisiones de código.
- **Regla:** Rama `main` protegida; commits convencionales; prohibidas las mezclas unilaterales sin autorización.

---

## D11 · Tercer perfil de usuario: Local / Residente (`resident`)
- **Estado:** **PROPUESTA** *(Falta confirmación del compañero de backend antes de aplicar la migración SQL 0001)*
- **Responsable:** Compañero de backend y equipo.
- **Fecha de evidencia:** 25 de octubre de 2026.
- **Descripción:** El onboarding ofrece 3 perfiles: Visitante (`visitor`), Instalación (`settler`) y Residente (`resident`).
- **Justificación técnica:**
  1. Permite diferenciar las necesidades del turista (eventos, precios de urgencia), del recién llegado (trámites, arriendos) y del habitante establecido (registro de su negocio, precios cotidianos de su barrio).
  2. La solicitud del profesor de permitir el registro de negocios locales por usuarios de la comunidad exige que el residente se sienta representado.
- **Reglas críticas:**
  1. **Seguridad:** El perfil de usuario (`profile_type`) **NUNCA confiere privilegios administrativos**. La autorización administrativa no reside en `profiles` (se descarta la columna `role`) sino en la tabla independiente `public.admin_users` mediante la función `public.is_admin()`, preservando el principio de mínimo privilegio y separando el tipo de perfil de la autorización de administración.
  2. **Compatibilidad:** En la migración inicial de backend (`20261027151910_profiles_and_consents.sql`) existe una restricción `check (profile_type in ('visitor', 'settler'))`. La inclusión de 'resident' se mantiene como propuesta formal pendiente de aprobación de Isaac para incorporar la migración complementaria correspondiente.
  3. **Comportamiento inicial:** Para el primer avance, el perfil `resident` compartirá la experiencia de `settler` con una marca `TODO(D11)` en el dominio.

---

## D12 · Barra inferior fija de cinco pestañas
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 27 de octubre de 2026 (Plan v1.1 y auditoría).
- **Descripción:** Implementación de navegación principal fija con 5 pestañas: `Inicio`, `Mapa`, `Escanear` (central), `Negocios` y `Perfil`.
- **Justificación técnica:** Los mockups heredados cambiaban la navegación según el perfil ("Guardados" vs "Dinero"), lo cual generaba desorientación y estados incoherentes al cambiar de perfil. La barra fija simplifica la estructura de rutas (`ShellRoute`) y mantiene accesibles las funcionalidades clave.
- **Impacto Frontend:** Pestañas no desarrolladas en el avance mostrarán un estado accesible "Próximamente" sin bloquear la navegación.

---

## D13 · Categorías de precio estrictamente comparables
- **Estado:** **PROPUESTA** *(Implementadas en el catálogo DEMO de Valledupar; pendiente de ratificación final en seed SQL)*
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 28 de octubre de 2026 (`VJ-04` y `VJ-05`).
- **Descripción:** Definir la lista de categorías y subcategorías obligatorias para el reporte y consulta de precios con unidades explícitas.
- **Justificación técnica:** Una regla estadística de mediana pierde validez si compara magnitudes heterogéneas. Por ejemplo, en "Transporte" debe compararse "Carrera mínima urbana de taxi" frente a la misma unidad.
- **Catálogo implementado en el piloto de Valledupar (`DemoPriceVerdictRepository`):**
  1. `taxi_urbano_corto`: Carrera urbana corta en taxi (trayecto urbano estándar 3–5 km).
  2. `almuerzo_corriente`: Almuerzo corriente / ejecutivo (plato del día con sopa, seco y bebida).
  3. `hotel_estandar_noche`: Habitación estándar (1 noche, acomodación sencilla/doble).
  4. `arriendo_estudio_mes`: Arriendo mensual apartaestudio (1 habitación, estrato medio).
  5. `consulta_medica_particular`: Consulta médica general particular (1 consulta presencial).

---

## D14 · Política de contraseñas y confirmación de correo
- **Estado:** **PENDIENTE** *(Requiere definición del compañero de backend en Supabase Auth)*
- **Responsable:** Compañero de backend.
- **Descripción:** Establecer la política de seguridad para el registro de cuentas:
  1. Longitud mínima de contraseña: 8 caracteres (validada en `auth_validators.dart`).
  2. Confirmación de correo por enlace o token: Definir si el usuario debe confirmar obligatoriamente su correo antes de acceder al sistema o si se permite un estado de gracia inicial.
- **Recomendación arquitectónica:** En el MVP, habilitar auto-confirmación o modo tolerante en desarrollo para facilitar las pruebas del evaluador sin depender de servidores SMTP reales.

---

## D15 · Medianas de precios segmentadas por zonas del municipio y selección híbrida (GPS / Mapa)
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes (Frontend y Contrato de Datos v1.1).
- **Fecha de evidencia:** 28 de octubre de 2026 (`VJ-04`, `VJ-05`, `docs/contrato-datos-v1.md` y `docs/modelo-er.puml`).
- **Descripción:**
  1. Las medianas estadísticas de precios no se calculan de forma plana para todo el municipio, sino segmentadas por **zonas dentro del municipio** (`public.municipality_zones`). En el piloto de Valledupar (`20001`), se definen 5 zonas: Zona Norte (`vup_norte`), Zona Centro (`vup_centro`), Zona Sur (`vup_sur`), Zona Oriente (`vup_oriente`) y Zona Occidente (`vup_occidente`).
  2. Para elegir la zona sin fricción manual, la app ofrece un **selector híbrido**:
     - **Modo automático (GPS)**: solicita permiso de ubicación al usuario para detectar automáticamente la zona en la que se encuentra.
     - **Modo manual en mapa interactivo**: si el usuario decide no conceder permiso de ubicación (o desea consultar/aportar en otra zona de la ciudad), puede tocar cualquier punto o marcador directamente sobre el mapa por zonas del municipio, y la función pura de dominio `resolveNearestZoneByNormalizedPoint` selecciona la zona correspondiente.
- **Justificación técnica:** En una misma ciudad como Valledupar, los costos de restaurantes, taxis y hospedaje varían significativamente entre sectores comerciales/turísticos (Zona Norte / Novalito) y sectores populares o terminales (Zona Sur / Terminal). Segmentar por `(municipality_code, zone_id, category_id)` evita sesgos estadísticos.
- **Impacto Frontend:** Implementado en `MunicipalityZone`, `ZoneMapPickerCard`, `PriceScanPage` (`M06`), `PriceResultPage` (`M07`/`M20`) y `ContributePricePage` (`M10`).
- **Impacto Backend:** Conciliado en `docs/contrato-datos-v1.md` y `docs/modelo-er.puml` mediante la tabla `public.municipality_zones`, la llave foránea `zone_id` en `public.price_reports` y el parámetro `p_zone_id` en la RPC `public.evaluate_price_verdict`.
