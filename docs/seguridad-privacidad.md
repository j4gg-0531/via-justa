# Política de Seguridad, Autenticación y Privacidad de Datos — Vía Justa MVP

## 1. Principios Rectores de Seguridad

1. **Defensa en Profundidad:** La seguridad no recae exclusivamente en la aplicación móvil; las reglas de autorización residen de forma innegociable en la base de datos (PostgreSQL Row Level Security) y en las Edge Functions.
2. **Principio de Mínimo Privilegio:** La aplicación Flutter utiliza exclusivamente la clave anónima pública (`anon_key`) de Supabase. **La clave de servicio (`service_role_key`) nunca se empaqueta, referencia ni transmite al cliente móvil**.
3. **No Retención de Datos Contractuales (RN-10):** Los contratos analizados por el motor de IA no se almacenan en bases de datos ni en discos persistentes; el texto viaja en memoria cifrado en tránsito (TLS 1.3) y se descarta inmediatamente tras la respuesta estructurada de Gemini.
4. **Cumplimiento Normativo Colombiano:** Tratamiento de datos personales enmarcado en el Régimen General de Protección de Datos Personales (Ley Estatutaria 1581 de 2012 y Decreto 1377 de 2013).

---

## 2. Ciclo de Vida de Autenticación y Sesión

### 2.1 Proveedores Soportados
- **Correo y Contraseña:** Registro y login directo vía Supabase Auth.
- **Google OAuth:** Inicio de sesión federado mediante Google Sign-In SDK / Supabase Auth.

### 2.2 Registro y Política de Contraseñas
- **Validación Local:** La contraseña debe contener mínimo 8 caracteres (validado por `auth_validators.dart`).
- **Verificación de Correo:**
  - *Entorno de Desarrollo / Pruebas:* Auto-confirmación habilitada para facilitar la evaluación sin dependencias SMTP.
  - *Entorno de Producción:* Envío de enlace de verificación por correo electrónico. El usuario no podrá emitir reportes de precios ni registrar negocios hasta confirmar su cuenta.

### 2.3 Persistencia y Renovación de Sesión
- Supabase Auth gestiona el almacenamiento seguro del *Refresh Token* en el almacén seguro nativo del sistema operativo (Android Keystore / EncryptedSharedPreferences).
- El cliente móvil intercepta automáticamente la expiración del *Access Token* JWT (1 hora de vigencia típica) y solicita su renovación silenciosa en segundo plano.

### 2.4 Cierre de Sesión Seguro (Logout)
- Al invocar `logout()`, el cliente invalida los tokens en el servidor de Supabase, limpia los proveedores de Riverpod en memoria (`userNameProvider`, `profileTypeProvider`, `selectedMunicipalityProvider`, etc.) y redirige mediante `context.go(AppRoutes.welcome)`.
- El historial de navegación de `go_router` se reinicia para impedir que el botón "Atrás" de Android recupere vistas privadas anteriores.

### 2.5 Eliminación y Derecho al Olvido (RF-06)
- El usuario puede solicitar la eliminación definitiva de su cuenta desde la pantalla de Perfil.
- La ejecución borra el registro en `auth.users`, lo que desencadena la eliminación en cascada (`ON DELETE CASCADE`) de su registro en `profiles`, sus registros de interés en `interest_registrations` y desvincula sus reportes de precios (anonimizándolos como aportes comunitarios sin autor).

---

## 3. Modelo de Privacidad y Consentimiento (Habeas Data)

### 3.1 Consentimiento Explícito y Versionado
- Antes de completar el registro o continuar con Google, el usuario debe aceptar expresamente los Términos de Servicio y la Política de Privacidad.
- Se almacena un registro inmutable en la tabla `consents` con:
  - `user_id`: Identificador del usuario.
  - `doc_type`: Documento consentido.
  - `version`: Versión exacta del texto legal aceptado (ej. `v1.0`).
  - `accepted_at`: Marca de tiempo certificada por el servidor (`now()`).
- Si los términos se actualizan a una versión `v2.0`, la aplicación presentará una pantalla de re-consentimiento obligatorio antes de permitir nuevas acciones.

### 3.2 Privacidad Geoespacial de Precios
- Los reportes de precios en `price_reports` permiten asociar una ubicación GPS (`location`).
- **Ofuscación de Privacidad:** Para evitar la trazabilidad de la rutina del usuario, la interfaz solo solicita coordenadas aproximadas a nivel de calle o sector comercial (`place_name`), sin persistir la ruta de desplazamiento ni identificadores de hardware.

---

## 4. Matriz de Autorización y Políticas RLS (Row Level Security)

Todas las tablas de la base de datos deben tener RLS activado de forma obligatoria (`ALTER TABLE <tabla> ENABLE ROW LEVEL SECURITY;`).

| Tabla | Operación | Rol Permitido | Condición de Política RLS |
|---|---|---|---|
| `profiles` | SELECT | `anon`, `authenticated` | `true` (datos públicos como display_name y municipio) |
| `profiles` | UPDATE | `authenticated` | `auth.uid() = id` (solo su propio registro, rol inmutable) |
| `consents` | SELECT | `authenticated` | `auth.uid() = user_id` |
| `consents` | INSERT | `authenticated` | `auth.uid() = user_id` |
| `price_reports` | SELECT | `anon`, `authenticated` | `is_hidden = false AND is_demo = false` |
| `price_reports` | INSERT | `authenticated` | `auth.uid() = user_id` |
| `price_reports` | UPDATE / DELETE | `authenticated` | `auth.uid() = user_id AND created_at > now() - INTERVAL '24 hours'` |
| `businesses` | SELECT | `anon`, `authenticated` | `status = 'approved' OR auth.uid() = owner_id` |
| `businesses` | INSERT | `authenticated` | `auth.uid() = owner_id AND status = 'pending'` |
| `businesses` | UPDATE | `authenticated` | `auth.uid() = owner_id AND status IN ('pending', 'approved')` *(sin alterar status)* |
| `ai_usage` | ALL | `service_role` | Exclusivo de Edge Function (inaccesible vía REST client) |
| `interest_registrations` | INSERT | `authenticated` | `auth.uid() = user_id` |

### 4.1 Inmutabilidad de Roles y Prevención de Escalada de Privilegios
- Un usuario común (`authenticated_user`) **bajo ninguna circunstancia puede asignarse el rol `admin`**.
- La columna `profiles.role` solo puede ser modificada por un administrador autenticado o mediante un trigger de base de datos con verificación de claims en `auth.users`.

---

## 5. Seguridad en Integraciones Externas

### 5.1 Google Maps API Key
- La clave de Google Maps en el archivo `AndroidManifest.xml` de Android es técnicamente visible mediante decompilación del APK.
- **Mitigación estricta:** La clave en Google Cloud Console debe estar restringida exclusivamente a:
  1. La aplicación Android mediante su nombre de paquete definitivo (`applicationId`) y la huella digital SHA-1 del certificado de firma (tanto debug como release).
  2. Las APIs estrictamente requeridas: *Maps SDK for Android* y *Places API (New)*.
  3. Alertas de presupuesto diarias en GCP para evitar sobrecostos por uso anómalo.

### 5.2 Edge Function de Gemini y Protección contra Prompt Injection
- El cliente móvil nunca se comunica directamente con la API de Google Gemini.
- La llamada pasa a través de la Edge Function `analyze_contract`.
- La Edge Function aplica:
  1. Verificación del JWT de sesión del usuario.
  2. Validación de cuota diaria en `ai_usage` (máximo 5 llamadas/día por usuario).
  3. Sanitización del texto de entrada (máximo 15.000 caracteres).
  4. Instrucción de sistema inyectada por el servidor que ordena al LLM actuar como analizador legal neutral, desestimando cualquier comando que intente alterar su comportamiento (*system prompt defense*).
