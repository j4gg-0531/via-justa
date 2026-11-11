# Protocolo de Entrega Android Release, Firma, Credenciales Cloud y Recuperación — Vía Justa MVP (`VJ-20`)

> **Alcance y Responsabilidad:**  
> Este documento establece el procedimiento reproducible en Windows (PowerShell) para empaquetar, firmar, restringir credenciales de nube (Supabase Auth, Google Maps SDK, Google OAuth y Gemini Edge Function), verificar en teléfono Android real y respaldar el proyecto para la entrega de producción (`VJ-20`).  
> *Nota de estado actual:* En el árbol de código actual, `android/app/build.gradle.kts` conserva temporalmente `applicationId = "com.example.via_justa"` y firma con llave debug para pruebas locales de desarrollo. La migración del paquete y del `signingConfig` de release en Gradle debe ejecutarse en coordinación con el responsable de Frontend una vez el equipo confirme el identificador definitivo (p. ej. `co.viajusta.app`).

---

## 1. Definición de Identidad del Paquete (`applicationId` y `namespace`)

Antes de generar el APK definitivo o registrar clientes OAuth de producción:

1. **Identificador actual (Desarrollo):** `com.example.via_justa`
2. **Identificador objetivo (Release):** Definir con el equipo un dominio inverso propio (ej. `co.viajusta.app` o `edu.unicesar.viajusta`).
3. **Archivos de Frontend impactados al cambiar el `applicationId`:**
   - `android/app/build.gradle.kts` (`namespace` y `defaultConfig.applicationId`).
   - Ruta del paquete de `MainActivity.kt` bajo `android/app/src/main/kotlin/...`.
   - Reglas de restricción de API Key en Google Cloud Console y Redirect URIs en Supabase Auth.

---

## 2. Generación Segura del Keystore de Release (Fuera del Repositorio)

**Regla de Seguridad (`PLAN_MAESTRO §0.7 y §VJ-20`):** El archivo `.jks` / `.keystore` y sus contraseñas **jamás** deben guardarse dentro del repositorio ni enviarse por chat o commits.

### 2.1 Crear el Keystore en una ruta local custodiada por el propietario
Ejecutar en PowerShell (usando el `keytool` incluido en el JDK 17 de Android Studio):

```powershell
$KeystoreDir = "D:\Keystores_ViaJusta"
New-Item -ItemType Directory -Force -Path $KeystoreDir | Out-Null

& keytool -genkey -v `
  -keystore "$KeystoreDir\via-justa-release.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias via_justa_key
```

### 2.2 Configurar `android/key.properties` (Ignorado por Git)
Crear el archivo `android/key.properties` (protegido por `.gitignore`):

```properties
storePassword=<CONTRASENA_DEL_KEYSTORE>
keyPassword=<CONTRASENA_DE_LA_LLAVE>
keyAlias=via_justa_key
storeFile=D:/Keystores_ViaJusta/via-justa-release.jks
```

### 2.3 Obtener Huellas Digitales `SHA-1` y `SHA-256` (Debug vs. Release)
Es obligatorio extraer **ambas** huellas, ya que Google Maps y Google Sign-In fallarán silenciosamente en el APK `--release` si solo está autorizada la huella de `debug`:

```powershell
# Huella SHA-1 y SHA-256 del Keystore de RELEASE
& keytool -list -v -keystore "D:\Keystores_ViaJusta\via-justa-release.jks" -alias via_justa_key

# Huella SHA-1 y SHA-256 del Keystore de DEBUG
& keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

## 3. Alineación de Backend y Credenciales Cloud para el Release (`VJ-20`)

### 3.1 Google Cloud Console — Restricción de `MAPS_API_KEY`
1. Ingresar a *Google Cloud Console → APIs & Services → Credentials*.
2. Seleccionar la API Key inyectada en `android/local.properties` (`MAPS_API_KEY`).
3. En **Application restrictions**, seleccionar **Android apps** y agregar dos entradas:
   - Entrada Debug: `<applicationId>` + huella `SHA-1` de debug.
   - Entrada Release: `<applicationId>` + huella `SHA-1` de release.
4. En **API restrictions**, seleccionar **Restrict key** y marcar únicamente:
   - `Maps SDK for Android`
5. En *Billing → Budgets & alerts*, mantener activa la alerta de presupuesto diario para evitar cobros inesperados.

### 3.2 Supabase Auth y Deep Links (`vjehsjqmwibmiqmxlsou`)
1. En el panel de Supabase (*Authentication → URL Configuration*):
   - Configurar **Site URL** y **Redirect URLs** con el esquema de callback de la aplicación Android (ej. `io.supabase.viajusta://login-callback/` o el esquema definido en `AndroidManifest.xml`).
2. Si se habilita **Google OAuth** (*Authentication → Providers → Google*):
   - Registrar en Google Cloud Console un cliente OAuth 2.0 tipo **Android** con el `<applicationId>` y el `SHA-1` de **release**, y un cliente tipo **Web application** cuyo Redirect URI apunte a `https://vjehsjqmwibmiqmxlsou.supabase.co/auth/v1/callback`.

### 3.3 Checklist de Backend Previo al Empaquetado Release
Antes de compilar el APK de entrega, verificar desde la raíz del proyecto:

```powershell
# 1. Confirmar que las 14 migraciones (VJ-07 a VJ-18) están sincronizadas en Supabase Cloud
supabase migration list --linked

# 2. Confirmar que la Edge Function analyze_contract está activa y desplegada
supabase functions list --project-ref vjehsjqmwibmiqmxlsou

# 3. Ejecutar respaldo completo de esquema y datos previo al release (ver docs/backend/guia-respaldo-restauracion.md)
```

---

## 4. Permisos Mínimos en `AndroidManifest.xml`

El manifiesto de release debe declarar únicamente los permisos estrictamente requeridos por las funcionalidades reales del MVP:

| Permiso Android | Justificación en Vía Justa MVP | Obligatoriedad |
|---|---|---|
| `android.permission.INTERNET` | Comunicación HTTPS con Supabase (Auth, PostgREST, Storage, Edge Function) y descarga de tiles de Google Maps | **Obligatorio** |
| `android.permission.ACCESS_NETWORK_STATE` | Detección de conectividad por plugins de red y ML Kit | **Obligatorio** |
| `android.permission.ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` | Detección de zona urbana en el semáforo de precios y ubicación en el mapa de Valledupar (siempre precedida de aviso en UI y con fallback manual sin GPS) | **Condicional (con fallback manual)** |

> **Nota sobre Cámara y Archivos (`VJ-13`):** La captura de contratos utiliza el *Photo Picker* / *Activity Result* del sistema (`image_picker` y `file_picker`) precedido por el diálogo de consentimiento propio de la app (`RN-10`), por lo que no exige declarar permisos intrusivos de almacenamiento global ni `READ_EXTERNAL_STORAGE` en Android moderno.

---

## 5. Compilación, Verificación de Firma e Instalación en Teléfono Físico

### 5.1 Compilación del APK Firmado (`--release`)
Nunca empaquetar `SUPABASE_SERVICE_ROLE_KEY` ni `GEMINI_API_KEY` en `--dart-define`. Pasar únicamente la URL del proyecto y la llave pública `anon`:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test

flutter build apk --release `
  --dart-define=SUPABASE_URL=https://vjehsjqmwibmiqmxlsou.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<SUPABASE_PUBLIC_ANON_KEY>
```

### 5.2 Verificación Criptográfica del APK y Hash `SHA-256`
Comprobar que el artefacto generado en `build\app\outputs\flutter-apk\app-release.apk` NO esté firmado con certificado `CN=Android Debug`:

```powershell
# 1. Verificar certificado de firma del APK
& keytool -printcert -jarfile "build\app\outputs\flutter-apk\app-release.apk"

# 2. Generar hash SHA-256 oficial del artefacto para las notas de entrega
Get-FileHash "build\app\outputs\flutter-apk\app-release.apk" -Algorithm SHA256 | Format-List
```

### 5.3 Instalación por `adb` y Smoke Test en Dispositivo Android Real
Conectar el teléfono físico por USB con *Depuración por USB* activa:

```powershell
# 1. Verificar dispositivo detectado
& "C:\Android\Sdk\platform-tools\adb.exe" devices

# 2. Instalar APK de release (reemplazando versión previa si conserva firma)
& "C:\Android\Sdk\platform-tools\adb.exe" install -r "build\app\outputs\flutter-apk\app-release.apk"

# 3. Monitorear logs de errores fatales durante el recorrido smoke (sin imprimir tokens ni PII)
& "C:\Android\Sdk\platform-tools\adb.exe" logcat *:E
```

### 5.4 Recorrido Smoke Obligatorio (Con Internet y Sin Internet)
1. **Con Internet (Modo Real conectado a Supabase Cloud `vjehsjqmwibmiqmxlsou`):**
   - Registro/inicio de sesión real → aceptación de consentimiento (`consents`) → selección de perfil (`visitor`/`settler`/`resident`) → selección de Valledupar (`20001`).
   - Consulta del semáforo de precios en `vup_centro` → verificación de resultado estadístico (`calculate_price_verdict`).
   - Aporte de precio real en 4 pasos (`submit_price_report`) → verificación de actualización.
   - Mapa de precios y servicios (`get_municipality_map_items`) → renderizado de tiles de Google Maps con certificado de release.
   - Escaneo OCR local de contrato sintético → análisis con Gemini (`analyze_contract`) → descuento de cuota diaria (`get_my_ai_quota_status`).
   - Vista cultural de Valledupar (`get_city_overview` en `es`/`en`) → directorio de negocios aprobados (`get_business_catalog` y `get_business_detail`) → apertura de enlaces externos (`wa.me`, `tel:`, Google Maps).
   - Cierre de sesión limpio (`logout`) verificando que el botón "Atrás" de Android no regrese a pantallas privadas.
2. **Sin Internet (Modo Avión / Fallback):**
   - Verificar que la app no sufra *crash* ni pantallas blancas al perder red, mostrando estados de error traducidos con opción de reintentar o el modo DEMO explícitamente rotulado.

---

## 6. Plan de Rollback y Recuperación

1. **Rollback de Aplicación Móvil:** Conservar cada `app-release.apk` aprobado junto con su archivo `.sha256` y el `git tag` correspondiente (`v1.0.0-mvp`). Si una compilación nueva presenta fallos en el dispositivo físico, reinstalar el último APK firmado estable mediante `adb install -r`.
2. **Rollback / Recuperación de Backend:** Seguir el procedimiento documentado en [`docs/backend/guia-respaldo-restauracion.md`](backend/guia-respaldo-restauracion.md) empleando los volcados `01_roles.sql`, `02_schema.sql` y `03_data.sql`.
