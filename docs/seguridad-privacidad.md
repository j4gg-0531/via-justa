# Política de Seguridad, Autenticación y Privacidad de Datos — Vía Justa MVP

## 1. Principios Rectores y Clasificación de Controles

Los controles de seguridad y privacidad se clasifican rigurosamente según su estado real en el ciclo de desarrollo:
- **[IMPLEMENTADO]:** Funcionalidad escrita, probada y presente en el repositorio y en Supabase Cloud.
- **[PROPUESTO]:** Especificación técnica acordada pendiente de implementación o migración en base de datos.
- **[PENDIENTE DE PRUEBA]:** Control dependiente de validación en entorno de integración o dispositivo físico real.

### Principios Fundamentales
1. **Defensa en Profundidad:** La seguridad no recae exclusivamente en la aplicación móvil; las reglas de autorización residen en la base de datos (PostgreSQL Row Level Security, triggers, funciones con `search_path` inmutable y permisos `GRANT` por columna) y en las Edge Functions **[IMPLEMENTADO]**.
2. **Principio de Mínimo Privilegio:** La aplicación Flutter utiliza exclusivamente la clave anónima pública (`anon_key`) de Supabase. **La clave de servicio (`service_role_key`) nunca se empaqueta, referencia ni transmite al cliente móvil** **[IMPLEMENTADO]**.
3. **No Retención de Datos Contractuales (RN-10):** Los contratos analizados por el motor de IA no se almacenan en bases de datos ni en discos persistentes; el texto viaja en memoria por canal seguro HTTPS y se descarta inmediatamente tras emitir la respuesta estructurada de Gemini **[IMPLEMENTADO EN VJ-14]**.
4. **Cumplimiento Normativo Colombiano:** Tratamiento de datos personales enmarcado en el Régimen General de Protección de Datos Personales (Ley Estatutaria 1581 de 2012 y Decreto 1377 de 2013) **[IMPLEMENTADO]**.

---

## 2. Ciclo de Vida de Autenticación y Sesión

### 2.1 Proveedores Soportados
- **Correo y Contraseña:** Registro y login validado localmente en `domain/auth_validators.dart` y conectado a Supabase Auth **[IMPLEMENTADO EN VJ-08]**.
- **Google OAuth:** Botón en interfaz **[IMPLEMENTADO EN DEMO]**; flujo federado real vía Supabase Auth **[PROPUESTO]**.

### 2.2 Registro y Política de Contraseñas
- **Validación Local:** La contraseña debe contener mínimo 8 caracteres (validado por `auth_validators.dart`) **[IMPLEMENTADO]**.
- **Verificación de Correo:**
  - *Entorno de Desarrollo / Pruebas:* Auto-confirmación habilitada para facilitar la evaluación sin dependencias SMTP externas **[IMPLEMENTADO]**.
  - *Entorno de Producción:* Envío de enlace de verificación por correo electrónico. El usuario no podrá emitir reportes de precios ni registrar negocios hasta confirmar su cuenta **[PROPUESTO]**.

### 2.3 Persistencia y Renovación de Sesión
- **Mecanismo de Almacenamiento:** Por defecto, el cliente de Supabase para Flutter persiste los tokens de sesión en el almacenamiento local estándar provisto por el sistema operativo (`SharedPreferences` en Android) **[IMPLEMENTADO]**.
- **Cifrado en Reposo:** La delegación de tokens al almacén seguro nativo (`EncryptedSharedPreferences` / Android Keystore) requiere la configuración explícita de un adaptador con `flutter_secure_storage`, clasificado actualmente como **[PROPUESTO / PENDIENTE DE PRUEBA]**.
- **Canal de Comunicación:** Las peticiones de red utilizan HTTPS estándar, negociando la versión de TLS más alta admitida conjuntamente por los servidores de Supabase/Google y la pila de red de Android (típicamente TLS 1.2 o TLS 1.3) **[PENDIENTE DE PRUEBA EN DISPOSITIVO]**.

### 2.4 Cierre de Sesión Seguro (Logout)
- Al invocar `logout()`, el cliente invalida los tokens en el servidor de Supabase, limpia los proveedores de Riverpod en memoria (`userNameProvider`, `profileTypeProvider`, `selectedMunicipalityProvider`, etc.) y redirige mediante `context.go(AppRoutes.welcome)` **[IMPLEMENTADO EN VJ-08]**.
- El historial de navegación de `go_router` se reinicia para impedir que el botón "Atrás" de Android recupere vistas privadas anteriores **[IMPLEMENTADO]**.

### 2.5 Protocolo Transaccional de Eliminación de Cuenta y Minimización de Datos (RF-06 / VJ-18)
- El usuario puede solicitar la eliminación definitiva de su cuenta desde la pantalla de Perfil invocando `public.delete_my_account()` **[IMPLEMENTADO EN VJ-08 Y ENDURECIDO EN VJ-18]**.
- **Orden de Ejecución Obligatorio (Pre-supresión antes de eliminar `auth.users`):**
  - La clave foránea `ON DELETE SET NULL` sobre `price_reports.user_id` solo opera al suprimirse el registro de autenticación. Si se elimina primero en `auth.users`, los reportes quedan huérfanos con `user_id = NULL` y se pierde la capacidad de saber qué reportes pertenecían a ese usuario para depurar información contextual o privada.
  - La función transaccional `public.delete_my_account()` (`supabase/migrations/20261108220000_security_reliability_cross_hardening.sql`) serializa ejecuciones concurrentes con `pg_advisory_xact_lock` y ejecuta 5 fases estrictas:
    1. **Fase 1 (Saneamiento previo de reportes contextuales):** Con el usuario aún identificable por `user_id = auth.uid()`, se depuran `source_note = NULL`, `place_name = NULL` y se nulifican las coordenadas GPS (`location = NULL`), preservando únicamente `{municipality_code, zone_id, category_id, amount_cop, created_at}` para el cálculo estadístico de la mediana.
    2. **Fase 2 (Desvinculación de auditoría de moderación):** Se limpia `reviewed_by = NULL` en cualquier fila de `public.businesses` revisada por el usuario.
    3. **Fase 3 (Eliminación en cascada de negocios propios):** Se eliminan los registros de `public.businesses` donde `owner_id = auth.uid()`, disparando `ON DELETE CASCADE` sobre `public.business_photos` y `public.business_dishes`. Los archivos en `storage.objects` quedan inmediatamente identificados como `'business_deleted'` por `public.list_orphan_business_media` para purga por API de Storage.
    4. **Fase 4 (Supresión de datos directos y cuotas):** Se eliminan explícitamente las filas del usuario en `public.ai_usage`, `public.consents`, `public.interest_registrations` y `public.admin_users`.
    5. **Fase 5 (Baja definitiva en Supabase Auth):** Se elimina el usuario en `auth.users`. La eliminación en cascada suprime `public.profiles` y fija `public.price_reports.user_id = NULL`.
- **Evaluación de Riesgo de Reidentificación:**
  - No se declara "anonimización irreversible absoluta" sin una verificación formal de reidentificación (análisis de singularidad espacio-temporal y $k$-anonimato bajo directrices de la SIC). El modelo se define como minimización rigurosa de datos y disociación seudónima reforzada **[IMPLEMENTADO]**.

---

## 3. Modelo de Privacidad y Consentimiento (Habeas Data)

### 3.1 Consentimiento Explícito y Versionado
- Antes de completar el registro o continuar con Google, el usuario debe aceptar expresamente los Términos de Servicio y la Política de Privacidad **[IMPLEMENTADO]**.
- Se almacena un registro inmutable en la tabla `consents` con `user_id`, `doc_type`, `version` y `accepted_at` **[IMPLEMENTADO]**.
- Si los términos se actualizan a una versión posterior (ej. `v2.0`), la aplicación presentará una pantalla de re-consentimiento obligatorio antes de permitir nuevas acciones **[PROPUESTO]**.

### 3.2 Privacidad Geoespacial de Precios
- Los reportes de precios en `price_reports` permiten asociar una ubicación GPS (`location`).
- **Ofuscación de Privacidad en Servidor:** Para evitar la trazabilidad de la rutina o domicilio del ciudadano, el trigger `public.enforce_price_report_submission_rules()` redondea automáticamente cualquier coordenada `location` a **3 decimales** ($\approx 110\text{ m}$ de resolución a nivel de cuadra/sector comercial) antes de persistirla, sin almacenar jamás coordenadas exactas de domicilios ni identificadores de hardware **[IMPLEMENTADO EN VJ-11]**.

---

## 4. Matriz de Autorización y Políticas RLS (Row Level Security)

Las **16 tablas** del esquema `public` tienen RLS activado de forma obligatoria (`ALTER TABLE <tabla> ENABLE ROW LEVEL SECURITY;`), verificado automáticamente en `supabase/tests/security_cross_audit.sql` **[IMPLEMENTADO]**.

| Tabla / Bucket | Operación | Rol Permitido | Condición de Política RLS / Trigger | Estado |
|---|---|---|---|---|
| `profiles` | SELECT | `authenticated` | `id = auth.uid()` (lectura privada de perfil propio) | **[IMPLEMENTADO]** |
| `profiles` | UPDATE | `authenticated` | `id = auth.uid()` + GRANT restringido a `(display_name, origin_country, current_municipality_code, language, profile_type)` | **[IMPLEMENTADO EN VJ-07/08]** |
| `admin_users` | ALL | `service_role` | Sin políticas para anon/authenticated; evaluada por `is_admin()` | **[IMPLEMENTADO]** |
| `consents` | SELECT / INSERT | `authenticated` | `auth.uid() = user_id` (inmutable: sin UPDATE ni DELETE para clientes) | **[IMPLEMENTADO]** |
| `departments` / `municipalities` / `municipality_zones` / `price_categories` / `official_tariffs` | SELECT | `anon`, `authenticated` | `true` (catálogos oficiales de solo lectura pública; `0` permisos de escritura) | **[IMPLEMENTADO]** |
| `price_reports` | SELECT | `anon`, `authenticated` | `is_hidden = false AND is_demo = false` (o propios `user_id = auth.uid()`) | **[IMPLEMENTADO]** |
| `price_reports` | INSERT | `authenticated` | `auth.uid() = user_id` + trigger de cuota diaria (10/24h), anti-duplicado (15m), limpieza HTML y ofuscación GPS | **[IMPLEMENTADO EN VJ-11/18]** |
| `price_reports` | UPDATE / DELETE | `authenticated` | `auth.uid() = user_id AND created_at > now() - INTERVAL '24 hours'` (sin alterar metadatos ni banderas) | **[IMPLEMENTADO EN VJ-11]** |
| `businesses` | SELECT | `anon`, `authenticated` | `(status = 'approved' AND is_demo = false)` o para autenticados `owner_id = auth.uid() OR public.is_admin()` | **[IMPLEMENTADO EN VJ-16]** |
| `businesses` | INSERT | `authenticated` | `owner_id = auth.uid() AND status = 'pending'` (fijado por trigger `private.enforce_business_rules()`, con consentimiento de WhatsApp y de publicación, cupos e idempotencia `client_request_id`) | **[IMPLEMENTADO EN VJ-16]** |
| `businesses` | UPDATE / DELETE | `authenticated` | `owner_id = auth.uid()` (sin GRANT sobre `status`/`owner_id`; toda edición de contenido devuelve el registro a `pending` para re-moderación) | **[IMPLEMENTADO EN VJ-16]** |
| `business_photos` | SELECT / WRITE | `anon`, `authenticated` | Lectura pública solo si el negocio está `approved`; escritura exclusiva del dueño verificando MIME real (`image/jpeg`, `image/png`, `image/webp`), tamaño $\le 5\text{ MiB}$ y ruta `{owner_id}/{business_id}/...` en `storage.objects` | **[IMPLEMENTADO EN VJ-16]** |
| `business_dishes` | SELECT / WRITE | `anon`, `authenticated` | Lectura pública solo si el negocio está `approved`; máximo 5 platos destacados (`sort_order 0..4`) administrados por el dueño | **[IMPLEMENTADO EN VJ-16]** |
| `storage.objects` (`business-media`) | SELECT / WRITE | `anon`, `authenticated` | Bucket privado (`public = false`, `5 MiB`). Subida máxima de 5 imágenes por negocio bajo `{auth.uid()}/{business_id}/...`; fotos de negocios `pending`/`rejected` invisibles al público | **[IMPLEMENTADO EN VJ-16]** |
| `city_content` / `events` | SELECT | `anon`, `authenticated` | `true` + RPCs `get_city_content`, `get_city_events_status` y `get_city_overview` con fallback `en -> es` y licencia obligatoria de imágenes | **[IMPLEMENTADO EN VJ-15]** |
| `app_config` | SELECT | `authenticated` | `true` (solo lectura de parámetros operativos; escritura exclusiva de `service_role`) | **[IMPLEMENTADO]** |
| `ai_usage` | ALL | `service_role` | Exclusivo de Edge Function y RPCs atómicas `consume_ai_daily_quota` / `refund_ai_daily_quota` con validación interna `private.is_privileged_caller()` | **[IMPLEMENTADO EN VJ-14/18]** |
| `interest_registrations` | SELECT / INSERT | `authenticated` | `auth.uid() = user_id` | **[IMPLEMENTADO]** |

### 4.1 Separación Administrativa y Prevención de Escalada de Privilegios
- Siguiendo la arquitectura implementada en `admin_users`, **los usuarios no poseen columna de rol en `profiles`** **[IMPLEMENTADO]**.
- La pertenencia a `admin_users` se administra directamente en el servidor sin políticas RLS públicas y es evaluada mediante la función segura `public.is_admin()` **[IMPLEMENTADO]**.
- La moderación de negocios (`public.moderate_business`) y de reportes de precios (`public.moderate_price_report`) exige `public.is_admin()` o ejecución privilegiada (`private.is_privileged_caller()`), bloqueando la auto-revisión (`[MODERATION_SELF_REVIEW]`) **[IMPLEMENTADO EN VJ-16/18]**.
- Además, `private.is_privileged_caller()` evalúa `current_setting('role', true)` en lugar de `current_user`, impidiendo que funciones `SECURITY DEFINER` confundan una llamada de un usuario autenticado con una operación administrativa de consola **[IMPLEMENTADO EN VJ-16/18]**.
- El 100 % de las funciones en `public` y `private` tienen `search_path` explícito e inmutable y `REVOKE ALL FROM PUBLIC`, y ambos esquemas tienen `ALTER DEFAULT PRIVILEGES` restrictivos **[IMPLEMENTADO EN VJ-18]**.

---

## 5. Seguridad en Integraciones Externas

### 5.1 Google Maps API Key
- La clave de Google Maps se inyecta en tiempo de compilación desde `android/local.properties` (ignorado en Git) hacia el placeholder `${MAPS_API_KEY}` de `AndroidManifest.xml` **[IMPLEMENTADO EN VJ-12]**.
- **Mitigación complementaria en Google Cloud Console:**
  1. Restricción por nombre de paquete (`applicationId`) y huella digital SHA-1 (debug y release).
  2. Restricción por APIs estrictamente requeridas (*Maps SDK for Android*).
  3. Alertas de presupuesto diarias en GCP para evitar sobrecostos por uso anómalo.

### 5.2 Edge Function de Gemini y Protección contra Prompt Injection
- El cliente móvil nunca se comunica directamente con la API de Google Gemini **[IMPLEMENTADO]**.
- La llamada pasa a través de la Edge Function `analyze_contract` (`supabase/functions/analyze_contract/index.ts`, con `verify_jwt = true` en `supabase/config.toml`) **[IMPLEMENTADO EN VJ-14]**.
- La Edge Function aplica:
  1. Verificación del JWT de sesión del usuario (`auth.getUser(jwt)`).
  2. Reserva atómica de cuota diaria en `ai_usage` mediante `public.consume_ai_daily_quota` (máximo 5 llamadas/día por usuario en zona `America/Bogota`, con reintegro automático `public.refund_ai_daily_quota` si falla el proveedor externo).
  3. Sanitización del texto de entrada (entre 20 y 15.000 caracteres, cuerpo $\le 128\text{ KB}$) y limpieza de HTML/scripts en la salida.
  4. Instrucción de sistema defensiva que delimita el contrato como `<untrusted_contract_document>` y exige referencias legales estrictamente verificables (`Ley 820 de 2003`, `Código Civil`, `Código de Comercio`, `Ley 1480 de 2011`, `Ley 1581 de 2012`) o `null`.

### 5.3 Permisos de ML Kit y Procesamiento Local de Contratos (VJ-13 / RN-10)
- **Permisos inyectados en AndroidManifest:** La integración de `google_mlkit_text_recognition` y sus dependencias (`com.google.android.gms:play-services-mlkit-text-recognition-common`) inyectan automáticamente en el manifiesto fusionado los permisos `android.permission.INTERNET` y `android.permission.ACCESS_NETWORK_STATE`.
- **Diagnóstico y advertencia de privacidad:** Aunque el reconocimiento óptico de caracteres (OCR) con el modelo latino opera localmente en el dispositivo sin enviar la imagen del contrato a servidores de Google, **queda PENDIENTE DE VERIFICAR en la documentación oficial de ML Kit** si la biblioteca transmite telemetría, eventos de diagnóstico o estadísticas de uso anónimas a Google.
- **Consentimiento propio en la aplicación:** Para cumplir RN-10 sin invocar permisos intrusivos del sistema operativo (no se solicita el permiso `CAMERA` ni se utiliza `permission_handler`), la aplicación presenta un diálogo modal previo de consentimiento informado antes de delegar la captura a la cámara del sistema o abrir el selector de archivos, garantizando transparencia sobre el procesamiento on-device y el borrado de archivos temporales en bloques `finally`.

### 5.4 Flujo de Datos y Salida del Dispositivo en el Análisis con IA (VJ-14)
- **Salida explícita del texto del dispositivo:** El análisis de contratos de VJ-14 transmite el texto extraído hacia la Edge Function de Supabase para su evaluación por Google Gemini, sin persistirlo jamás en disco ni base de datos.
- **Restricción de Tier Gratuito y uso exclusivo de contratos sintéticos en pruebas:** En etapa académica/evaluación se exige y advierte explícitamente el uso exclusivo de contratos sintéticos de muestra o textos desprovistos de datos personales reales.
- **Segundo consentimiento informado específico:** Previo a cualquier transmisión de texto hacia la Edge Function, la aplicación exige la confirmación expresa de un diálogo de consentimiento independiente del de OCR.

---

## 6. Matriz Amenaza → Mitigación → Prueba Verificable (VJ-18)

| ID | Amenaza Identificada | Mitigación Implementada en Servidor / App | Prueba Automatizada Verificable | Estado |
|---|---|---|---|---|
| **T-01** | **Escalación de privilegios a administrador** desde el cliente móvil modificando `profiles` o `admin_users` | `profiles` carece de columna `role`; `admin_users` tiene `REVOKE ALL` para `anon` y `authenticated`; `public.is_admin()` es de solo lectura | `supabase/tests/rls.sql` (Tests 6–8) y `supabase/tests/security_cross_audit.sql` (Tests 2, 7) | **[IMPLEMENTADO - PASS]** |
| **T-02** | **Suplantación de identidad (`user_id` / `owner_id`)** al insertar reportes de precio o negocios | RLS `WITH CHECK` + triggers `enforce_price_report_submission_rules()` y `private.enforce_business_rules()` fuerzan `auth.uid()` y rechazan IDs ajenos con `42501` | `supabase/tests/price_reports_rls.sql` (Test 3) y `supabase/tests/business_registration.sql` (Test 2) | **[IMPLEMENTADO - PASS]** |
| **T-03** | **Auto-aprobación de negocios o manipulación de banderas** (`status = 'approved'`, `is_seed = true`, `is_hidden = true`, `is_demo = true`) | `GRANT INSERT/UPDATE` por columna excluye campos de moderación; triggers fuerzan `status = 'pending'`, `is_seed = false`, `is_hidden = false` y devuelven a `pending` tras cualquier edición del dueño | `supabase/tests/business_registration.sql` (Tests 1, 13, 14) y `supabase/tests/price_reports_rls.sql` (Tests 4, 14) | **[IMPLEMENTADO - PASS]** |
| **T-04** | **Bypass de `SECURITY DEFINER` o inyección por `search_path`** en funciones SQL | 100 % de funciones en `public` y `private` declaran `SET search_path` explícito e inmutable; `private.is_privileged_caller()` evalúa `current_setting('role', true)` en lugar de `current_user` | `supabase/tests/security_cross_audit.sql` (Tests 3, 4) y `supabase/tests/business_registration.sql` (Test 23) | **[IMPLEMENTADO - PASS]** |
| **T-05** | **Fuga cruzada de datos privados entre usuarios (Usuario B lee/edita a Usuario A)** o exposición de negocios `pending` al público | Políticas RLS estrictas por `auth.uid()`; negocios no aprobados ocultos en tabla, catálogo, detalle y Storage | `supabase/tests/rls.sql` (Tests 2–5), `supabase/tests/business_catalog_rpc.sql` (Tests 2, 10) y `supabase/tests/security_cross_audit.sql` (Test 9) | **[IMPLEMENTADO - PASS]** |
| **T-06** | **Subida de malware / PDF disfrazado de imagen o acceso a fotos de negocios no aprobados** en Storage | Bucket `business-media` privado (`public = false`, máx. `5 MiB`, máx. 5 fotos/negocio); trigger `private.enforce_business_photo_rules()` valida en servidor el MIME real de `storage.objects` contra la extensión | `supabase/tests/business_registration.sql` (Tests 10, 11, 12, 16) | **[IMPLEMENTADO - PASS]** |
| **T-07** | **Rastreo de domicilio exacto del ciudadano** mediante coordenadas GPS en reportes de precio | Trigger `enforce_price_report_submission_rules()` trunca/redondea toda coordenada `location` a 3 decimales ($\approx 110\text{ m}$) antes de guardar en PostGIS | `supabase/tests/price_reports_rls.sql` (Test 6) | **[IMPLEMENTADO - PASS]** |
| **T-08** | **Prompt Injection, alucinación de leyes inexistentes o XSS** en el análisis de contratos con Gemini | Delimitación `<untrusted_contract_document>`, neutralización de etiquetas de cierre, filtro `sanitizeLegalReference()` (anula leyes no verificadas a `null`) y limpieza de `<script>`/HTML | `supabase/functions/analyze_contract/contract_analyzer_test.ts` (Tests 2, 3, 4) | **[IMPLEMENTADO - PASS]** |
| **T-09** | **Agotamiento de presupuesto / abuso de API de IA o spam de reportes y negocios** | Reserva atómica con `pg_advisory_xact_lock`: IA máx. 5/día (`America/Bogota`) con reintegro en fallo `502`/`504`; precios máx. 10/24h + cooldown 15 min; negocios máx. 3/24h y 5 activos + idempotencia `client_request_id` | `supabase/tests/ai_usage_quota.sql` (13 tests), `supabase/tests/price_reports_rls.sql` (Tests 8–10), `supabase/tests/business_registration.sql` (Tests 8, 9) | **[IMPLEMENTADO - PASS]** |
| **T-10** | **Persistencia residual de PII o bloqueo por FKs al eliminar la cuenta (`RF-06` / Ley 1581)** | `public.delete_my_account()` sanea primero `price_reports` (`place_name`, `source_note`, `location` a `NULL`), desvincula `reviewed_by`, borra negocios/fotos/platos/cuotas/consentimientos/intereses y suprime `auth.users` | `supabase/tests/security_cross_audit.sql` (Tests 11–16) | **[IMPLEMENTADO - PASS]** |
| **T-11** | **Auto-moderación administrativa** (un admin aprueba su propio negocio o restaura su propio reporte oculto) | Guardas explícitas `[MODERATION_SELF_REVIEW]` en `public.moderate_business` y `public.moderate_price_report` | `supabase/tests/business_registration.sql` (Test 18) y `supabase/tests/security_cross_audit.sql` (Test 10) | **[IMPLEMENTADO - PASS]** |

---

## 7. Resumen Consolidado de Cuotas Operativas y Control de Costos (VJ-18)

Todos los límites operativos residen en `public.app_config` y pueden ajustarse en caliente sin recompilar la aplicación móvil:

| Recurso Protegido | Clave en `app_config` | Límite Servidor | Mecanismo de Concurrencia / Fallo |
|---|---|---|---|
| **Análisis de contratos con Gemini (`analyze_contract`)** | `price_verdict_rules.daily_ai_limit_per_user` | **5 análisis / día** por usuario (`America/Bogota`) | `pg_advisory_xact_lock` en `consume_ai_daily_quota`; reintegro automático con `refund_ai_daily_quota` si Gemini devuelve `502`/`503`/`504` |
| **Tamaño de texto de contrato enviado a IA** | `MAX_CONTRACT_TEXT_LENGTH` (Edge Function) | **20 a 15.000 caracteres** (payload HTTP $\le 128\text{ KB}$) | Validación previa al consumo de cuota (`400 INVALID_INPUT_EMPTY` / `413 TEXT_TOO_LONG`) |
| **Aportes ciudadanos de precios (`price_reports`)** | `price_verdict_rules.daily_report_limit_per_user` y `duplicate_cooldown_minutes` | **10 reportes reales / 24 h** y **15 min** anti-duplicado | `pg_advisory_xact_lock` por usuario en `enforce_price_report_submission_rules()` |
| **Registro de negocios (`businesses`)** | `business_registration_rules` | **3 envíos / 24 h** y máx. **5 negocios activos/pendientes** por dueño | `pg_advisory_xact_lock` + idempotencia por `(owner_id, client_request_id)` |
| **Multimedia de negocios (`business-media`)** | `business_registration_rules` + `storage.buckets` | Máx. **5 fotos / negocio**, **5 MiB / foto**, solo `JPEG`/`PNG`/`WebP` | Política RLS `private.can_write_business_media` + trigger `private.enforce_business_photo_rules` + auditoría de huérfanos `public.list_orphan_business_media` |
| **Consultas de mapa y catálogo (`get_municipality_map_items`, `get_business_catalog`)** | Límite en RPC | Mapa acotado a **$\le 200$ pines** por viewport; catálogo paginado **$\le 50$ ítems/página** | Cláusula `least(greatest(...))` en servidor; el listado nunca descarga binarios de fotos completas |
