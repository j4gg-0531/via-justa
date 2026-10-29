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
│   ├── 20261029102000_businesses_and_content.sql
│   ├── 20261029120000_close_vj07_vj08_d11_and_account_deletion.sql
│   ├── 20261029130000_price_verdict_rpc.sql
│   └── 20261029140000_price_reports_quotas_privacy_and_rpc.sql
├── seed/                        # Datos iniciales idempotentes
│   ├── 01_departments.sql
│   ├── 02_municipalities.sql
│   ├── 03_municipality_zones.sql
│   ├── 04_price_categories.sql
│   ├── 05_app_config.sql
│   ├── 06_events_demo.sql
│   └── 07_price_reports_demo.sql
└── tests/
    ├── price_reports_rls.sql    # Pruebas pgTAP de aportes, cuotas y privacidad (18 aserciones)
    ├── price_verdict.sql        # Pruebas pgTAP del semáforo SQL (23 aserciones)
    └── rls.sql                  # Pruebas pgTAP de RLS y constraints (26 aserciones)
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

## Estado VJ-07, VJ-08, VJ-10 y VJ-11 (Backend)

- Migraciones 0001–0008 creadas:
  - `0001`–`0005`: esquema base de 16 tablas, RLS y GRANTs.
  - `0006`: ratificación de D11 (`resident` en `profiles.profile_type`), defensa por columnas en `price_reports` y función RPC transaccional `delete_my_account()` (Ley 1581 / RF-06).
  - `0007`: función SQL `calculate_price_verdict` (y alias `evaluate_price_verdict`) como única fuente de verdad estadística del semáforo por zona (`VJ-10`).
  - `0008`: validaciones de servidor en `price_reports`, ofuscación de privacidad GPS a 3 decimales (~110 m), control de concurrencia (`pg_advisory_xact_lock`), anti-duplicado (15 min), cuota diaria (10 aportes/24h) y funciones RPC `submit_price_report` y `moderate_price_report` (`VJ-11`).
- Seeds 01–07 creadas (33 departamentos, 25 municipios del Cesar, 5 zonas de Valledupar, 4 categorías, configuración del semáforo/cuotas, evento DEMO y reportes DEMO segregados).
- Pruebas pgTAP en `supabase/tests/rls.sql` (26 aserciones), `supabase/tests/price_verdict.sql` (23 aserciones) y `supabase/tests/price_reports_rls.sql` (18 aserciones) -> **67/67 PASS**.
- **Verificado en local el 29/10/2026** (CLI 2.101.0 + Docker 29.5.2):
  `supabase start` OK, `supabase db reset` OK (8 migraciones + 7 seeds) y
  `supabase test db` con `Files=3, Tests=67, Result: PASS`.
- **No se ha aplicado al proyecto remoto** (`vjehsjqmwibmiqmxlsou`). Requiere
  aprobación explícita del equipo antes de ejecutar `supabase db push`.

## Convenciones

- Tablas en plural y `snake_case`; PK `uuid` salvo catálogos (`code`, `id` textual).
- Montos COP como `integer` positivo; fechas con `timestamptz`.
- Códigos DANE/DIVIPOLA como `text` para preservar ceros.
- Toda regla de negocio del semáforo vive en SQL (VJ-10), nunca en el cliente.

## Edge Function `analyze_contract` y Cuota Diaria (VJ-14)

- **Ubicación:** `supabase/functions/analyze_contract/` (`index.ts`, `contract_analyzer.ts`, `contract_analyzer_test.ts`, `deno.json`).
- **Migración de cuota:** `supabase/migrations/20261029150000_ai_usage_quota_rpc.sql` (`consume_ai_daily_quota`, `refund_ai_daily_quota` y `get_my_ai_quota_status` en zona horaria `America/Bogota`).
- **Pruebas:** `supabase/tests/ai_usage_quota.sql` (12 aserciones pgTAP) y pruebas unitarias en `contract_analyzer_test.ts`.
- **Variables de entorno requeridas en Supabase Secrets (nunca versionadas):**
  - `GEMINI_API_KEY`: clave privada de Google AI Studio / Gemini.
  - `GEMINI_MODEL` (opcional, por defecto `gemini-2.5-flash`).
