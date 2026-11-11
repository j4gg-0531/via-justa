# Guía Operativa de Respaldo, Restauración, Rotación de Secretos y Mantenimiento — Backend Vía Justa MVP (`VJ-18`)

> **Propósito:** Definir los procedimientos seguros y reproducibles en Windows (PowerShell) para respaldar el esquema y los datos del proyecto Supabase (`vjehsjqmwibmiqmxlsou`), verificar una restauración en entorno local aislado sin poner en riesgo producción, rotar credenciales críticas y limpiar objetos huérfanos de Storage.

---

## 1. Reglas de Oro de Operación Segura

1. **Prohibición de comandos destructivos en remoto:** Jamás ejecutar `supabase db reset --linked` ni truncar tablas sobre el proyecto remoto de producción/evaluación. `supabase db reset` se utiliza **exclusivamente** sobre el contenedor Docker local desechable.
2. **Custodia de secretos fuera de Git:** Ningún archivo `.dump`, `.sql` con datos de usuarios reales (`auth.users`), `.env`, `key.properties` ni `.jks` debe ubicarse dentro de carpetas rastreadas por Git. Los respaldos deben almacenarse en una carpeta externa cifrada del responsable del proyecto (p. ej. `D:\Backups_ViaJusta\`).
3. **Migraciones inmutables hacia adelante (*forward-only*):** Cualquier ajuste de esquema o política RLS se aplica mediante una nueva migración con marca temporal en `supabase/migrations/` probada primero en local con `supabase test db`.

---

## 2. Procedimiento de Respaldo Lógico (Backup)

### 2.1 Respaldo de roles, esquema y datos desde Supabase Cloud
Ejecutar desde PowerShell en la raíz del repositorio (`D:\Proyectos Movil\Proyecto de aula\via-justa`), guardando los artefactos **fuera del repositorio**:

```powershell
# 1. Crear directorio externo con marca de fecha
$BackupDate = Get-Date -Format "yyyyMMdd_HHmm"
$BackupDir  = "D:\Backups_ViaJusta\backup_$BackupDate"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

# 2. Exportar roles de base de datos
supabase db dump --linked -f "$BackupDir\01_roles.sql" --role-only

# 3. Exportar esquema completo (tablas, tipos, funciones, triggers, políticas RLS)
supabase db dump --linked -f "$BackupDir\02_schema.sql"

# 4. Exportar datos de aplicación (esquema public y catálogos/reportes/negocios)
supabase db dump --linked -f "$BackupDir\03_data.sql" --data-only --use-copy

# 5. Generar hashes SHA-256 de integridad del respaldo
Get-FileHash "$BackupDir\*.sql" -Algorithm SHA256 | Format-Table Hash, Path
```

### 2.2 Verificación del estado de migraciones sincronizadas
Antes y después de cada ventana de mantenimiento, verificar que la tabla `supabase_migrations.schema_migrations` coincida al 100 % entre local y remoto:

```powershell
supabase migration list
```

---

## 3. Simulacro de Restauración Segura en Entorno Local (Restore Drill)

Para comprobar que las migraciones, semillas y respaldos son 100 % recuperables sin tocar la nube:

```powershell
# 1. Asegurar que Docker Desktop esté activo y levantar el entorno local aislado
supabase start

# 2. Reconstruir desde cero el contenedor local aplicando todas las migraciones + seeds
supabase db reset

# 3. Ejecutar la batería completa de pruebas automatizadas pgTAP (9 suites)
supabase test db
```

Si se desea restaurar un volcado de datos específico (`03_data.sql`) sobre el contenedor local para auditoría forense:

```powershell
$OutputEncoding = [System.Text.Encoding]::UTF8
Get-Content "D:\Backups_ViaJusta\backup_<FECHA>\03_data.sql" -Raw -Encoding UTF8 |
  docker exec -i supabase_db_via-justa psql -U postgres -d postgres -v ON_ERROR_STOP=1
```

---

## 4. Rotación de Secretos y Credenciales (`VJ-18`)

En caso de sospecha de exposición o rotación programada de credenciales:

### 4.1 Clave de API de Google Gemini (`GEMINI_API_KEY`)
1. Generar una nueva clave en Google AI Studio restringida al proyecto.
2. Actualizar el secreto en Supabase Cloud sin exponerlo en código ni historial de consola:
   ```powershell
   supabase secrets set GEMINI_API_KEY="<NUEVA_CLAVE_GEMINI>" --project-ref vjehsjqmwibmiqmxlsou
   ```
3. Revocar inmediatamente la clave anterior en Google AI Studio.
4. Verificar el funcionamiento invocando las pruebas de la Edge Function (`analyze_contract`).

### 4.2 Clave de Google Maps SDK para Android (`MAPS_API_KEY`)
1. En Google Cloud Console → *APIs & Services → Credentials*, restringir la clave por:
   - **Application restrictions:** *Android apps* → `applicationId` definitivo + huella **SHA-1 de debug** y **SHA-1 de release**.
   - **API restrictions:** Exclusivamente *Maps SDK for Android*.
2. Actualizar únicamente el archivo local ignorado `android/local.properties`:
   ```properties
   MAPS_API_KEY=<NUEVA_CLAVE_MAPS_RESTRINGIDA>
   ```

### 4.3 Claves de Supabase (`anon` / `service_role`)
- La aplicación móvil solo recibe `SUPABASE_URL` y `SUPABASE_ANON_KEY` por `--dart-define`.
- `SUPABASE_SERVICE_ROLE_KEY` jamás se almacena en el repositorio ni en el cliente; Supabase la inyecta automáticamente en el entorno interno de la Edge Function `analyze_contract`.

---

## 5. Mantenimiento de Archivos Huérfanos en Storage (`business-media`)

Cuando un usuario elimina su cuenta (`public.delete_my_account()`) o elimina un negocio, o cuando una subida de imagen se interrumpe antes de vincularse en `public.business_photos`, el trigger interno de Supabase Storage (`storage.protect_objects_delete`) impide borrar binarios directamente desde SQL.

Para auditar y purgar estos objetos huérfanos de forma segura:

1. **Consultar objetos huérfanos desde consola SQL o rol administrador:**
   ```sql
   select *
   from public.list_orphan_business_media(interval '24 hours');
   ```
   - `reason = 'business_deleted'`: el negocio propietario (o la cuenta del dueño) fue eliminado.
   - `reason = 'not_linked_to_business_photos'`: archivo subido hace más de 24 horas que nunca se asoció a una posición del negocio.
2. **Eliminar los objetos listados** a través del panel de *Storage → business-media* en Supabase Studio o invocando la API oficial `supabase.storage.from('business-media').remove([object_name])` con una sesión administrativa.
