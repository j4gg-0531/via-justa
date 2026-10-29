-- ============================================================================
-- Vía Justa MVP · Migración 0001 · Extensiones y geografía DANE
-- ============================================================================
-- Crea:
--   * Extensiones: PostGIS (geografía), unaccent y pg_trgm (búsqueda sin tildes).
--   * public.departments: 32 departamentos + Bogotá D.C. (código DANE de 2 dígitos).
--   * public.municipalities: municipios con código DIVIPOLA de 5 dígitos.
--   * public.municipality_zones: zonas internas de municipios piloto para medianas.
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.3, §2.4 y §2.4.1
--   docs/modelo-er.puml
--
-- Nota: los catálogos geográficos se escriben únicamente por migraciones/seed
-- (rol service_role). El cliente móvil solo tiene SELECT.
-- ============================================================================

create extension if not exists postgis with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- Wrapper IMMUTABLE de unaccent para poder indexar búsquedas sin tildes.
-- (La función nativa unaccent() es STABLE y no puede usarse directamente en índices).
create or replace function public.immutable_unaccent(input text)
returns text
language sql
immutable
parallel safe
strict
set search_path = extensions, public
as $$
  select unaccent(input)
$$;

-- ---------------------------------------------------------------------------
-- Departamentos (DANE, 2 dígitos)
-- ---------------------------------------------------------------------------
create table if not exists public.departments (
  code text primary key check (code ~ '^[0-9]{2}$'),
  name text not null
);

comment on table public.departments is
  'Catálogo DANE de 32 departamentos + Bogotá D.C.';

alter table public.departments enable row level security;

drop policy if exists departments_select_public on public.departments;
create policy departments_select_public
  on public.departments
  for select
  to anon, authenticated
  using (true);

revoke all on public.departments from anon, authenticated;
grant select on public.departments to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Municipios (DIVIPOLA, 5 dígitos)
-- ---------------------------------------------------------------------------
create table if not exists public.municipalities (
  code text primary key check (code ~ '^[0-9]{5}$'),
  department_code text not null
    references public.departments(code)
    on update cascade
    on delete restrict,
  name text not null,
  is_pilot boolean not null default false
);

comment on table public.municipalities is
  'Catálogo DIVIPOLA. is_pilot habilita la experiencia funcional completa.';

create index if not exists municipalities_department_idx
  on public.municipalities (department_code);

create index if not exists municipalities_name_unaccent_trgm_idx
  on public.municipalities
  using gin (public.immutable_unaccent(lower(name)) extensions.gin_trgm_ops);

alter table public.municipalities enable row level security;

drop policy if exists municipalities_select_public on public.municipalities;
create policy municipalities_select_public
  on public.municipalities
  for select
  to anon, authenticated
  using (true);

revoke all on public.municipalities from anon, authenticated;
grant select on public.municipalities to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Zonas internas por municipio (segmentación de medianas)
-- ---------------------------------------------------------------------------
create table if not exists public.municipality_zones (
  id varchar(50) primary key,
  municipality_code text not null
    references public.municipalities(code)
    on update cascade
    on delete cascade,
  name_es varchar(100) not null,
  name_en varchar(100) not null,
  sector_hint_es varchar(150) not null default '',
  sector_hint_en varchar(150) not null default '',
  normalized_x numeric(5, 4) not null default 0.5
    check (normalized_x between 0 and 1),
  normalized_y numeric(5, 4) not null default 0.5
    check (normalized_y between 0 and 1),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  -- Permite que price_reports valide (zone_id, municipality_code) en una sola FK.
  unique (id, municipality_code)
);

comment on table public.municipality_zones is
  'Zonas internas de un municipio piloto para calcular medianas por sector.';

create index if not exists municipality_zones_municipality_idx
  on public.municipality_zones (municipality_code, sort_order);

alter table public.municipality_zones enable row level security;

drop policy if exists municipality_zones_select_public on public.municipality_zones;
create policy municipality_zones_select_public
  on public.municipality_zones
  for select
  to anon, authenticated
  using (true);

revoke all on public.municipality_zones from anon, authenticated;
grant select on public.municipality_zones to anon, authenticated;
