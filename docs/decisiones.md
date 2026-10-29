# Registro de Decisiones de Arquitectura y Producto (ADRs)

Este documento formaliza el registro de decisiones técnicas y de producto para el proyecto **Vía Justa MVP**, estableciendo su estado, justificación, alternativas e impacto entre frontend y backend.

---

## Índice de Decisiones

| ID | Decisión | Estado | Responsable | Fecha Evidencia |
|---|---|---|---|---|
| **D1** | Soporte bilingüe español/inglés desde el día 1 | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D2** | Internacionalización con `easy_localization` | **ACORDADA** | Frontend | 19 de octubre de 2026 |
| **D3** | Google Maps (`google_maps_flutter`) y Places | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D4** | Backend en Supabase (PostgreSQL, PostGIS, Auth, Storage, Edge Functions) | **ACORDADA** | Backend | 29 de octubre de 2026 |
| **D5** | Estado con Riverpod 3 y navegación con `go_router` | **ACORDADA** | Frontend | 19 de octubre de 2026 |
| **D6** | Negocios sin pedidos internos (enlace externo) | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D7** | Contacto por WhatsApp externo sin chat propio | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D8** | Arquitectura en capas ligeras y reglas en `AGENTS.md` | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D9** | Gemini en Edge Function como proveedor LLM para contratos | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D10**| Repositorio único, ramas cortas por tarea y PR revisado | **ACORDADA** | Ambos | 19 de octubre de 2026 |
| **D11**| Tercer perfil de usuario: Local / Residente (`resident`) | **ACORDADA** | Backend / Ambos | 29 de octubre de 2026 |
| **D12**| Barra inferior fija de cinco pestañas | **ACORDADA** | Frontend | 27 de octubre de 2026 |
| **D13**| Categorías de precio estrictamente comparables | **ACORDADA** | Ambos | 29 de octubre de 2026 |
| **D14**| Política de contraseñas y confirmación de correo | **ACORDADA** | Backend | 29 de octubre de 2026 |
| **D15**| Medianas de precios por zonas del municipio y selección híbrida (GPS / Mapa) | **ACORDADA** | Ambos | 28 de octubre de 2026 |
| **D16**| Geometría del mapa de departamentos desde SVG de Simplemaps convertido a JSON por script | **ACORDADA** | Frontend | 28 de octubre de 2026 |
| **D17**| Reglas mínimas de R8 / Proguard para OCR en Release (ComponentRegistrar) | **ACORDADA** | Frontend | 28 de octubre de 2026 |
| **D18**| Formatos de contrato en MVP (JPG, PNG, TXT) y diferimiento de PDF | **ACORDADA** | Ambos | 28 de octubre de 2026 |
| **D19**| Texto nativo de ML Kit (recognized.text) sin reordenamiento manual | **ACORDADA** | Frontend | 28 de octubre de 2026 |
| **D20**| Gateway abstracto (`ContractAnalysisGateway`) y modelo desacoplado (`ContractAnalysisResult`) | **ACORDADA** | Ambos | 29 de octubre de 2026 |
| **D21**| Reutilización de `SemanticStatusColors` para el nivel de riesgo de contratos | **ACORDADA** | Frontend | 29 de octubre de 2026 |
| **D22**| Segundo consentimiento informado para análisis con IA de terceros | **ACORDADA** | Ambos | 29 de octubre de 2026 |
| **D23**| Navegación reactiva y declarativa con `GoRouter` y estado de sesión tri-estado | **ACORDADA** | Frontend | 29 de octubre de 2026 |

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
- **Estado:** **ACORDADA** *(Ratificada por el responsable de backend el 29 de octubre de 2026)*
- **Responsable:** Backend (responsable único de Supabase).
- **Fecha de evidencia:** 19 de octubre de 2026 (registrada como propuesta en el Plan de trabajo); ratificada el 29 de octubre de 2026.
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
- **Condición de activación:** Cumplida. El proyecto Supabase de desarrollo fue creado y vinculado; a partir de VJ-07 las migraciones se versionan en `supabase/migrations/` y se aplican con el CLI.

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
- **Estado:** **ACORDADA** *(Ratificada por Backend en la migración `20261029120000_close_vj07_vj08_d11_and_account_deletion.sql`)*
- **Responsable:** Compañero de backend y equipo.
- **Fecha de evidencia:** 25 de octubre de 2026 (propuesta); ratificada el 29 de octubre de 2026.
- **Descripción:** El onboarding ofrece 3 perfiles: Visitante (`visitor`), Instalación (`settler`) y Residente (`resident`).
- **Justificación técnica:**
  1. Permite diferenciar las necesidades del turista (eventos, precios de urgencia), del recién llegado (trámites, arriendos) y del habitante establecido (registro de su negocio, precios cotidianos de su barrio).
  2. La solicitud del profesor de permitir el registro de negocios locales por usuarios de la comunidad exige que el residente se sienta representado.
- **Reglas críticas:**
  1. **Seguridad:** El perfil de usuario (`profile_type`) **NUNCA confiere privilegios administrativos**. La autorización administrativa no reside en `profiles` (se descarta la columna `role`) sino en la tabla independiente `public.admin_users` mediante la función `public.is_admin()`, preservando el principio de mínimo privilegio y separando el tipo de perfil de la autorización de administración.
  2. **Compatibilidad:** En la migración `20261029120000_close_vj07_vj08_d11_and_account_deletion.sql` se actualizó la restricción `profiles_profile_type_check` a `check (profile_type in ('visitor', 'settler', 'resident'))`, habilitando a nivel de base de datos la persistencia de los tres perfiles.
  3. **Implementación Frontend (VJ-09b):** En `ProfileType.isPersistable` se habilitó `resident` para persistir junto con `visitor` y `settler` en `public.profiles.profile_type`. En `MunicipalityPage`, al presionar `Entrar a...`, se persiste `current_municipality_code` en `public.profiles.current_municipality_code`, permitiendo la hidratación completa de sesión y redirección directa a `/home` al reiniciar la aplicación sin repetir el onboarding ni la selección de municipio.

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
- **Estado:** **ACORDADA** *(Ratificada en `supabase/seed/04_price_categories.sql` y en el catálogo del municipio piloto)*
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 28 de octubre de 2026 (`VJ-04` y `VJ-05`); ratificada en seed SQL el 29 de octubre de 2026 (`VJ-07` y `VJ-10`).
- **Descripción:** Definir la lista de categorías y subcategorías obligatorias para el reporte y consulta de precios con unidades explícitas.
- **Justificación técnica:** Una regla estadística de mediana pierde validez si compara magnitudes heterogéneas. Por ejemplo, en "Transporte" debe compararse "Carrera mínima urbana de taxi" frente a la misma unidad.
- **Catálogo implementado en el piloto de Valledupar (`04_price_categories.sql`):**
  1. `taxi_urbano_corto`: Carrera urbana corta en taxi (trayecto urbano estándar 3–5 km, `min_amount_cop = 4000`, `max_amount_cop = 80000`).
  2. `almuerzo_corriente`: Almuerzo corriente / ejecutivo (plato del día con sopa, seco y bebida, `min_amount_cop = 8000`, `max_amount_cop = 120000`).
  3. `hotel_estandar_noche`: Habitación estándar (1 noche, acomodación sencilla/doble, `min_amount_cop = 40000`, `max_amount_cop = 1500000`).
  4. `arriendo_estudio_mes`: Arriendo mensual apartaestudio (1 habitación, estrato medio, `min_amount_cop = 300000`, `max_amount_cop = 6000000`).
  *(Nota: el catálogo DEMO local incluye adicionalmente `consulta_medica_particular` para pruebas en memoria).*

---

## D14 · Política de contraseñas y confirmación de correo
- **Estado:** **ACORDADA** *(Configurada en `supabase/config.toml` para el MVP)*
- **Responsable:** Compañero de backend.
- **Fecha de evidencia:** 29 de octubre de 2026 (`VJ-08` / `VJ-10`).
- **Descripción:** Establecer la política de seguridad para el registro de cuentas:
  1. Longitud mínima de contraseña: 8 caracteres (`minimum_password_length = 8` en `supabase/config.toml` y validada en `auth_validators.dart`).
  2. Confirmación de correo: En el entorno de desarrollo y evaluación del MVP se establece `enable_confirmations = false` en `[auth.email]` (`supabase/config.toml`) para permitir el registro y prueba inmediata por parte del evaluador académico sin depender de entrega SMTP externa, manteniendo en `AuthController` el soporte para `emailConfirmationRequired` si se habilita en producción.

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

---

## D16 · Geometría del mapa de departamentos desde SVG de Simplemaps convertido a JSON por script
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 28 de octubre de 2026 (`M03` / `VJ-09`).
- **Descripción:** Reemplazo del mapa provisional de departamentos por la geometría vectorial real de los 33 territorios de Colombia (32 departamentos + Bogotá, D.C.) extraída del archivo `tools/source/co.svg` (Simplemaps.com, licencia comercial gratuita) y convertida mediante `tools/svg_to_geo_json.py` a `assets/data/colombia_departments_geo.json`.
- **Justificación técnica:**
  1. Evita coordenadas inventadas a mano y elimina dependencias externas de parseo SVG en tiempo de ejecución.
  2. Mantiene `DepartmentRepository` síncrono para el catálogo (`Department`: `code`, `name`, `isAvailable`) y aísla la carga asíncrona de anillos poligonales en `DepartmentShapeRepository` (`LocalDepartmentShapeRepository`), uniendo catálogo y geometría únicamente por código DANE de 2 dígitos.
  3. Soporta múltiples anillos por territorio (islas en San Andrés y Providencia `'88'`, Bolívar `'13'`, Cauca `'19'`, Chocó `'27'` y Nariño `'52'`) y prioriza enclaves como Bogotá, D.C. (`'11'`) sobre Cundinamarca (`'25'`).
- **Alternativas consideradas:**
  - Shapefiles completos del Marco Geoestadístico Nacional (MGN) del DANE: peso elevado para empaquetado directo en móvil sin preprocesamiento cartográfico; queda como mejora futura.
  - Polígonos aproximados escritos a mano: descartados por baja fidelidad visual.
- **Impacto Frontend:** `DepartmentShape`, `DepartmentShapeRepository`, `LocalDepartmentShapeRepository`, `findDepartmentAtPoint` y renderizado `CustomPainter` en `MapPage` con crédito explícito a Simplemaps (aclarando que no es cartografía oficial DANE).
- **Impacto Backend:** Ninguno; la geometría es un recurso estático del cliente móvil y no se almacena en `public.departments`.

---

## D17 · Reglas mínimas de R8 / Proguard para OCR en Release (ComponentRegistrar)
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 28 de octubre de 2026 (VJ-13).
- **Descripción:** Inclusión en ndroid/app/proguard-rules.pro de la regla mínima:
  `proguard
  -keep class * implements com.google.firebase.components.ComponentRegistrar {
      public <init>();
  }
  `
  y supresión puntual con -dontwarn de los constructores de opciones para scripts no empaquetados (chino, devanagari, japonés y coreano).
- **Justificación técnica:**
  1. google_mlkit_text_recognition utiliza internamente el contenedor de inyección de dependencias de Firebase/ML Kit (ComponentDiscovery), el cual instancia por reflexión las clases declaradas como <meta-data> en el manifiesto fusionado (CommonComponentRegistrar, VisionCommonRegistrar, TextRegistrar).
  2. En compilaciones --release, el optimizador R8 eliminaba el constructor público sin argumentos <init>() de dichas clases por considerarlo no referenciado estáticamente, provocando un fallo en tiempo de ejecución (java.lang.NullPointerException: Attempt to invoke virtual method 'java.lang.Class java.lang.Object.getClass()' on a null object reference) al resolver SharedPrefManager.
  3. La regla acota la preservación exclusivamente a las clases que implementan ComponentRegistrar, evitando reglas genéricas permisivas sobre la totalidad del SDK de ML Kit.
- **Impacto Frontend:** ndroid/app/proguard-rules.pro resuelve el fallo de R8 en --release sin alterar uild.gradle.kts ni el pplicationId.
- **Impacto Backend:** Ninguno.

---

## D18 · Formatos de contrato en MVP (JPG, PNG, TXT) y diferimiento de PDF para Fase 2
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 28 de octubre de 2026 (VJ-13).
- **Descripción:** El MVP de captura de contratos admite exclusivamente imágenes en formato **JPG (JPEG)** y **PNG**, así como archivos de texto plano **TXT**, con un tamaño máximo de 10 MB. La carga de archivos PDF queda explícitamente marcada como "Próximamente" (pdfComingSoon).
- **Justificación técnica:**
  1. El motor de OCR on-device google_mlkit_text_recognition procesa mapas de bits individuales (InputImage), no documentos vectoriales ni archivos PDF multipágina.
  2. Rasterizar PDFs localmente en Flutter requeriría dependencias pesadas de renderizado nativo (pdfx, pdf_render, 
ative_pdf_renderer) o procesamiento en backend que aumentaría sustancialmente el peso del APK y la complejidad de memoria en dispositivos de gama media/baja.
  3. Para el caso de uso principal en terreno (fotografiar un contrato impreso en papel o cargar una foto/captura de pantalla), JPG y PNG cubren la necesidad inmediata, complementados con TXT para contratos digitales copiados.
  4. El selector de archivos incluye la extensión .pdf para que, en caso de que el usuario seleccione un PDF, el sistema lo identifique amigablemente y muestre el aviso educativo "Próximamente" en lugar de fallar o ignorar la selección.
- **Impacto Frontend:** alidateContractFileExtension en domain/contract_capture.dart retorna ContractCaptureError.pdfComingSoon.
- **Impacto Backend:** Preparación para que en VJ-14, la Edge Function de Gemini reciba directamente el texto UTF-8 normalizado y consolidado por ML Kit (hasta 15.000 caracteres), sin necesidad de parsear PDFs binarios en el servidor.
---

## D19 · Texto nativo de ML Kit (recognized.text) sin reordenamiento manual
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 28 de octubre de 2026 (VJ-13).
- **Descripción:** La extracción OCR mediante `google_mlkit_text_recognition` utiliza directamente el texto consolidado por la librería (`recognized.text`) en lugar de algoritmos de ordenamiento geométrico propios basados en cajas delimitadoras (`top`/`left`).
- **Justificación técnica:**
  1. El modelo de visión de ML Kit agrupa internamente las palabras en líneas, párrafos y bloques de lectura según la orientación, densidad y flujo textual del documento.
  2. Los algoritmos manuales de reordenamiento basados en coordenadas absolutas pueden descomponer columnas, invertir el orden en capturas con inclinación angular leve o fragmentar oraciones contiguas.
  3. `recognized.text` entrega un resultado significativamente más robusto y fiel en documentos reales capturados con la cámara del dispositivo móvil.
- **Impacto Frontend:** `DeviceContractOcrRepository` retorna directamente `recognized.text`. Se eliminaron de `domain/contract_capture.dart` las funciones y clases geométricas no utilizadas (`OcrTextLine`, `sortOcrTextLines`, `composeSortedOcrText`).
- **Impacto Backend:** Ninguno.
---

## D20 · Gateway abstracto (`ContractAnalysisGateway`) y modelo desacoplado (`ContractAnalysisResult`)
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 29 de octubre de 2026 (VJ-14).
- **Descripción:** La interacción de análisis de contratos se estructura mediante una interfaz abstracta en el dominio (`ContractAnalysisGateway`) y un modelo inmutable estricto (`ContractAnalysisResult`), sin dependencias de red prematuras, SDKs de Gemini ni referencias a Supabase en la aplicación móvil.
- **Justificación técnica:**
  1. La aplicación móvil jamás debe contener claves de API de Gemini ni comunicarse directamente con Google AI; la llamada real debe ser intermediada por una Edge Function de Supabase con autenticación JWT y validación de cuotas.
  2. El modelo demo previo (`ContractAnalysis`) se preserva intacto para garantizar la compatibilidad regresiva del catálogo inicial de la pantalla de escaneo.
  3. `ContractAnalysisResult.fromMap` implementa una deserialización estricta con `FormatException` que valida el nivel (`green`, `yellow`, `red`), campos requeridos no vacíos y máximos seguros (hasta 5 puntos clave y hasta 10 cláusulas analizadas).
  4. Los errores se modelan de forma tipada y exhaustiva mediante `ContractAnalysisError`, mapeando fallos HTTP y de infraestructura sin exponer información técnica sensible en la vista.
- **Impacto Frontend:** Creación de `ContractAnalysisGateway`, `DefaultContractAnalysisRepository`, `DemoContractAnalysisGateway`, `ContractAnalysisResult` y `ContractAnalysisNotifier`.
- **Impacto Backend:** La Edge Function futura de Supabase deberá apegarse estrictamente al contrato de datos JSON definido en `docs/contrato-datos-v1.md` §4.4 y §4.5.

---

## D21 · Reutilización de `SemanticStatusColors` para el nivel de riesgo de contratos
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 29 de octubre de 2026 (VJ-14).
- **Descripción:** El nivel de riesgo del contrato (`green`, `yellow`, `red`) utiliza la extensión de tema `SemanticStatusColors` (`styleForContractLevel`) para definir los estilos visuales de borde, fondo, texto e ícono.
- **Justificación técnica:**
  1. Cumple la directriz de diseño del proyecto: los colores verde, ámbar y rojo se reservan exclusivamente para estados semánticos tipo semáforo.
  2. Garantiza accesibilidad WCAG AA: el estado del contrato nunca depende únicamente del color, integrando siempre triple canal informativo (color de fondo/borde + ícono temático obligatorio + texto explicativo traducido mediante `.tr()`).
  3. Mantiene la coherencia visual con los veredictos de precios (`PriceVerdictLevel`).
- **Impacto Frontend:** Método `styleForContractLevel` en `SemanticStatusColors` e integración en `ContractAnalysisResultView`.
- **Impacto Backend:** Ninguno.

---

## D22 · Segundo consentimiento informado para análisis con IA de terceros
- **Estado:** **ACORDADA**
- **Responsable:** Ambos integrantes.
- **Fecha de evidencia:** 29 de octubre de 2026 (VJ-14).
- **Descripción:** Se establece un flujo de consentimiento informado independiente y diferenciado del consentimiento de OCR local (RN-10). Este segundo consentimiento advierte al usuario que el texto del contrato saldrá del teléfono hacia un servicio de IA de terceros para ser analizado, y exige en la etapa de prueba el uso exclusivo de contratos sintéticos o textos anonimizados.
- **Justificación técnica:**
  1. Legalmente y según las directrices de privacidad, el procesamiento local de imágenes (on-device) difiere sustancialmente de la transmisión de datos hacia un servicio cloud o LLM de terceros.
  2. La decisión de solicitar el consentimiento reside en el estado del provider (`ContractAnalysisNotifier`), conservándose durante la sesión activa y revocándose al cerrar sesión (`SessionController.signOut`).
- **Impacto Frontend:** Estado `hasGivenAiConsent` y diálogo `_showAiConsentDialog` en `ContractCaptureSection`.
- **Impacto Backend:** Ninguno.

---

## D23 · Navegación reactiva y declarativa con `GoRouter` y estado de sesión tri-estado
- **Estado:** **ACORDADA**
- **Responsable:** Frontend.
- **Fecha de evidencia:** 29 de octubre de 2026 (VJ-09a).
- **Descripción:** La navegación y el control de acceso en la aplicación móvil se articulan de forma puramente declarativa y reactiva mediante `GoRouter` y la regla de dominio `resolveNavigationRedirect`:
  1. **Puente reactivo (`_AuthSessionListenable`):** `routerProvider` utiliza un `refreshListenable` que observa única y exclusivamente el estado de sesión en `authControllerProvider` (`isAuthenticated` e `isRestoring`). No reacciona a providers transitorios de selección (perfil o municipio), evitando saltos indeseados de pantalla durante la interacción del usuario antes de confirmar.
  2. **Estado de sesión tri-estado (`SessionNavigationStatus`):** Se introdujo el enum con estados `unknown`, `unauthenticated` y `authenticated`. Cuando la app inicia y se está restaurando el token de sesión (`unknown`), el router mantiene al usuario en `/splash`, eliminando el destello visual prematuro hacia `/welcome`.
  3. **Protección de rutas sin sesión:** Toda ruta privada protegida (`/home`, `/onboarding`, `/departments`, etc.) redirige de inmediato a `/welcome` si el estado es `unauthenticated`.
  4. **Resolución del primer paso incompleto (`resolveFirstIncompleteStep`):** Usuarios autenticados que intentan ingresar a pantallas públicas (`/welcome`, `/login`, `/register`) son redirigidos de forma jerárquica a su primer paso pendiente:
     - Sin perfil seleccionado → `/onboarding`.
     - Sin municipio seleccionado → `/departments`.
     - Perfil y municipio listos → `/home`.
  5. **Exploración libre de municipios:** Las rutas de municipios (`/departments`, `/department/:code`, `/municipality/:code`) no se bloquean si el usuario ya seleccionó un municipio previamente, permitiendo cambiar de ciudad en cualquier momento.
  6. **Cero navegación imperativa en vistas:** Se eliminaron los llamados directos a `context.go()` y `context.push()` tras login, registro y cierre de sesión (`ProfilePage`). Las vistas delegan toda la transición al ciclo de vida de los providers y a `GoRouter`.
- **Justificación técnica:**
  1. Cumplimiento estricto de la regla de arquitectura del proyecto (Regla 5.2): la lógica de redirección y permisos reside en funciones puras de dominio (`session_navigation_rule.dart`), facilitando pruebas unitarias exhaustivas sin instanciar widgets ni Flutter.
  2. Experiencia de usuario limpia y sin parpadeos: se eliminan condiciones de carrera entre la restauración asíncrona del token de autenticación y el router.
  3. Consistencia total con el cierre de sesión (`SessionController.signOut`): limpiar el estado notifica automáticamente al router, devolviendo al usuario a `/welcome` sin bloques `try/catch` ni llamadas imperativas en la UI.
- **Impacto Frontend:** Creación de `SessionNavigationStatus`, `resolveNavigationRedirect` y `classifyRoute` en `session_navigation_rule.dart`; integración en `app_router.dart`; flag `isRestoring` en `AuthState` y `AuthController`; desmonte de navegación imperativa en `LoginPage`, `RegisterPage` y `ProfilePage`.
- **Impacto Backend:** Ninguno.


