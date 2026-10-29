# Backend Vía Justa — Supabase

Documentación operativa del backend (responsable: backend/Isaac). El frontend no
debe importar ni consultar esta carpeta directamente; solo consume el contrato
de datos y las RPC/Edge Functions acordadas.

## Estructura

```text
supabase/
├── config.toml                  # Configuración local del CLI (sin secretos)
├── .gitignore                   # Ignora .branches y .temp
├── migrations/                  # Migraciones SQL numeradas (fuente de verdad)
│   ├── 20261027151907_extensions_and_geography.sql
│   ├── 20261027151910_profiles_and_consents.sql
│   ├── 20261029100000_price_catalog.sql
│   ├── 20261029101000_price_reports_and_events.sql
│   └── 20261029102000_businesses_and_content.sql
├── seed/                        # Datos iniciales idempotentes
│   ├── 01_departments.sql
│   ├── 02_municipalities.sql
│   ├── 03_municipality_zones.sql
│   ├── 04_price_categories.sql
│   ├── 05_app_config.sql
│   └── 06_events_demo.sql
└── tests/
    └── rls.sql                  # Pruebas pgTAP de RLS y constraints
```

## Requisitos

- Supabase CLI 2.101 o superior.
- Docker Desktop con backend WSL2 en ejecución.
- Proyecto Supabase remoto ya vinculado (`supabase link`).

## Flujo local

```powershell
# 1. Levantar el stack local (PostgreSQL 17 + Auth + Storage + Studio)
supabase start

# 2. Aplicar migraciones y seeds desde cero
supabase db reset

# 3. Ejecutar las pruebas de RLS/constraints
supabase test db

# 4. Detener el stack
supabase stop
```

`supabase db reset` ejecuta, en orden:

1. `supabase/migrations/*.sql` (orden lexicográfico).
2. `supabase/seed/*.sql` (orden lexicográfico por el prefijo `01_`…`06_`).

## Aplicar al proyecto remoto

```powershell
# Requiere aprobación explícita del equipo antes de ejecutarlo.
supabase db push
```

Regla del proyecto: **ningún cambio manual** en tablas, RLS o funciones desde el
panel web de Supabase. Todo cambio debe ser una migración versionada e inmutable.

## Seguridad

- La app móvil usa únicamente la clave pública `anon`.
- `service_role` solo vive en Edge Functions y scripts administrativos.
- Nunca se versionan `.env`, `key.properties`, `*.jks`, claves de Gemini ni de
  Google Maps.
- RLS activo en las 16 tablas de `public`; los catálogos son de solo lectura para
  `anon`/`authenticated`.

## Estado VJ-07

- Migraciones 0001–0005 creadas.
- Seeds 01–06 creadas (33 departamentos, 25 municipios del Cesar, 5 zonas de
  Valledupar, 4 categorías, configuración del semáforo y evento DEMO).
- Pruebas pgTAP en `supabase/tests/rls.sql` (21 aserciones).
- **Verificación local pendiente:** el daemon de Docker no estaba disponible en
  el entorno del 29/10/2026. Ejecutar `supabase db reset` y `supabase test db`
  antes de declarar VJ-07 como `HECHO-VERIFICADO`.
- **No se ha aplicado al proyecto remoto.**

## Convenciones

- Tablas en plural y `snake_case`; PK `uuid` salvo catálogos (`code`, `id` textual).
- Montos COP como `integer` positivo; fechas con `timestamptz`.
- Códigos DANE/DIVIPOLA como `text` para preservar ceros.
- Toda regla de negocio del semáforo vive en SQL (VJ-10), nunca en el cliente.
