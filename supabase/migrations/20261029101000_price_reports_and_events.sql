-- ============================================================================
-- Vía Justa MVP · Migración 0004 · Reportes de precio, eventos, configuración
-- ============================================================================
-- Crea:
--   * public.price_reports: aportes ciudadanos de precios por zona.
--   * public.events: eventos activos que alteran la referencia estacional.
--   * public.app_config: umbrales y parámetros operativos (sin recompilar app).
--   * public.ai_usage: cuota diaria del análisis de contratos con IA.
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.6, §2.7, §2.8 y §2.9
--   docs/seguridad-privacidad.md §4
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Reportes de precio
-- ---------------------------------------------------------------------------
create table if not exists public.price_reports (
  id uuid primary key default gen_random_uuid(),
  -- Si la cuenta se elimina, el reporte se conserva sin identidad (ON DELETE SET NULL).
  user_id uuid references auth.users(id) on delete set null,
  category_id varchar(50) not null
    references public.price_categories(id)
    on update cascade
    on delete restrict,
  municipality_code text not null
    references public.municipalities(code)
    on update cascade
    on delete restrict,
  zone_id varchar(50) not null,
  amount_cop integer not null check (amount_cop > 0),
  location geography(Point, 4326),
  place_name varchar(150),
  is_seed boolean not null default false,
  is_demo boolean not null default false,
  is_hidden boolean not null default false,
  source_note varchar(255),
  created_at timestamptz not null default now(),
  -- La zona debe pertenecer al mismo municipio del reporte.
  constraint price_reports_zone_municipality_fk
    foreign key (zone_id, municipality_code)
    references public.municipality_zones(id, municipality_code)
    on update cascade
    on delete restrict
);

comment on table public.price_reports is
  'Aportes ciudadanos de precios. La mediana se calcula en la RPC, nunca en el cliente.';

create index if not exists price_reports_stat_idx
  on public.price_reports (municipality_code, zone_id, category_id, created_at)
  where is_hidden = false and is_demo = false;

create index if not exists price_reports_location_idx
  on public.price_reports using gist (location);

create index if not exists price_reports_user_idx
  on public.price_reports (user_id);

alter table public.price_reports enable row level security;

-- Cualquiera puede leer reportes públicos (no ocultos, no demo).
drop policy if exists price_reports_select_public on public.price_reports;
create policy price_reports_select_public
  on public.price_reports
  for select
  to anon, authenticated
  using (is_hidden = false and is_demo = false);

-- El autor siempre puede ver sus propios reportes (incluidos demo u ocultos).
drop policy if exists price_reports_select_own on public.price_reports;
create policy price_reports_select_own
  on public.price_reports
  for select
  to authenticated
  using (user_id = auth.uid());

-- El cliente solo inserta reportes a su propio nombre.
drop policy if exists price_reports_insert_own on public.price_reports;
create policy price_reports_insert_own
  on public.price_reports
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Edición/borrado solo por el autor y solo durante las primeras 24 horas.
drop policy if exists price_reports_update_own_recent on public.price_reports;
create policy price_reports_update_own_recent
  on public.price_reports
  for update
  to authenticated
  using (user_id = auth.uid() and created_at > now() - interval '24 hours')
  with check (user_id = auth.uid());

drop policy if exists price_reports_delete_own_recent on public.price_reports;
create policy price_reports_delete_own_recent
  on public.price_reports
  for delete
  to authenticated
  using (user_id = auth.uid() and created_at > now() - interval '24 hours');

revoke all on public.price_reports from anon, authenticated;
grant select on public.price_reports to anon, authenticated;
grant insert, update, delete on public.price_reports to authenticated;

-- ---------------------------------------------------------------------------
-- Eventos (festivales, ferias, temporadas)
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  municipality_code varchar(5) not null
    references public.municipalities(code)
    on update cascade
    on delete cascade,
  name varchar(150) not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_demo boolean not null default false,
  constraint events_dates_check check (ends_at >= starts_at)
);

comment on table public.events is
  'Eventos por municipio. is_demo = true impide presentarlos como datos reales.';

create index if not exists events_dates_idx
  on public.events (municipality_code, starts_at, ends_at);

alter table public.events enable row level security;

drop policy if exists events_select_public on public.events;
create policy events_select_public
  on public.events
  for select
  to anon, authenticated
  using (true);

revoke all on public.events from anon, authenticated;
grant select on public.events to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Configuración operativa (umbrales, ventanas, cuotas)
-- ---------------------------------------------------------------------------
create table if not exists public.app_config (
  key varchar(50) primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_config is
  'Parámetros operativos versionables (umbrales 15/40, N=3, ventana 60 días, factor 1.15).';

drop trigger if exists app_config_set_updated_at on public.app_config;
create trigger app_config_set_updated_at
  before update on public.app_config
  for each row
  execute function public.set_updated_at();

alter table public.app_config enable row level security;

drop policy if exists app_config_select_authenticated on public.app_config;
create policy app_config_select_authenticated
  on public.app_config
  for select
  to authenticated
  using (true);

revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to authenticated;

-- ---------------------------------------------------------------------------
-- Cuota de uso de IA (exclusiva de la Edge Function con service_role)
-- ---------------------------------------------------------------------------
create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  count integer not null default 1 check (count >= 0),
  primary key (user_id, day)
);

comment on table public.ai_usage is
  'Contador atómico de análisis de contratos por usuario/día. Inaccesible desde el cliente.';

alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon, authenticated;
