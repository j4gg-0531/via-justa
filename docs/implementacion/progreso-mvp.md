# Progreso, Control de Cambios y Dictamen Go/No-Go — Vía Justa MVP

**Última actualización:** 22 de noviembre de 2026 (Cierre `RF-06`, textos legales Ley 1581, limpieza Auth/Inicio y preparación `VJ-20` Android `co.viajusta.app`)  
**Rama actual:** `feature/cierre-rf06-legal-vj20` (partiendo de `main` en `336d080` tras integrar PRs #30–#38)  
**Repositorio remoto:** `https://github.com/j4gg-0531/via-justa.git`  
**Proyecto Supabase Remoto:** `via-justa` (`vjehsjqmwibmiqmxlsou`, PostgreSQL 17.11 — `21` archivos de migración en `supabase/migrations/`)  
**Entorno de ejecución:** Windows 10/11 x64, PowerShell 5.1, Flutter `3.47.7` (`stable`), Dart `3.13.5`, Supabase CLI `2.101.0`  
**Suites de pruebas automatizadas:**
- **Flutter (`test/`):** `364/364` pruebas unitarias, de widgets y E2E en PASS (`54` archivos, `0` errores en `flutter analyze`).
- **PostgreSQL pgTAP (`supabase/tests/`):** `12` archivos de suite en repositorio (`9` suites base con `168` aserciones documentadas + `business_direct_publication.sql`, `business_ratings.sql`, `business_transactional_update.sql` añadidos en PRs #30–#35).
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
| **VJ-08** | P0 | Ambos | Supabase Auth real, sesión, perfil y consentimientos (`delete_my_account`) | **INTEGRADO + VERIFICADO** | PR #16 + PR #18 (`main`) + conectado en `ProfilePage` / `AuthController` (`feature/cierre-rf06-legal-vj20`) |
| **VJ-09** | P0 | Frontend | Navegación por sesión, municipios reales y mapa oficial | **INTEGRADO** | PR #21 + PR #28 + PR #37 (`identidad-ilustrada-mapas-y-ciudades`) |
| **VJ-10** | P0 | Backend | Función SQL de semáforo: única fuente de verdad (`calculate_price_verdict`) | **INTEGRADO + NUBE** | PR #18 (`23/23` pgTAP PASS) |
| **VJ-11** | P0 | Ambos | Reportes reales: aporte, límites, fuente y sincronización | **INTEGRADO** | PR #28 + PR #38 (`feat/mapa-lugares-y-estimador-taxi`) |
| **VJ-12** | P1 | Ambos | Google Maps de precios, filtros, pines vectoriales y estimador de taxi | **INTEGRADO** | PR #22 + PR #28 + PR #38 (`feat/mapa-lugares-y-estimador-taxi`) |
| **VJ-13** | P1 | Frontend | Captura de contratos: cámara, archivos y OCR local con ML Kit | **INTEGRADO** | PR #14 (`main`, verificado en `moto_g22`) |
| **VJ-14** | P1 | Ambos | Análisis de contratos con Gemini en Edge Function y cuota diaria SQL | **INTEGRADO** | PR #17 + PR #20 + PR #28 |
| **VJ-15** | P2 | Ambos | Vista de ciudad de Valledupar: cultura verificada `es`/`en` y eventos | **BACKEND EN NUBE + IDENTIDAD VISUAL / CONEXIÓN `get_city_overview` DIFERIDA** | Backend en `20261030130000` (PR #23); ilustración visual en PR #37; vistas conectadas a RPC diferidas |
| **VJ-16** | P2 | Ambos | Registro de negocio en 4 pasos, bucket privado `business-media` y publicación | **INTEGRADO** | PR #24 + PR #30 (`codex/vj-16-publicacion-directa-negocios`) + PR #35 (`aviso-precios-zona`) |
| **VJ-17** | P2 | Ambos | Negocios: catálogo paginado, detalle, valoraciones y acciones externas seguras | **INTEGRADO** | PR #25 + PR #33 + PR #34 (`valoraciones-negocios`) |
| **VJ-18** | P0 | Ambos | Correcciones cruzadas de seguridad, privacidad, OWASP y `delete_my_account` | **INTEGRADO** | PR #26 + PR #32 (`auditoria-owasp-mobile-top10`) + `feature/cierre-rf06-legal-vj20` |
| **VJ-19** | P0 | Ambos | Suite de pruebas integrales y matriz RF → pruebas | **INTEGRADO** | `12` suites pgTAP + `364` pruebas en Flutter (`54` archivos) |
| **VJ-20** | P0 | Frontend | Entrega Android real: `applicationId` `co.viajusta.app`, firma release, APK | **CONFIGURADO EN GRADLE / PENDIENTE KEYSTORE LOCAL Y APK FINAL** | `android/app/build.gradle.kts`, `MainActivity.kt`, `AndroidManifest.xml`, `docs/release-android.md` |
| **VJ-21** | P0 | Ambos | Documentación final, sustentación y decisión Go/No-Go | **ACTUALIZADO** | `docs/arquitectura.md`, `docs/manual-usuario.md`, `docs/guia-demo.md`, `docs/seguridad-privacidad.md` |

---

## 2. Resumen de Entregables de Backend Completados y Sincronizados en Nube (`VJ-07` a `VJ-19`)

### 2.1 Migraciones Aplicadas en Supabase Cloud (`vjehsjqmwibmiqmxlsou`)
Las migraciones en `supabase/migrations/` se encuentran sincronizadas entre el repositorio local y el proyecto remoto en Supabase Cloud (`supabase db push`):

1. `20261027151907_extensions_and_geography.sql`: Extensiones `postgis` y `unaccent`; tablas `departments`, `municipalities`, `municipality_zones` e `interest_registrations`.
2. `20261027151910_profiles_and_consents.sql`: Tablas `profiles`, `admin_users`, `consents`, función `is_admin()` y trigger `handle_new_user()`.
3. `20261029100000_price_catalog.sql`: Tabla `price_categories` y `app_config`.
4. `20261029101000_price_reports_and_events.sql`: Tablas `price_reports`, `events` y `ai_usage`.
5. `20261029102000_businesses_and_content.sql`: Tablas `businesses`, `business_photos`, `business_dishes` y `city_content`.
6. `20261029120000_close_vj07_vj08_d11_and_account_deletion.sql`: Ratificación de `D11` (`resident`), control de columnas en `price_reports` y primera versión de `delete_my_account()`.
7. `20261029130000_price_verdict_rpc.sql` (`VJ-10`): Funciones `calculate_price_verdict` y `evaluate_price_verdict` (mediana por zona, ventana de 60 días, $N \ge 3$, umbrales 15%/40% y eventos).
8. `20261029140000_price_reports_quotas_privacy_and_rpc.sql` (`VJ-11`): Trigger `enforce_price_report_submission_rules`, redondeo GPS a 3 decimales ($\approx 110\text{ m}$), cuota de 5 reportes/día y RPC `submit_price_report`.
9. `20261029150000_ai_usage_quota_rpc.sql` (`VJ-14`): Cuota diaria atómica en `America/Bogota` (`consume_ai_daily_quota`, `refund_ai_daily_quota`, `get_my_ai_quota_status`).
10. `20261030120000_price_map_geospatial_rpc.sql` (`VJ-12`): Coordenadas de centroide en `municipality_zones`, índice espacial y RPCs `get_municipality_zones`, `get_price_map_markers`.
11. `20261030130000_city_content_and_events_rpc.sql` (`VJ-15`): Enriquecimiento de `city_content` y `events`, atribución obligatoria de fuentes y RPCs `get_city_overview`, `get_city_events`.
12. `20261031100000_business_registration_storage_and_moderation.sql` (`VJ-16`): Reglas de registro ciudadano en 4 pasos (`submit_business`), bucket privado `business-media`, RLS y moderación.
13. `20261031110000_business_catalog_detail_and_external_actions.sql` (`VJ-17`): RPCs `get_business_catalog` (paginado + búsqueda `unaccent` en negocio y platos) y `get_business_detail`.
14. `20261108220000_security_reliability_cross_hardening.sql` (`VJ-18`): Revocación de `DEFAULT PRIVILEGES` en `public`/`private`, revocación de `EXECUTE PUBLIC` en funciones auxiliares, sanitización de etiquetas HTML en `price_reports`, bloqueo de automoderación en `moderate_price_report`, blindaje interno en `consume_ai_daily_quota`/`refund_ai_daily_quota` y actualización de `delete_my_account()` al protocolo transaccional de 5 fases.
15. `20261101100000_taxi_distance_ranges_and_verdict.sql` (Rediseño Analizar): Clasificación de trayectos de taxi en SQL por rangos geodésicos (`0_2_km`, `2_5_km`, `gt_5_km`) y sobrecarga de `calculate_price_verdict` y `submit_price_report`.

---

## 3. Evaluación de Puertas de Calidad (`Gates G0` a `G6` — §10 del Plan Maestro)

| Gate | Nombre | Estado Actual | Sustento y Pendientes Transparentes |
|---|---|---|---|
| **G0** | Arranque limpio y línea base (`VJ-00`–`VJ-02`) | **APROBADO (GO)** | Compilación limpia, `flutter analyze` sin errores, 0 secretos en git (`gitleaks`), estructura de 3 capas y decisiones `D1`–`D24` documentadas. |
| **G1** | Primer avance navegable (`VJ-03`–`VJ-06`) | **APROBADO (GO)** | Shell de 5 pestañas persistentes, semáforo DEMO por zonas, aporte en 4 pasos DEMO, recorrido E2E automatizado (`first_milestone_walkthrough_test.dart`) y guía de 7 min. |
| **G2** | Backend operativo y seguro (`VJ-07`–`VJ-08`) | **APROBADO (GO)** | 16 tablas con RLS activa, `GRANT`s de mínimo privilegio, Auth real integrado en app (`PR #16`), consentimientos `v1.0` y `14/14` migraciones aplicadas en Supabase Cloud (`vjehsjqmwibmiqmxlsou`). |
| **G3** | Núcleo de precios de extremo a extremo (`VJ-10`–`VJ-12`) | **APROBADO (GO)** | **Backend 100% GO:** `calculate_price_verdict`, `submit_price_report` y `get_price_map_markers` con cálculo de taxi por distancias en SQL. **Frontend 100% GO:** Conectado a Supabase real sin fallback a datos falsos, selección de puntos en Google Maps / GPS (`showMapPointPickerSheet`) y semáforo rediseñado con umbrales y sugerencia determinista. |
| **G4** | Núcleo de contratos de extremo a extremo (`VJ-13`–`VJ-14`) | **APROBADO (GO)** | OCR local con ML Kit verificado en dispositivo real (`moto_g22`, `PR #14`), UI limpia sin cajas falsas ni muestras sintéticas fijas, subida de archivos JPG/PNG/TXT hasta 10 MB, aviso de PDF próximamente y conexión con Edge Function `analyze_contract`. |
| **G5** | Ciudad y negocios (`VJ-15`–`VJ-17`) | **NEGOCIOS INTEGRADOS / `VJ-15` RPC DIFERIDA** | **Negocios 100% integrados:** registro en 4 pasos, publicación directa, directorio paginado, ficha con valoraciones y aviso de precios por zona (PRs #30, #33, #34, #35). **Ciudad (`VJ-15`):** backend `get_city_overview` y semillas listos; identidad visual ilustrada integrada en PR #37; conexión de la vista cultural/eventos a RPC diferida por decisión de alcance. |
| **G6** | Candidato a entrega final (`VJ-18`–`VJ-21`) | **GO EN APP Y BACKEND / PENDIENTE FIRMA APK LOCAL** | Auditoría OWASP (PR #32), eliminación de cuenta `delete_my_account` en `ProfilePage`, textos legales `Ley 1581`, limpieza de botones provisionales, `applicationId` definitivo `co.viajusta.app` y lectura de `key.properties` en Gradle listos (`364/364` pruebas Flutter). **Único paso operativo pendiente:** crear keystore `.jks` local, actualizar `MAPS_API_KEY` en GCP con el `SHA-1` release y firmar/probar el APK final en teléfono físico según `docs/release-android.md`. |

---

## 4. Dictamen Formal Go / No-Go (`VJ-21`)

### 4.1 Dictamen por Ámbito de Responsabilidad

1. **Ámbito Backend, Seguridad, Base de Datos y Documentación Técnica (`supabase/` y `docs/`):**
   - **DICTAMEN: `GO` (Completado, Auditado y Sincronizado hasta `21` migraciones SQL).**
   - Todas las invariantes de negocio, seguridad, privacidad (`RN-10`, Ley 1581 de 2012, ofuscación GPS, cuotas de reportes e IA, publicación/valoraciones de negocios, anti-escalación y supresión en 5 fases) están respaldadas por **12 archivos de suite pgTAP** en `supabase/tests/` y **6 bloques Deno**.
2. **Ámbito Aplicación Móvil y Empaquetado Release Android (`lib/` y `android/`):**
   - **DICTAMEN: `GO` EN CÓDIGO (`364/364` pruebas PASS) / PENDIENTE FIRMA APK EN EQUIPO LOCAL (`VJ-20`).**
   - Auth, Mapa Colombia con identidad visual, Precios/Taxi con estimador, Contratos OCR+Gemini, Directorio/Registro/Valoraciones de Negocios, `delete_my_account` y textos legales Ley 1581 están integrados; solo resta generar el `.jks` local, autorizar el `SHA-1` release en Google Cloud Console y emitir el `app-release.apk` firmado (`VJ-15` RPC cultural queda diferida explícitamente).

### 4.2 Hoja de Ruta Inmediata Posterior
1. **Empaquetado Release (`VJ-20`):** Generar el keystore `.jks` fuera del repo, crear `android/key.properties`, autorizar `co.viajusta.app` + `SHA-1` release en Google Cloud Console y validar `app-release.apk` en dispositivo físico (`docs/release-android.md`).
2. **Cultura real (`VJ-15`, cuando se retome):** Conectar `get_city_overview` y `get_city_events_status` en las vistas de ciudad e inicio.
