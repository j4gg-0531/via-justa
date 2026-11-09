# Progreso, Control de Cambios y Dictamen Go/No-Go — Vía Justa MVP

**Última actualización:** 8 de noviembre de 2026 (Cierre de Backend y Documentación Final `VJ-18` a `VJ-21`)  
**Rama actual:** `feature/vj-20-vj-21-release-y-documentacion-final`  
**Repositorio remoto:** `https://github.com/j4gg-0531/via-justa.git`  
**Proyecto Supabase Remoto:** `via-justa` (`vjehsjqmwibmiqmxlsou`, PostgreSQL 17.11 — `14/14` migraciones sincronizadas en la nube)  
**Entorno de ejecución:** Windows 10/11 x64, PowerShell 5.1, Flutter `3.47.7` (`stable`), Dart `3.13.5`, Supabase CLI `2.101.0`  
**Suites de pruebas automatizadas:**
- **Flutter (`test/`):** `252/252` pruebas unitarias, de widgets y E2E en PASS.
- **PostgreSQL pgTAP (`supabase/tests/`):** `9` suites con `168` aserciones cubriendo RLS, semáforo estadístico, cuotas de reportes, geoespacial/mapa, cuota IA, contenido cultural/eventos, negocios/Storage/moderación, catálogo/acciones externas y auditoría cruzada de seguridad (`VJ-18`/`VJ-19`).
- **Edge Function Deno (`supabase/functions/analyze_contract/`):** `6` bloques de pruebas unitarias y de handler HTTP en `contract_analyzer_test.ts`.

---

## 1. Tablero Maestro de Tareas (`VJ-00` a `VJ-21`)

| ID | Prioridad | Rol | Tarea | Estado | Evidencia / Rama / PR |
|---|---|---|---|---|---|
| **VJ-00** | P0 | Ambos | Inventario inicial, baseline reproducible y control de cambios | **INTEGRADO** | PR #4 (`main`) |
| **VJ-01** | P0 | Ambos | Decisiones, contrato con compañero, diagrama ER y gobierno | **INTEGRADO** | PR #5 (`main`) |
| **VJ-02** | P0 | Frontend | Higiene técnica, README, CI y accesibilidad base | **INTEGRADO** | PR #6 (`main`) |
| **VJ-03** | P0 | Frontend | Navegación principal: ShellRoute con 5 pestañas persistentes y mapa local M08 | **INTEGRADO** | PR #7 (`main`) |
| **VJ-04** | P1 | Ambos | Motor visual de semáforo demo por zonas (GPS + mapa): pantallas M06, M07 y M20 | **INTEGRADO** | `feature/vj-04-semaforo-demo` (`main`) |
| **VJ-05** | P1 | Frontend | Pantalla M10: aportar precio en 4 pasos demo por zona | **INTEGRADO** | `feature/vj-05-aportar-precio-demo` (`main`) |
| **VJ-06** | P1 | Ambos | Cierre del primer avance: walkthrough E2E, CI y documentación de sustentación | **INTEGRADO** | `feature/vj-06-cierre-primer-avance` (`main`) |
| **VJ-07** | P0 | Backend | Supabase: migración inicial, RLS, GRANT, seeds y ER | **INTEGRADO + NUBE** | PR #15 + `supabase db push` (`vjehsjqmwibmiqmxlsou`) |
| **VJ-08** | P0 | Ambos | Supabase Auth real, sesión, perfil y consentimientos (`delete_my_account`) | **INTEGRADO + NUBE** | PR #16 + PR #18 (`main`) |
| **VJ-09** | P0 | Frontend | Navegación por sesión, municipios reales y mapa oficial | **PARCIAL (`VJ-09a` HECHO)** | Router reactivo listo; pendiente adaptador remoto de municipios en UI |
| **VJ-10** | P0 | Backend | Función SQL de semáforo: única fuente de verdad (`calculate_price_verdict`) | **INTEGRADO + NUBE** | PR #18 (`23/23` pgTAP PASS) |
| **VJ-11** | P0 | Ambos | Reportes reales: aporte, límites, fuente y sincronización | **BACKEND HECHO EN NUBE / APP PENDIENTE** | Migración `20261029140000` (`18/18` pgTAP PASS); falta conectar UI M10 a `submit_price_report` |
| **VJ-12** | P1 | Ambos | Google Maps de precios, filtros y optimización geoespacial | **BACKEND HECHO EN NUBE / APP PENDIENTE** | Migración `20261030120000_price_map_geospatial_rpc.sql` (`15/15` pgTAP PASS); falta widget `GoogleMap` en app |
| **VJ-13** | P1 | Frontend | Captura de contratos: cámara, archivos y OCR local con ML Kit | **INTEGRADO** | PR #14 (`main`, verificado en `moto_g22`) |
| **VJ-14** | P1 | Ambos | Análisis de contratos con Gemini en Edge Function y cuota diaria SQL | **HECHO-VERIFICADO + NUBE** | App en PR #17 + Edge Function `analyze_contract` + migración `20261029150000` (`12/12` pgTAP PASS) |
| **VJ-15** | P2 | Ambos | Vista de ciudad de Valledupar: cultura verificada `es`/`en` y eventos | **BACKEND HECHO EN NUBE / APP PENDIENTE** | Migración `20261030130000` + semilla `08_city_content_valledupar.sql` (`16/16` pgTAP PASS); falta pantalla `M18` |
| **VJ-16** | P2 | Ambos | Registro de negocio en 4 pasos, bucket privado `business-media`, RLS y moderación | **BACKEND HECHO EN NUBE / APP PENDIENTE** | Migración `20261031100000` + semilla `09` (`24/24` pgTAP PASS); falta wizard `M19` en app |
| **VJ-17** | P2 | Ambos | Negocios: catálogo paginado, detalle y acciones externas seguras | **BACKEND HECHO EN NUBE / APP PENDIENTE** | Migración `20261031110000` + semilla `10` (`18/18` pgTAP PASS); falta conectar `M21`/`M09` a RPCs |
| **VJ-18** | P0 | Ambos | Correcciones cruzadas de seguridad, privacidad y confiabilidad | **BACKEND HECHO EN NUBE** | Migración `20261108220000` + `docs/seguridad-privacidad.md` + `docs/backend/guia-respaldo-restauracion.md` |
| **VJ-19** | P0 | Ambos | Suite de pruebas integrales y matriz RF → pruebas automatizadas | **BACKEND HECHO** | `supabase/tests/security_cross_audit.sql` (`16` aserciones) + `docs/pruebas/matriz-rf-casos.md` |
| **VJ-20** | P0 | Ambos | Entrega Android real: protocolo de firma release, SHA-1/256, OAuth y respaldo | **DOCUMENTADO (PROTOCOLO LISTO) / PENDIENTE FIRMA APK EN FRONTEND** | `docs/release-android.md` completo; pendiente aplicar `applicationId` final y firmar en `android/` |
| **VJ-21** | P0 | Ambos | Documentación final, manual de usuario, guion de 7 min y dictamen Go/No-Go | **HECHO-VERIFICADO** | `docs/arquitectura.md`, `docs/modelo-er.puml`, `docs/manual-usuario.md`, `docs/guia-demo.md`, `README.md` |

---

## 2. Resumen de Entregables de Backend Completados y Sincronizados en Nube (`VJ-07` a `VJ-19`)

### 2.1 Migraciones Aplicadas en Supabase Cloud (`vjehsjqmwibmiqmxlsou`)
Las **14 migraciones** en `supabase/migrations/` se encuentran 100% sincronizadas entre el repositorio local y el proyecto remoto en Supabase Cloud (`supabase migration list` verificado):

1. `20261027151907_extensions_and_geography.sql`: Extensiones `postgis` y `unaccent`; tablas `departments`, `municipalities`, `municipality_zones` e `interest_registrations`.
2. `20261027151910_profiles_and_consents.sql`: Tablas `profiles`, `admin_users`, `consents`, función `is_admin()` y trigger `handle_new_user()`.
3. `20261029100000_price_catalog.sql`: Tabla `price_categories` y `app_config`.
4. `20261029101000_price_reports_and_events.sql`: Tablas `price_reports`, `events` y `ai_usage`.
5. `20261029102000_businesses_and_content.sql`: Tablas `businesses`, `business_photos`, `business_dishes` y `city_content`.
6. `20261029120000_close_vj07_vj08_d11_and_account_deletion.sql`: Ratificación de `D11` (`resident`), control de columnas en `price_reports` y primera versión de `delete_my_account()`.
7. `20261029130000_price_verdict_rpc.sql` (`VJ-10`): Funciones `calculate_price_verdict` y `evaluate_price_verdict` (mediana por zona, ventana de 60 días, $N \ge 3$, umbrales `+15%`/`+40%`/`-40%` y modo evento).
8. `20261029140000_price_reports_quotas_privacy_and_rpc.sql` (`VJ-11`): Trigger `enforce_price_report_submission_rules`, redondeo GPS a 3 decimales ($\approx 110\text{ m}$), enfriamiento de 15 min, tope de 10 reportes/24h, `submit_price_report` y `moderate_price_report`.
9. `20261029150000_ai_usage_quota_rpc.sql` (`VJ-14`): Cuota diaria atómica en `America/Bogota` (`consume_ai_daily_quota`, `refund_ai_daily_quota`, `get_my_ai_quota_status`).
10. `20261030120000_price_map_geospatial_rpc.sql` (`VJ-12`): Coordenadas de centroide en `municipality_zones`, índice espacial y RPCs `get_municipality_zones`, `get_price_map_markers` (con filtro `ST_MakeEnvelope` y resumen estadístico por zona) y `resolve_municipality_zone_by_coords`.
11. `20261030130000_city_content_and_events_rpc.sql` (`VJ-15`): Enriquecimiento de `city_content` y `events`, atribución obligatoria de fuentes y RPCs `get_city_content`, `get_city_events_status` y `get_city_overview` con fallback automático `en` → `es`.
12. `20261031100000_business_registration_storage_and_moderation.sql` (`VJ-16`): Reglas de registro ciudadano en 4 pasos (`submit_business`), bucket privado `business-media` con validación de MIME real en `storage.objects.metadata`, moderación administrativa (`moderate_business`, `get_business_moderation_queue`) y detector de archivos huérfanos (`list_orphan_business_media`).
13. `20261031110000_business_catalog_detail_and_external_actions.sql` (`VJ-17`): RPCs `get_business_catalog` (paginado + búsqueda `unaccent` en negocio y platos), `get_business_detail`, `get_my_businesses` y constructores seguros RFC 3986 `build_business_whatsapp_url` y `build_business_maps_url`.
14. `20261108220000_security_reliability_cross_hardening.sql` (`VJ-18`): Revocación de `DEFAULT PRIVILEGES` en `public`/`private`, revocación de `EXECUTE PUBLIC` en funciones auxiliares, sanitización de etiquetas HTML en `price_reports`, bloqueo de automoderación en `moderate_price_report`, blindaje interno en `consume_ai_daily_quota`/`refund_ai_daily_quota` y actualización de `delete_my_account()` al protocolo transaccional de 5 fases.

---

## 3. Evaluación de Puertas de Calidad (`Gates G0` a `G6` — §10 del Plan Maestro)

| Gate | Nombre | Estado Actual | Sustento y Pendientes Transparentes |
|---|---|---|---|
| **G0** | Arranque limpio y línea base (`VJ-00`–`VJ-02`) | **APROBADO (GO)** | Compilación limpia, `flutter analyze` sin errores, 0 secretos en git (`gitleaks`), estructura de 3 capas y decisiones `D1`–`D15` documentadas. |
| **G1** | Primer avance navegable (`VJ-03`–`VJ-06`) | **APROBADO (GO)** | Shell de 5 pestañas persistentes, semáforo DEMO por zonas, aporte en 4 pasos DEMO, recorrido E2E automatizado (`first_milestone_walkthrough_test.dart`) y guía de 7 min. |
| **G2** | Backend operativo y seguro (`VJ-07`–`VJ-08`) | **APROBADO (GO)** | 16 tablas con RLS activa, `GRANT`s de mínimo privilegio, Auth real integrado en app (`PR #16`), consentimientos `v1.0` y `14/14` migraciones aplicadas en Supabase Cloud (`vjehsjqmwibmiqmxlsou`). |
| **G3** | Núcleo de precios de extremo a extremo (`VJ-10`–`VJ-12`) | **APROBADO EN BACKEND / PARCIAL EN APP** | **Backend 100% GO:** `calculate_price_verdict`, `submit_price_report` y `get_price_map_markers` probados con 56 aserciones pgTAP en PASS y desplegados en la nube. **Pendiente en Frontend:** conectar `PriceVerdictRepository`, `PriceContributionRepository` y el mapa `M08` a las RPCs reales. |
| **G4** | Núcleo de contratos de extremo a extremo (`VJ-13`–`VJ-14`) | **APROBADO (GO)** | OCR local con ML Kit verificado en dispositivo real (`moto_g22`, `PR #14`), UI de análisis y doble consentimiento integrados (`PR #17`), y Edge Function `analyze_contract` + cuota SQL (`5/día` con reembolso) verificadas con pgTAP y Deno. Solo resta conmutar el provider de `DemoContractAnalysisGateway` al cliente HTTP de `analyze_contract` en la build con `--dart-define`. |
| **G5** | Ciudad y negocios (`VJ-15`–`VJ-17`) | **APROBADO EN BACKEND / PENDIENTE EN APP** | **Backend 100% GO:** RPCs `get_city_overview`, `submit_business`, `moderate_business`, `get_business_catalog` y `get_business_detail` + bucket privado `business-media` desplegados y verificados con 58 aserciones pgTAP. **Pendiente en Frontend:** implementar las vistas/adaptadores reales de `M18`, `M19` y conectar `M21`/`M09`. |
| **G6** | Candidato a entrega final (`VJ-18`–`VJ-21`) | **GO EN BACKEND Y DOCUMENTACIÓN / CONDICIONAL EN RELEASE ANDROID** | **Backend y Documentación 100% GO:** endurecimiento cruzado `VJ-18`, suite `security_cross_audit.sql`, matriz `matriz-rf-casos.md`, protocolo `release-android.md`, manual de usuario y guion de 7 min completados. **Condición para Release Final:** que el responsable de Frontend conecte los adaptadores pendientes (`G3`/`G5`), aplique el `applicationId` definitivo (`co.viajusta.app`) y firme el APK release según `docs/release-android.md`. |

---

## 4. Dictamen Formal Go / No-Go (`VJ-21`)

### 4.1 Dictamen por Ámbito de Responsabilidad

1. **Ámbito Backend, Seguridad, Base de Datos y Documentación Técnica (`supabase/` y `docs/`):**
   - **DICTAMEN: `GO` (100% Completado, Auditado y Desplegado en Supabase Cloud).**
   - Las 14 migraciones están aplicadas en `vjehsjqmwibmiqmxlsou`.
   - Todas las invariantes de negocio, seguridad, privacidad (`RN-10`, Ley 1581 de 2012, ofuscación GPS, cuotas de reportes e IA, moderación de negocios y precios, anti-escalación y supresión en 5 fases) están respaldadas por **168 aserciones pgTAP** distribuidas en 9 suites y **6 bloques Deno**.
2. **Ámbito Integración Frontend y Empaquetado Release Android (`lib/` y `android/`):**
   - **DICTAMEN: `GO CONDICIONAL` (Apto para sustentación inmediata con Auth/Contratos + respaldo DEMO; requiere cierre de adaptadores UI de `VJ-11/12/15/16/17` y firma APK `VJ-20` por parte del equipo de Frontend para producción 100% conectada).**

### 4.2 Hoja de Ruta Inmediata Posterior a `VJ-21`
1. **Nutrición y curaduría de datos reales en la base de datos (`Supabase Cloud`):** Poblar muestras iniciales verificadas (`is_seed = true`, `is_demo = false`) para todas las categorías y zonas de Valledupar (`20001`), eventos reales y comercios aprobados verificados, de modo que el semáforo, la vista cultural y el directorio respondan con riqueza de datos reales desde el primer segundo.
2. **Coordinación con Frontend:** Entregar al compañero encargado de Frontend las firmas exactas documentadas en [`docs/contrato-datos-v1.md`](../contrato-datos-v1.md) y el checklist de [`docs/release-android.md`](../release-android.md) para el cableado final de providers y la generación del APK firmado.
