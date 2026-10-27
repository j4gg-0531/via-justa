# Contrato de Datos v1.0 — Vía Justa MVP

> **Estado del documento:** ESQUEMA PROPUESTO PARA RATIFICACIÓN (Contract-First).  
> **Fecha:** 27 de octubre de 2026.  
> **Importante:** Este documento representa el acuerdo de interfaz formal entre Frontend (Flutter) y Backend (Supabase/PostgreSQL). Actualmente **NO se han aplicado migraciones físicas** en la base de datos de producción ni local; este contrato debe ser validado por el compañero de backend antes de ejecutar la migración inicial `0001_initial_schema.sql` (VJ-07).

---

## 1. Convenciones y Tipos Generales

1. **Identificadores primarios:** UUID v4 (`id UUID PRIMARY KEY DEFAULT gen_random_uuid()`), excepto en tablas de referencia geográfica oficial donde se utiliza el código DANE DIVIPOLA (`VARCHAR(5)`).
2. **Nombres:** Tablas en plural y snake_case (`price_reports`, `businesses`). Columnas en snake_case (`created_at`, `amount_cop`).
3. **Moneda:** Pesos colombianos (COP) almacenados como enteros positivos (`INTEGER` o `BIGINT`), sin centavos.
4. **Fechas:** Con zona horaria estricta (`TIMESTAMPTZ`), por defecto `now()`.
5. **Tipos Enumerados (Enums):**
   ```sql
   CREATE TYPE profile_type_enum AS ENUM ('visitor', 'settler', 'resident');
   CREATE TYPE business_status_enum AS ENUM ('pending', 'approved', 'rejected');
   CREATE TYPE verdict_level_enum AS ENUM ('insufficient', 'green', 'yellow', 'red');
   CREATE TYPE user_role_enum AS ENUM ('authenticated_user', 'admin');
   ```

---

## 2. Especificación de Entidades

### 2.1 `profiles`
- **Finalidad:** Almacenar la información pública y preferencias del usuario autenticado en `auth.users`.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK, FK -> `auth.users(id)` ON DELETE CASCADE | Identificador unívoco del usuario en Auth |
  | `display_name` | `VARCHAR(100)` | NOT NULL | Nombre para mostrar registrado en bienvenida |
  | `profile_type` | `profile_type_enum`| NOT NULL DEFAULT 'visitor' | Perfil de usuario (D11 propuesto) |
  | `origin_country` | `VARCHAR(3)` | NULL | Código ISO de país de origen (opcional) |
  | `current_municipality_code` | `VARCHAR(5)` | NULL, FK -> `municipalities(code)` | Municipio seleccionado como residencia/estadía |
  | `language` | `VARCHAR(2)` | NOT NULL DEFAULT 'es' | Idioma preferido (`es` / `en`) |
  | `role` | `user_role_enum` | NOT NULL DEFAULT 'authenticated_user' | Rol del usuario. **No editable por el cliente** |
  | `created_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha de creación del perfil |
  | `updated_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha de última modificación |
- **Índices:** `CREATE INDEX idx_profiles_municipality ON profiles(current_municipality_code);`
- **Políticas RLS:**
  - `SELECT`: Público para datos no sensibles o restringido al propio usuario (`auth.uid() = id`).
  - `INSERT`: Solo el propio usuario (`auth.uid() = id`).
  - `UPDATE`: Solo el propio usuario sobre sus columnas, **excluyendo `role`** (garantizado con triggers o políticas de columnas).
  - `DELETE`: Cascada desde `auth.users` o llamada administrativa.
- **Responsabilidad:** Frontend gestiona creación al completar registro; Backend valida integridad y bloquea escalamiento de privilegios a `admin`.

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
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `code` | `VARCHAR(2)` | PK | Código DIVIPOLA de 2 dígitos (ej. `'20'` para Cesar) |
  | `name` | `VARCHAR(100)` | NOT NULL, UNIQUE | Nombre oficial del departamento |
  | `is_available` | `BOOLEAN` | NOT NULL DEFAULT false | Habilitado para navegación operativa |
- **Políticas RLS:** `SELECT` público a todos los usuarios (`anon`, `authenticated`). Modificaciones solo `admin`.

---

### 2.4 `municipalities`
- **Finalidad:** Catálogo de municipios colombianos con indicación de ciudades piloto.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `code` | `VARCHAR(5)` | PK | Código DIVIPOLA de 5 dígitos (ej. `'20001'` para Valledupar) |
  | `department_code` | `VARCHAR(2)` | NOT NULL, FK -> `departments(code)` | Departamento al que pertenece |
  | `name` | `VARCHAR(100)` | NOT NULL | Nombre del municipio |
  | `is_pilot` | `BOOLEAN` | NOT NULL DEFAULT false | Si es `true`, abre la experiencia completa de la app |
- **Índices:**
  - `CREATE INDEX idx_municipalities_dept ON municipalities(department_code);`
  - `CREATE INDEX idx_municipalities_search ON municipalities USING gin(to_tsvector('spanish', name));`
- **Políticas RLS:** `SELECT` público a todos los usuarios (`anon`, `authenticated`). Modificaciones solo `admin`.

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
- **Finalidad:** Almacenar los reportes ciudadanos de precios observados en el terreno.
- **Estructura:**
  | Columna | Tipo | Restricciones | Descripción |
  |---|---|---|---|
  | `id` | `UUID` | PK DEFAULT gen_random_uuid() | Identificador del reporte |
  | `user_id` | `UUID` | NOT NULL, FK -> `auth.users(id)` | Usuario que reporta el precio |
  | `category_id` | `VARCHAR(50)` | NOT NULL, FK -> `price_categories(id)` | Categoría comparable específica |
  | `municipality_code` | `VARCHAR(5)` | NOT NULL, FK -> `municipalities(code)` | Municipio del reporte |
  | `amount_cop` | `INTEGER` | NOT NULL, CHECK (amount_cop > 0) | Monto observado en pesos colombianos |
  | `location` | `GEOGRAPHY(Point, 4326)` | NULL | Coordenadas aproximadas del reporte (PostGIS) |
  | `place_name` | `VARCHAR(150)` | NULL | Nombre descriptivo del lugar o sector |
  | `is_seed` | `BOOLEAN` | NOT NULL DEFAULT false | Marca de datos semilla iniciales verificados |
  | `is_demo` | `BOOLEAN` | NOT NULL DEFAULT false | Marca de datos de demostración para pruebas |
  | `is_hidden` | `BOOLEAN` | NOT NULL DEFAULT false | Oculto por moderación o anomalía |
  | `source_note` | `VARCHAR(255)` | NULL | Fuente u observación (ej. "Factura local", "Observación en terminal") |
  | `created_at` | `TIMESTAMPTZ` | NOT NULL DEFAULT now() | Fecha y hora del reporte |
- **Índices obligatorios:**
  - `CREATE INDEX idx_price_reports_stat ON price_reports(municipality_code, category_id, created_at) WHERE is_hidden = false AND is_demo = false;`
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
  | `status` | `business_status_enum` | NOT NULL DEFAULT 'pending' | Estado: `pending`, `approved`, `rejected` |
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

## 3. Contrato de la Función RPC del Semáforo de Precios

> **Principio de Fuente Única de Verdad:** La regla de justicia de precios **se calcula exclusivamente en la base de datos** mediante una función SQL (`calculate_price_verdict`), garantizando consistencia, auditoría y seguridad. El cliente Flutter únicamente presenta el veredicto visualmente. Para el primer avance, Flutter usará un espejo en Dart rotulado explícitamente como `DEMO`.

### 3.1 Firma Propuesta
```sql
CREATE OR REPLACE FUNCTION calculate_price_verdict(
    p_category_id VARCHAR,
    p_municipality_code VARCHAR,
    p_amount_cop INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$ ... $$;
```

### 3.2 Lógica Estadística y Reglas de Negocio
1. **Filtro de reportes válidos:** Se consultan reportes de la misma categoría y municipio dentro de una ventana de **60 días** (`created_at >= now() - INTERVAL '60 days'`), excluyendo reportes ocultos (`is_hidden = false`) y demos (`is_demo = false`).
2. **Muestra mínima ($N \ge 3$):**
   - Si la cantidad de reportes válidos $N < 3$, la función retorna `level: "insufficient"`. No se asigna color de semáforo ni recomendación cuantitativa.
3. **Cálculo de la referencia (Mediana):**
   - La referencia se calcula como la mediana estadística exacta: `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount_cop)`.
   - Se prohíbe el uso de promedios simples para evitar sesgo por cobros atípicos extremos.
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
   - Si existe evento y cuenta con $\ge 3$ reportes dentro de sus fechas, se calcula la mediana del evento (`ref_event`) y su respectiva desviación. El resultado entrega ambas referencias para contraste transparente.
8. **Tope Recomendado:**
   $$\text{tope\_recomendado} = \text{referencia\_vigente} \times 1.15$$

### 3.3 Esquema JSON de Respuesta
```json
{
  "level": "green" | "yellow" | "red" | "insufficient",
  "amount_cop": 15000,
  "reference_cop": 12000,
  "deviation_percent": 25.0,
  "sample_count": 8,
  "underpriced_alert": false,
  "recommended_cap_cop": 13800,
  "window_days": 60,
  "is_event_context": false,
  "event_details": null,
  "disclaimer": "Este cálculo es una referencia estadística comunitaria orientativa y no constituye una tarifa legalmente vinculante."
}
```

### 3.4 Casos de Prueba Límite Requeridos (RNF-09)
1. **$\text{desv} = 0.0\%$:** Nivel `green`.
2. **$\text{desv} = 15.0\%$:** Nivel `green` (límite superior verde).
3. **$\text{desv} = 15.01\%$:** Nivel `yellow` (inicio amarillo).
4. **$\text{desv} = 40.0\%$:** Nivel `yellow` (límite superior amarillo).
5. **$\text{desv} = 40.01\%$:** Nivel `red` (inicio rojo).
6. **$N < 3$ reportes:** Nivel `insufficient` (estado neutro).
7. **$\text{desv} = -40.01\%$:** Nivel `green` con `underpriced_alert = true`.
8. **Evento activo con $N \ge 3$:** Retorna referencias base y de evento.
9. **Evento activo con $N < 3$:** Retorna advertencia de evento pero evalúa sobre histórico de 60 días.

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

### 4.3 Control de Seguridad y Prompt Defense
1. **Límite de caracteres:** Máximo 15.000 caracteres de texto plano.
2. **Validación de cuota:** La función consulta `ai_usage`. Si `count >= 5` en el día actual, rechaza con código HTTP `429 Too Many Requests`.
3. **Aislamiento de Prompt:** El texto del contrato se trata como dato no confiable (*untrusted input*). El system prompt instruye ignorar instrucciones imperativas embebidas en el contrato.
4. **Privacidad estricta (RN-10):** El texto del contrato **NUNCA se persiste en la base de datos ni en logs**. Solo se registra el conteo de uso en `ai_usage`.

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
