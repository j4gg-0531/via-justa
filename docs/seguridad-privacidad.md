# Política de Seguridad, Autenticación y Privacidad de Datos — Vía Justa MVP

## 1. Principios Rectores y Clasificación de Controles

Los controles de seguridad y privacidad se clasifican rigurosamente según su estado real en el ciclo de desarrollo:
- **[IMPLEMENTADO]:** Funcionalidad escrita, probada o presente en el repositorio.
- **[PROPUESTO]:** Especificación técnica acordada pendiente de implementación o migración en base de datos.
- **[PENDIENTE DE PRUEBA]:** Control dependiente de validación en entorno de integración o dispositivo real.

### Principios Fundamentales
1. **Defensa en Profundidad:** La seguridad no recae exclusivamente en la aplicación móvil; las reglas de autorización residen en la base de datos (PostgreSQL Row Level Security) y en las Edge Functions **[PROPUESTO]**.
2. **Principio de Mínimo Privilegio:** La aplicación Flutter utiliza exclusivamente la clave anónima pública (`anon_key`) de Supabase. **La clave de servicio (`service_role_key`) nunca se empaqueta, referencia ni transmite al cliente móvil** **[IMPLEMENTADO EN DISEÑO]**.
3. **No Retención de Datos Contractuales (RN-10):** Los contratos analizados por el motor de IA no se almacenan en bases de datos ni en discos persistentes; el texto viaja en memoria por canal seguro HTTPS y se descarta inmediatamente tras emitir la respuesta estructurada de Gemini **[PROPUESTO]**.
4. **Cumplimiento Normativo Colombiano:** Tratamiento de datos personales enmarcado en el Régimen General de Protección de Datos Personales (Ley Estatutaria 1581 de 2012 y Decreto 1377 de 2013) **[PROPUESTO]**.

---

## 2. Ciclo de Vida de Autenticación y Sesión

### 2.1 Proveedores Soportados
- **Correo y Contraseña:** Registro y login validado localmente en `domain/auth_validators.dart` **[IMPLEMENTADO]**; conexión a Supabase Auth **[PROPUESTO]**.
- **Google OAuth:** Botón en interfaz **[IMPLEMENTADO EN DEMO]**; flujo federado real vía Supabase Auth **[PROPUESTO]**.

### 2.2 Registro y Política de Contraseñas
- **Validación Local:** La contraseña debe contener mínimo 8 caracteres (validado por `auth_validators.dart`) **[IMPLEMENTADO]**.
- **Verificación de Correo:**
  - *Entorno de Desarrollo / Pruebas:* Auto-confirmación habilitada para facilitar la evaluación sin dependencias SMTP externas **[PROPUESTO]**.
  - *Entorno de Producción:* Envío de enlace de verificación por correo electrónico. El usuario no podrá emitir reportes de precios ni registrar negocios hasta confirmar su cuenta **[PROPUESTO]**.

### 2.3 Persistencia y Renovación de Sesión
- **Mecanismo de Almacenamiento:** Por defecto, el cliente de Supabase para Flutter persiste los tokens de sesión en el almacenamiento local estándar provisto por el sistema operativo (`SharedPreferences` en Android) **[PROPUESTO]**.
- **Cifrado en Reposo:** La delegación de tokens al almacén seguro nativo (`EncryptedSharedPreferences` / Android Keystore) requiere la configuración explícita de un adaptador con `flutter_secure_storage`, clasificado actualmente como **[PROPUESTO / PENDIENTE DE PRUEBA]**.
- **Canal de Comunicación:** Las peticiones de red utilizan HTTPS estándar, negociando la versión de TLS más alta admitida conjuntamente por los servidores de Supabase/Google y la pila de red de Android (típicamente TLS 1.2 o TLS 1.3) **[PENDIENTE DE PRUEBA EN DISPOSITIVO]**.

### 2.4 Cierre de Sesión Seguro (Logout)
- Al invocar `logout()`, el cliente invalida los tokens en el servidor de Supabase, limpia los proveedores de Riverpod en memoria (`userNameProvider`, `profileTypeProvider`, `selectedMunicipalityProvider`, etc.) y redirige mediante `context.go(AppRoutes.welcome)` **[PROPUESTO]**.
- El historial de navegación de `go_router` se reinicia para impedir que el botón "Atrás" de Android recupere vistas privadas anteriores **[PROPUESTO]**.

### 2.5 Eliminación de Cuenta y Tratamiento de Reportes (RF-06)
- El usuario puede solicitar la eliminación definitiva de su cuenta desde la pantalla de Perfil **[PROPUESTO]**.
- **Estrategia de Anonimización Integral (Habeas Data - Ley 1581 de 2012):**
  - La eliminación borra el registro en `auth.users`, lo que desencadena la eliminación en cascada (`ON DELETE CASCADE`) de su registro en `profiles` y de sus solicitudes en `interest_registrations`.
  - **Desvinculación relacional y depuración de PII [PROPUESTO]:** La clave foránea `price_reports.user_id` utiliza `ON DELETE SET NULL`. Sin embargo, para satisfacer los estándares de la Ley 1581 de 2012 y garantizar la anonimización completa:
    1. Se vacían los campos de texto libre (`source_note = NULL`) para impedir la persistencia de nombres o datos identificables introducidos por el usuario.
    2. Las coordenadas geográficas exactas (`location`) de reportes asociados a domicilios privados se disocian o generalizan al centroide municipal, conservando únicamente `municipality_code` y `category_id`.
    3. El registro numérico histórico (`amount_cop`, fecha y categoría) se preserva de manera irreversiblemente disociada para el cálculo de la mediana comunitaria de 60 días.

---

## 3. Modelo de Privacidad y Consentimiento (Habeas Data)

### 3.1 Consentimiento Explícito y Versionado
- Antes de completar el registro o continuar con Google, el usuario debe aceptar expresamente los Términos de Servicio y la Política de Privacidad **[IMPLEMENTADO EN UI / VALIDACIÓN]**.
- Se almacena un registro inmutable en la tabla `consents` con `user_id`, `doc_type`, `version` y `accepted_at` **[PROPUESTO EN MIGRACIÓN]**.
- Si los términos se actualizan a una versión posterior (ej. `v2.0`), la aplicación presentará una pantalla de re-consentimiento obligatorio antes de permitir nuevas acciones **[PROPUESTO]**.

### 3.2 Privacidad Geoespacial de Precios
- Los reportes de precios en `price_reports` permiten asociar una ubicación GPS (`location`).
- **Ofuscación de Privacidad:** Para evitar la trazabilidad de la rutina del usuario, la interfaz solo solicita coordenadas aproximadas a nivel de calle o sector comercial (`place_name`), sin persistir la ruta de desplazamiento ni identificadores de hardware **[PROPUESTO]**.

---

## 4. Matriz de Autorización y Políticas RLS (Row Level Security)

Todas las tablas de la base de datos deben tener RLS activado de forma obligatoria (`ALTER TABLE <tabla> ENABLE ROW LEVEL SECURITY;`) **[PROPUESTO]**.

| Tabla | Operación | Rol Permitido | Condición de Política RLS | Estado |
|---|---|---|---|---|
| `profiles` | SELECT | `authenticated` | `id = auth.uid()` (lectura privada de perfil propio) | **[IMPLEMENTADO EN feature/supabase-init]** |
| `profiles` | UPDATE | `authenticated` | `id = auth.uid()` (solo fila propia mediante política RLS; restricciones por columna por GRANT son propuestas) | **[IMPLEMENTADO EN feature/supabase-init]** |
| `admin_users` | ALL | `service_role` | Sin políticas para anon/authenticated; evaluada por `is_admin()` | **[IMPLEMENTADO EN feature/supabase-init]** |
| `consents` | SELECT | `authenticated` | `auth.uid() = user_id` | **[IMPLEMENTADO EN feature/supabase-init]** |
| `consents` | INSERT | `authenticated` | `auth.uid() = user_id` | **[IMPLEMENTADO EN feature/supabase-init]** |
| `departments` | SELECT | `anon`, `authenticated`| `true` (lectura pública) | **[IMPLEMENTADO EN feature/supabase-init]** |
| `municipalities`| SELECT| `anon`, `authenticated`| `true` (lectura pública) | **[IMPLEMENTADO EN feature/supabase-init]** |
| `price_reports` | SELECT | `anon`, `authenticated` | `is_hidden = false AND is_demo = false` | **[PROPUESTO]** |
| `price_reports` | INSERT | `authenticated` | `auth.uid() = user_id` | **[PROPUESTO]** |
| `price_reports` | UPDATE / DELETE | `authenticated` | `auth.uid() = user_id AND created_at > now() - INTERVAL '24 hours'` | **[PROPUESTO]** |
| `businesses` | SELECT | `anon`, `authenticated` | `status = 'approved' OR auth.uid() = owner_id` | **[PROPUESTO]** |
| `businesses` | INSERT | `authenticated` | `auth.uid() = owner_id AND status = 'pending'` | **[PROPUESTO]** |
| `businesses` | UPDATE | `authenticated` | `auth.uid() = owner_id AND status IN ('pending', 'approved')` *(sin alterar status)* | **[PROPUESTO]** |
| `ai_usage` | ALL | `service_role` | Exclusivo de Edge Function (inaccesible vía REST client) | **[PROPUESTO]** |
| `interest_registrations` | INSERT | `authenticated` | `auth.uid() = user_id` | **[PROPUESTO]** |

### 4.1 Separación Administrativa y Prevención de Escalada de Privilegios
- Siguiendo la arquitectura implementada por backend en `admin_users`, **los usuarios no poseen columna de rol en `profiles`** **[IMPLEMENTADO]**.
- La pertenencia a `admin_users` se administra directamente en el servidor sin políticas RLS públicas y es evaluada mediante la función segura `public.is_admin()` **[IMPLEMENTADO]**.
- **Distinción entre RLS y permisos a nivel de columna:**
  - La migración `20261027151910_profiles_and_consents.sql` implementa la política RLS a nivel de fila `profiles_update_own` (`using (id = auth.uid()) with check (id = auth.uid())`) **[IMPLEMENTADO]**.
  - La restricción de actualización por columna mediante permisos SQL GRANT es una propuesta de defensa en profundidad para VJ-07 **[PROPUESTO]**, que impedirá modificar columnas del sistema:
    ```sql
    -- Propuesta complementaria para VJ-07 (a incorporar por backend):
    REVOKE UPDATE ON public.profiles FROM authenticated;
    GRANT UPDATE (display_name, origin_country, current_municipality_code, language, profile_type) ON public.profiles TO authenticated;
    ```
- **Auditoría de autoría y descarte de funciones públicas:**
  - Se evaluó y descartó la creación de funciones `SECURITY DEFINER` de consulta de nombres por UUID (como `get_public_author_name()`), dado que facilitan la enumeración y cosecha masiva de PII eludiendo RLS. En el MVP, los aportes a precios son agregados estadísticos y la identidad del autor permanece **estrictamente privada** **[DECISIÓN DE SEGURIDAD]**.

---

## 5. Seguridad en Integraciones Externas

### 5.1 Google Maps API Key
- La clave de Google Maps en el archivo `AndroidManifest.xml` de Android es técnicamente visible mediante descompilación del APK.
- **Mitigación estricta [PROPUESTO / PENDIENTE DE CONFIGURACIÓN EN GCP]:**
  1. Restricción en Google Cloud Console por nombre de paquete definitivo (`applicationId`) y huella digital SHA-1 (debug y release).
  2. Restricción por APIs estrictamente requeridas (*Maps SDK for Android* y *Places API*).
  3. Alertas de presupuesto diarias en GCP para evitar sobrecostos por uso anómalo.

### 5.2 Edge Function de Gemini y Protección contra Prompt Injection
- El cliente móvil nunca se comunica directamente con la API de Google Gemini **[PROPUESTO]**.
- La llamada pasa a través de la Edge Function `analyze_contract`.
- La Edge Function aplica:
  1. Verificación del JWT de sesión del usuario.
  2. Validación de cuota diaria en `ai_usage` (máximo 5 llamadas/día por usuario).
  3. Sanitización del texto de entrada (máximo 15.000 caracteres).
  4. Instrucción de sistema inyectada por el servidor que ordena al LLM actuar como analizador legal neutral, desestimando cualquier comando que intente alterar su comportamiento (*system prompt defense*).
