# Contrato de Datos v1.0 — Vía Justa MVP

> **Estado del documento:** RATIFICADO E IMPLEMENTADO EN MIGRACIONES (`0001` a `0007`).
> **Fecha:** 29 de octubre de 2026.
> **Importante:** Este documento representa el acuerdo de interfaz formal entre Frontend (Flutter) y Backend (Supabase/PostgreSQL), sincronizado con las migraciones versionadas en `supabase/migrations/`.

---

## 1. Convenciones y Tipos Generales

1. **Identificadores primarios:** UUID v4 (`id UUID PRIMARY KEY DEFAULT gen_random_uuid()`), excepto en tablas de referencia geográfica oficial donde se utiliza el código DANE DIVIPOLA (`VARCHAR(5)`) y en los catálogos técnicos (`price_categories`, `municipality_zones`) donde se emplean claves estables (`VARCHAR(50)`).
2. **Nombres:** Tablas en plural y snake_case (`price_reports`, `municipality_zones`, `businesses`). Columnas en snake_case (`created_at`, `amount_cop`, `zone_id`).
3. **Moneda:** Pesos colombianos (COP) almacenados como enteros positivos (`INTEGER` o `BIGINT`), sin centavos.
4. **Fechas:** Con zona horaria estricta (`TIMESTAMPTZ`), por defecto `now()`.
5. **Tipos Enumerados y Restricciones de Dominio:**
   - En las migraciones reales del backend (`20261027151910_profiles_and_consents.sql`), las restricciones de dominio se implementan mediante columnas `TEXT` con restricciones `CHECK`:
     - `profile_type`:
       - **Valores admitidos en base de datos [IMPLEMENTADO - D11 RATIFICADA]:** `'visitor'`, `'settler'` y `'resident'` (mediante `CHECK (profile_type IN ('visitor', 'settler', 'resident'))` en la migración `20261029120000_close_vj07_vj08_d11_and_account_deletion.sql`).
     - `language`: `TEXT CHECK (language IN ('es', 'en'))` (implementado con valor por defecto `'es'`).
   - Para entidades posteriores planificadas:
     - `business_status`: `TEXT CHECK (status IN ('pending', 'approved', 'rejected'))` (planificado para VJ-16).
     - `verdict_level`: valor de texto retornado por la función de semáforo (`'insufficient'`, `'green'`, `'yellow'`, `'red'`).
   - **Eliminación de `user_role_enum`:** Se elimina formalmente cualquier tipo de rol en `profiles`. La pertenencia a administración vive exclusivamente en la tabla `public.admin_users` evaluada por la función `public.is_admin()`.

---

## 2. Especificación de Entidades

### 2.1 `profiles` y Autorización Administrativa

#### `profiles` (Información del Usuario)
- **Finalidad:** Almacenar los datos de identidad, preferencias e idioma del usuario autenticado en `auth.users`.
- **Estructura conciliada con migraciones reales de backend:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK, FK -> `auth.users(id)` ON DELETE CASCADE | Identificador unívoco del usuario en Auth |
  | `display_name` | `TEXT` | NULL | Nombre para mostrar (inicializado por trigger desde metadata) |
  | `profile_type` | `TEXT` | NULL, CHECK (`profile_type IN ('visitor', 'settler', 'resident')`) [IMPLEMENTADO D11] | Perfil de usuario (`'visitor'`, `'settler'`, `'resident'`). Inicialmente NULL hasta completar onboarding |
  | `origin_country` | `TEXT` | NULL | País de origen (opcional) |
  | `current_municipality_code` | `TEXT` | NULL, FK -> `municipalities(code)` | Municipio seleccionado como residencia/estadía |
  | `language` | `TEXT` | NOT NULL DEFAULT 'es', CHECK (`language IN ('es', 'en')`) | Idioma preferido |
  | `created_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha de creación del perfil |
  | `updated_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha de última modificación (mantenida por trigger) |

> **Compatibilidad con `handle_new_user()`:** Al registrarse un usuario en `auth.users`, el trigger inicial de base de datos ejecuta:
> `INSERT INTO public.profiles (id, display_name) VALUES (new.id, coalesce(...));`
> Para que esta inserción no falle, las columnas `profile_type`, `origin_country` y `current_municipality_code` son inicialmente `NULL` y se completan durante el onboarding. `language` cuenta con `DEFAULT 'es'`.
>
> **Distinción de perfiles admitidos vs. propuestos:** La migración `20261027151910_profiles_and_consents.sql` valida activamente `check (profile_type in ('visitor', 'settler'))`. La inclusión del perfil `'resident'` es una propuesta (D11) sujeta a validación con backend; hasta que se aplique la migración complementaria correspondiente, cualquier intento de escribir `'resident'` generará un error de restricción de integridad en PostgreSQL.

#### `admin_users` (Autorización Administrativa Separada)
Siguiendo la arquitectura de seguridad implementada en la migración `20261027151910_profiles_and_consents.sql`, **los privilegios de administración NO se guardan en `profiles`**. Se aísla el acceso administrativo en una tabla separada:
```sql
CREATE TABLE public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY; -- Sin políticas para authenticated/anon
```
- **Función de verificación:**
  ```sql
  CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid());
  $$;
  ```

#### Políticas de Privacidad, Autoría y Control de Columnas en `profiles`
1. **Lectura privada [IMPLEMENTADO]:** La política RLS existente `profiles_select_own` en `20261027151910_profiles_and_consents.sql` restringe estrictamente la lectura al propio usuario (`id = auth.uid()`).
2. **Auditoría de autoría y descarte de `get_public_author_name()`:**
   - **Evaluación de riesgos de seguridad:** Se auditó la propuesta de exponer `get_public_author_name(p_user_id UUID)` con `SECURITY DEFINER` y permisos `EXECUTE`. Esta función permitiría que cualquier cliente (incluso no autenticado o autenticado con fines maliciosos) consulte UUIDs arbitrarios en bucle, facilitando la **cosecha masiva de identidades y nombres reales (PII)** eludiendo la política RLS.
   - **Decisión arquitectónica:** En el MVP, los aportes a la base de precios son datos agregados para cálculo estadístico (mediana) y no requieren mostrar la identidad del autor a terceros. Por tanto, el nombre del autor permanece **estrictamente privado** y la función queda **[POSPUESTA / FUERA DE MVP]**. Cada usuario únicamente consulta sus propios aportes mediante RLS (`using (user_id = auth.uid())`).
3. **Restricción de actualización: RLS implementado vs. GRANTs propuestos:**
   - **RLS a nivel de fila [IMPLEMENTADO]:** La política `profiles_update_own` en la migración de Isaac garantiza que solo el dueño del registro pueda ejecutar `UPDATE` sobre su fila (`using (id = auth.uid()) with check (id = auth.uid())`).
   - **GRANTs a nivel de columna [PROPUESTO para VJ-07/VJ-08]:** Como mecanismo adicional de defensa en profundidad para evitar que se intenten modificar columnas inmutables o de auditoría, se propone para VJ-07 la siguiente configuración de privilegios (pendiente de incorporar por backend):
     ```sql
     -- Propuesta de defensa en profundidad (pendiente de acuerdo con Isaac en VJ-07):
     REVOKE UPDATE ON public.profiles FROM authenticated;
     GRANT UPDATE (display_name, origin_country, current_municipality_code, language, profile_type) ON public.profiles TO authenticated;
     ```

---

### 2.2 `consents`
- **Finalidad:** Registro auditable de consentimientos legales y tratamiento de datos personales (Habeas Data - Ley 1581 de 2012).
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador del consentimiento |
  | `user_id` | `UUID` | NOT NULL, FK -> `auth.users(id)` ON DELETE CASCADE | Usuario que consiente |
  | `doc_type` | `VARCHAR(50)` | NOT NULL | Tipo: `terms_and_conditions`, `privacy_policy` |
  | `version` | `VARCHAR(20)` | NOT NULL | Versión del documento aceptado (ej. `v1.0`) |
  | `accepted_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Marca temporal exacta de la aceptación |
- **Índices:** `CREATE INDEX idx_consents_user ON consents(user_id);`
- **Políticas RLS:**
  - `SELECT`: Solo el propietario (`auth.uid() = user_id`) o administradores.
  - `INSERT`: Solo el usuario autenticado (`auth.uid() = user_id`).
  - `UPDATE` / `DELETE`: **Prohibidos** (tabla inmutable de registro legal).

---

### 2.3 `departments`
- **Finalidad:** Catálogo maestro oficial de los 32 departamentos y Bogotá D.C. según DANE.
- **Estructura (conciliada con migración `20261027151907_extensions_and_geography.sql`):**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `code` | `TEXT` | PK, CHECK (`code ~ '^[0-9]{2}$'`) | Código DANE de 2 dígitos (ej. `'20'` para Cesar) |
  | `name` | `TEXT` | NOT NULL | Nombre oficial del departamento |
- **Políticas RLS:** `SELECT` público a todos los usuarios (`anon`, `authenticated`). Modificaciones solo `admin`.

---

### 2.4 `municipalities`
- **Finalidad:** Catálogo de municipios colombianos con indicación de ciudades piloto.
- **Estructura (conciliada con migración `20261027151907_extensions_and_geography.sql`):**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `code` | `TEXT` | PK, CHECK (`code ~ '^[0-9]{5}$'`) | Código DIVIPOLA de 5 dígitos (ej. `'20001'` para Valledupar) |
  | `department_code` | `TEXT` | NOT NULL, FK -> `departments(code)` | Código de departamento al que pertenece |
  | `name` | `TEXT` | NOT NULL | Nombre oficial del municipio |
  | `is_pilot` | `BOOLEAN` | NOT NULL DEFAULT false | Si es `true`, habilita la experiencia funcional de la app |
- **Índices:**
  - `CREATE INDEX municipalities_department_idx ON public.municipalities(department_code);`
  - `CREATE INDEX idx_municipalities_search ON public.municipalities USING gin(to_tsvector('spanish', name));`
- **Políticas RLS:** `SELECT` público a todos los usuarios (`anon`, `authenticated`). Modificaciones solo `admin`.

---

### 2.4.1 `municipality_zones`
- **Finalidad:** Subdivisión zonal dentro de cada municipio piloto para segmentar las medianas estadísticas de precios por sectores reales (p. ej., en Valledupar `'20001'`: `vup_norte`, `vup_centro`, `vup_sur`, `vup_oriente`, `vup_occidente`), evitando mezclar zonas con dinámicas de costo distintas en una sola cifra municipal.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `VARCHAR(50)` | PK | Identificador técnico de la zona (ej. `'vup_norte'`, `'vup_centro'`, `'vup_sur'`, `'vup_oriente'`, `'vup_occidente'`) |
  | `municipality_code` | `TEXT` | NOT NULL, FK -> `municipalities(code)` ON DELETE CASCADE | Municipio al que pertenece la zona |
  | `name_es` | `VARCHAR(100)` | NOT NULL | Nombre de la zona en español (ej. `"Zona Norte"`) |
  | `name_en` | `VARCHAR(100)` | NOT NULL | Nombre de la zona en inglés (ej. `"North Zone"`) |
  | `sector_hint_es` | `VARCHAR(150)` | NOT NULL DEFAULT '' | Barrios o puntos de referencia en español (ej. `"Novalito, San Joaquín, CC Guatapurí"`) |
  | `sector_hint_en` | `VARCHAR(150)` | NOT NULL DEFAULT '' | Barrios o puntos de referencia en inglés (ej. `"Novalito, San Joaquín, Guatapurí Mall"`) |
  | `normalized_x` | `NUMERIC(5,4)` | NOT NULL DEFAULT 0.5, CHECK (0..1) | Posición X normalizada en el lienzo del mapa local (consumida por `MunicipalityZone.fromMap`) |
  | `normalized_y` | `NUMERIC(5,4)` | NOT NULL DEFAULT 0.5, CHECK (0..1) | Posición Y normalizada en el lienzo del mapa local (consumida por `MunicipalityZone.fromMap`) |
  | `sort_order` | `INTEGER` | NOT NULL DEFAULT 0 | Orden de visualización en selectores |
  | `is_active` | `BOOLEAN` | NOT NULL DEFAULT true | Si la zona está activa para consultas y reportes |
- **Índices:** `CREATE INDEX idx_municipality_zones_mun ON public.municipality_zones(municipality_code, sort_order);`
- **Políticas RLS:** `SELECT` público (`anon`, `authenticated`). Modificaciones solo `admin`.

---

### 2.5 `price_categories`
- **Finalidad:** Catálogo estructurado de categorías de precios comparables.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `VARCHAR(50)` | PK | Clave fija técnica (ej. `transport_taxi_minimal`) |
  | `group_key` | `VARCHAR(50)` | NOT NULL | Grupo temático: `transport`, `food`, `lodging`, `services` |
  | `name_es` | `VARCHAR(100)` | NOT NULL | Nombre en español |
  | `name_en` | `VARCHAR(100)` | NOT NULL | Nombre en inglés |
  | `unit_description_es`| `VARCHAR(100)` | NOT NULL | Unidad comparable (ej. "Carrera mínima diurna urbana") |
  | `unit_description_en`| `VARCHAR(100)` | NOT NULL | Unidad en inglés (ej. "Standard urban daytime ride") |
  | `sort_order` | `INTEGER` | NOT NULL DEFAULT 0 | Orden de visualización en la interfaz |
  | `is_active` | `BOOLEAN` | NOT NULL DEFAULT true | Si está habilitada para nuevos reportes |
- **Políticas RLS:** `SELECT` público. Modificaciones solo `admin`.

---

### 2.6 `price_reports`
- **Finalidad:** Almacenar los reportes ciudadanos de precios observados en el terreno, segmentados por zona del municipio.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador del reporte |
  | `user_id` | `UUID` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | Usuario que reporta (se desvincula si borra su cuenta) |
  | `category_id` | `VARCHAR(50)` | NOT NULL, FK -> `price_categories(id)` | Categoría comparable específica |
  | `municipality_code` | `TEXT` | NOT NULL, FK -> `municipalities(code)` | Municipio del reporte |
  | `zone_id` | `VARCHAR(50)` | NOT NULL, FK -> `municipality_zones(id)` | Zona del municipio donde se observó el precio (ej. `'vup_norte'`, `'vup_centro'`, `'vup_sur'`) |
  | `amount_cop` | `INTEGER` | NOT NULL, CHECK (amount_cop > 0) | Monto observado en pesos colombianos |
  | `location` | `GEOGRAPHY(Point, 4326)` | NULL | Coordenadas aproximadas del reporte (PostGIS) |
  | `place_name` | `VARCHAR(150)` | NULL | Nombre descriptivo del lugar o sector |
  | `is_seed` | `BOOLEAN` | NOT NULL DEFAULT false | Marca de datos semilla iniciales verificados |
  | `is_demo` | `BOOLEAN` | NOT NULL DEFAULT false | Marca de datos de demostración para pruebas |
  | `is_hidden` | `BOOLEAN` | NOT NULL DEFAULT false | Oculto por moderación o anomalía |
  | `source_note` | `VARCHAR(255)` | NULL | Fuente u observación (ej. "Factura local", "Observación en terminal") |
  | `created_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha y hora del reporte |

> **Protocolo Transaccional de Supresión de Cuenta y Minimizacion de Datos (Habeas Data - Ley 1581 de 2012):**  
> 
> La desvinculación de la clave foránea mediante `ON DELETE SET NULL` sobre `price_reports.user_id` ocurre al suprimirse el usuario. Sin embargo, **si se elimina primero el registro en `auth.users`, los reportes quedan huérfanos con `user_id = NULL` y se vuelve imposible identificar cuáles pertenecían a ese usuario para depurar información contextual o privada**.
>
> Por tanto, el protocolo de eliminación **debe ejecutarse en orden estricto antes de la baja del usuario**, mediante una operación de backend segura y transaccional (RPC con `SECURITY DEFINER` o Edge Function administrativa con `service_role`):
> 
> 1. **Fase 1: Pre-supresión y depuración contextual (Antes de eliminar la cuenta):**
>    - Se valida que el llamador autenticado coincida con el usuario objetivo (`auth.uid() = p_user_id`).
>    - Dentro de una transacción atómica de base de datos:
>      - **Depuración de texto libre e identificadores:** Se vacían `source_note = NULL` y `place_name = NULL` (`UPDATE price_reports SET source_note = NULL, place_name = NULL WHERE user_id = p_user_id;`), erradicando nombres comerciales atípicos, referencias domiciliarias o comentarios con PII.
>      - **Saneamiento espacial:** Si el reporte contiene coordenadas GPS de alta precisión (`location`) asociadas a domicilios privados o rutas personales, se disocian fijándolas en `NULL` (`UPDATE price_reports SET location = NULL WHERE user_id = p_user_id;`), conservando únicamente `municipality_code`, `zone_id` y `category_id` (macro-zona del municipio sin coordenadas exactas).
>      - **Eliminación de registros personales directos:** Se suprimen los registros en `consents` y solicitudes en `interest_registrations`.
> 2. **Fase 2: Supresión del usuario en `auth.users`:**
>    - Una vez saneados los datos contextuales, se invoca la eliminación en el subsistema de autenticación (`supabase.auth.admin.deleteUser(p_user_id)`).
>    - Esta baja elimina en cascada `public.profiles` (`ON DELETE CASCADE`) y activa `ON DELETE SET NULL` sobre `price_reports.user_id`, desvinculando la clave foránea del registro numérico previamente saneado.
> 3. **Manejo transaccional y tratamiento de errores:**
>    - Si la depuración en la Fase 1 falla o arroja excepción, la transacción hace `ROLLBACK` completo y la cuenta **NO** se elimina, retornando un error controlado al cliente (`500 Internal Error / Error en saneamiento previo de cuenta`).
>    - Si la Fase 1 culmina exitosamente pero falla la invocación de `deleteUser` en Auth, la operación se registra en bitácora administrativa para reintento y se notifica al usuario, evitando inconsistencias entre Auth y la base de datos pública.
> 4. **Aclaración sobre el nivel de privacidad:**
>    - No se califica este procedimiento como "anonimización irreversible absoluta", ya que el riesgo residual de reidentificación depende del tamaño de la muestra comunitaria ($k$-anonimato) y de correlaciones externas. Se clasifica formalmente como una **estrategia de minimización de datos y disociación seudónima reforzada** conforme a la Ley 1581 de 2012 y las directrices de la SIC, sujeta a auditoría de privacidad empírica.
- **Índices obligatorios:**
  - `CREATE INDEX idx_price_reports_stat ON price_reports(municipality_code, zone_id, category_id, created_at) WHERE is_hidden = false AND is_demo = false;`
  - `CREATE INDEX idx_price_reports_location ON price_reports USING GIST(location);`
  - `CREATE INDEX idx_price_reports_user ON price_reports(user_id);`
- **Políticas RLS:**
  - `SELECT`: Visible para todos si `is_hidden = false` y `is_demo = false` (a menos que el usuario esté en modo demo).
  - `INSERT`: Usuarios autenticados (`auth.uid() = user_id`), validando tope de reportes diarios para prevenir spam.
  - `UPDATE` / `DELETE`: Solo el autor sobre sus reportes recientes o administradores.

---

### 2.7 `events`
- **Finalidad:** Registro de festivales, ferias y eventos masivos que provocan variaciones estacionales en los precios.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador del evento |
  | `municipality_code` | `VARCHAR(5)` | NOT NULL, FK -> `municipalities(code)` | Municipio sede del evento |
  | `name` | `VARCHAR(150)` | NOT NULL | Nombre del evento (ej. "Festival Vallenato") |
  | `starts_at` | `TIMESTAMPTZ` | NOT NULL | Fecha/hora de inicio |
  | `ends_at` | `TIMESTAMPTZ` | NOT NULL, CHECK (ends_at >= starts_at) | Fecha/hora de finalización |
  | `is_demo` | `BOOLEAN` | NOT NULL DEFAULT false | **Obligatorio para la demo**: no presentar eventos simulados como reales |
- **Índices:** `CREATE INDEX idx_events_dates ON events(municipality_code, starts_at, ends_at);`
- **Políticas RLS:** `SELECT` público. `INSERT`/`UPDATE`/`DELETE` exclusivo de administradores.

---

### 2.8 `app_config`
- **Finalidad:** Parámetros operativos y umbrales globales de la plataforma (diseñado para absorber cambios sin publicar nuevas versiones de la app).
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `key` | `VARCHAR(50)` | PK | Clave de configuración (ej. `price_verdict_rules`) |
  | `value` | `JSONB` | NOT NULL | Objeto con valores tipados |
  | `updated_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha de última actualización |
- **Valores por defecto en semilla:**
  ```json
  {
    "window_days": 60,
    "min_reports": 3,
    "threshold_green": 15.0,
    "threshold_yellow": 40.0,
    "underpriced_alert_threshold": -40.0,
    "recommended_cap_factor": 1.15,
    "daily_ai_limit_per_user": 5
  }
  ```
- **Políticas RLS:** `SELECT` público a autenticados. Modificación exclusiva de administradores.

---

### 2.9 `ai_usage`
- **Finalidad:** Control de cuota y presupuesto diario para el análisis de contratos mediante Gemini.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `user_id` | `UUID` | NOT NULL, FK -> `auth.users(id)` | Usuario solicitante |
  | `day` | `DATE` | NOT NULL DEFAULT CURRENT_DATE | Día calendario de la solicitud |
  | `count` | `INTEGER` | NOT NULL DEFAULT 1 | Cantidad de análisis ejecutados en el día |
  | PRIMARY KEY | `(user_id, day)` | PK compuesta |
- **Políticas RLS:** Gestionado exclusivamente por la Edge Function mediante la clave de servicio (`service_role`). Inaccesible directamente por el cliente móvil para evitar manipulación.

---

### 2.10 `businesses`
- **Finalidad:** Directorio y registro ciudadano de negocios y comercios locales.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador del negocio |
  | `owner_id` | `UUID` | NOT NULL, FK -> `auth.users(id)` | Usuario dueño o proponente del registro |
  | `municipality_code` | `VARCHAR(5)` | NOT NULL, FK -> `municipalities(code)` | Municipio del establecimiento |
  | `type` | `VARCHAR(50)` | NOT NULL | Tipo: `restaurant`, `hotel`, `service`, `handicraft` |
  | `name` | `VARCHAR(150)` | NOT NULL | Nombre comercial |
  | `description_es` | `TEXT` | NOT NULL | Descripción en español |
  | `description_en` | `TEXT` | NOT NULL | Descripción en inglés |
  | `location` | `GEOGRAPHY(Point, 4326)` | NOT NULL | Coordenadas del local |
  | `place_id` | `VARCHAR(150)` | NULL | Google Places ID para "Cómo llegar" |
  | `phone` | `VARCHAR(20)` | NULL | Teléfono fijo o móvil local |
  | `whatsapp` | `VARCHAR(20)` | NOT NULL | Teléfono en formato internacional (sin el `+`) |
  | `whatsapp_consent_at`| `TIMESTAMPTZ` | NOT NULL | Consentimiento para enlace comercial wa.me |
  | `order_url` | `TEXT` | NULL | Enlace opcional a carta o sistema de pedidos externo |
  | `hours` | `JSONB` | NULL | Estructura de horarios de atención |
  | `status` | `TEXT` | NOT NULL DEFAULT 'pending', CHECK (status in ('pending', 'approved', 'rejected')) | Estado: `pending`, `approved`, `rejected` |
  | `rejection_reason` | `TEXT` | NULL | Motivo de rechazo en caso de no aprobación |
  | `created_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha de registro |
- **Índices:**
  - `CREATE INDEX idx_businesses_approved ON businesses(municipality_code, type) WHERE status = 'approved';`
  - `CREATE INDEX idx_businesses_owner ON businesses(owner_id);`
  - `CREATE INDEX idx_businesses_location ON businesses USING GIST(location);`
- **Políticas RLS:**
  - `SELECT`: Cualquier usuario puede leer comercios con `status = 'approved'`. El `owner_id` puede ver sus comercios en cualquier estado.
  - `INSERT`: Cualquier usuario autenticado puede proponer un nuevo negocio (nace obligatoriamente con `status = 'pending'`).
  - `UPDATE`: El `owner_id` puede editar datos descriptivos mientras esté pendiente o aprobado, pero **no puede alterar el campo `status`**.
  - Transición a `approved` o `rejected`: Exclusiva de administradores.

---

### 2.11 `business_photos`
- **Finalidad:** Fotografías del local y productos (máximo 5 por negocio).
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador |
  | `business_id` | `UUID` | NOT NULL, FK -> `businesses(id)` ON DELETE CASCADE | Negocio asociado |
  | `storage_path` | `TEXT` | NOT NULL | Ruta del archivo en el bucket `business-media` |
  | `position` | `INTEGER` | NOT NULL DEFAULT 0 | Orden de visualización (0 a 4) |
  | `is_cover` | `BOOLEAN` | NOT NULL DEFAULT false | Si es la imagen de portada |
- **Políticas RLS:** `SELECT` público si el negocio está aprobado; administrada por el dueño del negocio.

---

### 2.12 `business_dishes`
- **Finalidad:** Platos o servicios destacados (máximo 5 por negocio, opcional para restaurantes y servicios).
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador |
  | `business_id` | `UUID` | NOT NULL, FK -> `businesses(id)` ON DELETE CASCADE | Negocio asociado |
  | `name` | `VARCHAR(100)` | NOT NULL | Nombre del plato o servicio |
  | `price_cop` | `INTEGER` | NOT NULL, CHECK (price_cop > 0) | Precio en pesos colombianos |
  | `description` | `TEXT` | NULL | Breve reseña del producto |
  | `sort_order` | `INTEGER` | NOT NULL DEFAULT 0 | Orden de aparición |
- **Políticas RLS:** Hereda la visibilidad y permisos del negocio asociado.

---

### 2.13 `city_content`
- **Finalidad:** Contenido cultural, gastronómico, patrimonial y de servicios de la ciudad piloto.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador |
  | `municipality_code` | `VARCHAR(5)` | NOT NULL, FK -> `municipalities(code)` | Municipio al que pertenece |
  | `locale` | `VARCHAR(2)` | NOT NULL, CHECK (locale IN ('es', 'en')) | Idioma del contenido |
  | `section` | `VARCHAR(50)` | NOT NULL | Sección: `culture`, `gastronomy`, `emergency` |
  | `title` | `VARCHAR(150)` | NOT NULL | Título de la tarjeta |
  | `body` | `TEXT` | NOT NULL | Contenido narrativo |
  | `image_path` | `TEXT` | NULL | Imagen con licencia y atribución |
  | `source_citation` | `VARCHAR(255)` | NOT NULL | Fuente y crédito oficial de la información |
- **Políticas RLS:** `SELECT` público. Modificación exclusiva de administradores.

---

### 2.14 `interest_registrations`
- **Finalidad:** Almacenar solicitudes ciudadanas de apertura de nuevos municipios fuera del piloto (botón "Notificarme").
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador |
  | `user_id` | `UUID` | NOT NULL, FK -> `auth.users(id)` | Usuario interesado |
  | `municipality_code` | `VARCHAR(5)` | NOT NULL, FK -> `municipalities(code)` | Municipio solicitado |
  | `created_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha del registro de interés |
  | UNIQUE | `(user_id, municipality_code)` | Evita duplicar votos |
- **Políticas RLS:** `INSERT` por el usuario autenticado. `SELECT` solo para el usuario (`auth.uid() = user_id`) o administradores.

---

## 3. Contrato de la Función RPC del Semáforo de Precios por Zona

> **Principio de Fuente Única de Verdad:** La regla de justicia de precios **se calcula exclusivamente en la base de datos** mediante una función SQL (`calculate_price_verdict`), garantizando consistencia, auditoría y seguridad. El cliente Flutter únicamente presenta el veredicto visualmente. Para el primer avance, Flutter usará un espejo en Dart rotulado explícitamente como `DEMO`.

### 3.1 Firma Propuesta
```sql
CREATE OR REPLACE FUNCTION calculate_price_verdict(
    p_category_id VARCHAR,
    p_municipality_code VARCHAR,
    p_zone_id VARCHAR,
    p_amount_cop INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$ ... $$;
```

### 3.2 Lógica Estadística y Reglas de Negocio
1. **Filtro de reportes válidos por zona del municipio:** Se consultan reportes de la misma categoría, municipio y **zona del municipio** (`zone_id = p_zone_id`, p. ej. Norte, Centro, Sur, Oriente u Occidente en Valledupar) dentro de una ventana de **60 días** (`created_at >= now() - INTERVAL '60 days'`), excluyendo reportes ocultos (`is_hidden = false`) y demos (`is_demo = false`).
2. **Muestra mínima en la zona ($N \ge 3$):**
   - Si la cantidad de reportes válidos en la zona $N < 3$, la función retorna `level: "insufficient"`. No se asigna color de semáforo ni recomendación cuantitativa.
3. **Cálculo de la referencia zonal (Mediana):**
   - La referencia de la zona se calcula como la mediana estadística exacta: `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount_cop)`.
   - Se prohíbe el uso de promedios simples o de medianas globales de todo el municipio para evitar sesgo por diferencias de costo entre sectores y cobros atípicos extremos.
4. **Desviación Porcentual:**
   $$\text{desv} = \frac{\text{precio} - \text{ref}}{\text{ref}} \times 100$$
5. **Niveles del Semáforo:**
   - **Verde (`green`):** $\text{desv} \le 15.0\%$.
   - **Amarillo (`yellow`):** $15.0\% < \text{desv} \le 40.0\%$.
   - **Rojo (`red`):** $\text{desv} > 40.0\%$.
6. **Advertencia de precio sospechosamente bajo (`underpriced_alert`):**
   - Si $\text{desv} < -40.0\%$, el nivel es `green`, pero se activa el flag booleano `underpriced_alert: true` con mensaje informativo (posible estafa, servicio incompleto o baja calidad).
7. **Contexto de Evento Activo:**
   - Se verifica si el municipio tiene un evento activo hoy (`now() BETWEEN starts_at AND ends_at`).
   - Si existe evento y la zona cuenta con $\ge 3$ reportes dentro de sus fechas, se calcula la mediana de la zona en el evento (`ref_event`) y su respectiva desviación. El resultado entrega ambas referencias para contraste transparente.
8. **Tope Recomendado en la Zona:**
   $$\text{tope\_recomendado} = \text{referencia\_vigente} \times 1.15$$

### 3.3 Esquema JSON de Respuesta
```json
{
  "rule_version": "v1.0",
  "level": "green" | "yellow" | "red" | "insufficient",
  "category_id": "transport_taxi_minimal",
  "municipality_code": "20001",
  "zone_id": "vup_centro",
  "amount_cop": 15000,
  "reference_cop": 12000,
  "baseline_reference_cop": 12000,
  "deviation_percent": 25.0,
  "baseline_deviation_percent": 25.0,
  "sample_count": 8,
  "underpriced_alert": false,
  "recommended_cap_cop": 13800,
  "window_days": 60,
  "is_event_context": false,
  "event_details": null,
  "is_demo": false
}
```

### 3.4 Casos de Prueba Límite Requeridos (RNF-09)
1. **$\text{desv} = 0.0\%$:** Nivel `green`.
2. **$\text{desv} = 15.0\%$:** Nivel `green` (límite superior verde).
3. **$\text{desv} = 15.01\%$:** Nivel `yellow` (inicio amarillo).
4. **$\text{desv} = 40.0\%$:** Nivel `yellow` (límite superior amarillo).
5. **$\text{desv} = 40.01\%$:** Nivel `red` (inicio rojo).
6. **$N < 3$ reportes en la zona:** Nivel `insufficient` (estado neutro).
7. **$\text{desv} = -40.01\%$:** Nivel `green` con `underpriced_alert = true`.
8. **Evento activo con $N \ge 3$ en la zona:** Retorna referencias base y de evento.
9. **Evento activo con $N < 3$ en la zona:** Retorna advertencia de evento pero evalúa sobre histórico zonal de 60 días.

---

## 4. Contrato de la Edge Function para Análisis de Contratos con Gemini

### 4.1 Endpoint y Autenticación
- **URL:** `POST https://<project-ref>.supabase.co/functions/v1/analyze_contract`
- **Headers:**
  - `Authorization: Bearer <JWT_USER_SESSION>` (usuario autenticado obligatorio).
  - `Content-Type: application/json`

### 4.2 Payload de Entrada
```json
{
  "contract_text": "Texto extraído mediante OCR o PDF...",
  "locale": "es"
}
```

### 4.3 Control de Seguridad, Cuota Atómica y Prompt Defense
1. **Límite de caracteres:** Máximo 15.000 caracteres de texto plano (cuerpo HTTP crudo $\le 128\text{ KB}$).
2. **Validación atómica de cuota (`public.ai_usage`, zona horaria `America/Bogota`):**
   - La Edge Function invoca con `service_role` la RPC `public.consume_ai_daily_quota(user_id)` antes de llamar a Gemini (serializada con `pg_advisory_xact_lock`).
   - Si `count >= 5` en el día calendario actual (`America/Bogota`, `UTC-5`), rechaza inmediatamente con HTTP `429 Too Many Requests` y código `AI_DAILY_LIMIT_EXCEEDED`.
   - **Política de reintegro ante fallos técnicos:** Si la llamada posterior a Gemini falla por error de proveedor (`502`/`503`), timeout (`504`) o respuesta malformada (`AI_RESPONSE_INVALID`), la función ejecuta `public.refund_ai_daily_quota(user_id)` para que el reintento del usuario no consuma su cuota diaria.
   - El usuario autenticado puede consultar su saldo diario mediante `public.get_my_ai_quota_status()`.
3. **Aislamiento de Prompt y Saneamiento de Salida:** El texto del contrato se delimita dentro de `<untrusted_contract_document>` como dato no confiable (*untrusted input*). El validador de salida elimina etiquetas HTML/script y anula a `null` cualquier referencia legal no verificable contra normas reales colombianas (*Ley 820 de 2003*, *Código Civil*, *Código de Comercio*, *Ley 1480 de 2011*, *Ley 1581 de 2012*).
4. **Privacidad estricta (RN-10):** El texto del contrato **NUNCA se persiste en la base de datos, Storage ni en logs**. Solo se registra el conteo de uso en `ai_usage`.

### 4.4 Esquema JSON Retornado por Gemini (`responseSchema`)
```json
{
  "level": "green" | "yellow" | "red",
  "general_recommendation": "Resumen conciso y profesional del contrato.",
  "key_points": [
    {
      "title": "Monto y canon de arriendo",
      "detail": "El canon mensual pactado es de $1.200.000 COP con incremento según IPC."
    }
  ],
  "clauses": [
    {
      "excerpt": "El arrendatario no podrá solicitar reparaciones bajo ninguna circunstancia.",
      "issue": "Cláusula potencialmente abusiva que transgrede la obligación de mantenimiento legal.",
      "legal_reference": "Ley 820 de 2003, Artículo 8",
      "recommendation": "Solicitar la eliminación o modificación de esta cláusula antes de firmar."
    }
  ],
  "disclaimer": "El presente análisis es asistido por inteligencia artificial con fines exclusivamente pedagógicos y orientativos. No sustituye la asesoría jurídica profesional.",
  "locale": "es"
}
```

### 4.5 Manejo de Errores Tipados
| Código HTTP | Código Error App | Mensaje Traducible |
|---|---|---|
| 401 | `AUTH_UNAUTHORIZED` | Sesión requerida para analizar documentos |
| 400 | `INVALID_INPUT_EMPTY` | El documento no contiene texto legible |
| 413 | `TEXT_TOO_LONG` | El texto supera el tamaño máximo permitido |
| 429 | `AI_DAILY_LIMIT_EXCEEDED` | Has alcanzado el límite diario de análisis de contratos |
| 502 | `AI_SERVICE_UNAVAILABLE` | El servicio de análisis no está disponible temporalmente |
