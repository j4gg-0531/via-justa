-- ============================================================================
-- Vía Justa MVP · Migración 0003 · Catálogo de categorías de precio
-- ============================================================================
-- Crea public.price_categories: unidades comparables para que la mediana
-- estadística no mezcle magnitudes heterogéneas (D13).
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.5
--   docs/decisiones.md D13
--
-- Nota: los identificadores coinciden con el catálogo DEMO que ya consume el
-- frontend (`DemoPriceVerdictRepository.demoCategories`) para que la transición
-- a Supabase no rompa la app.
-- ============================================================================

create table if not exists public.price_categories (
  id varchar(50) primary key,
  group_key varchar(50) not null,
  name_es varchar(100) not null,
  name_en varchar(100) not null,
  unit_description_es varchar(100) not null,
  unit_description_en varchar(100) not null,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

comment on table public.price_categories is
  'Catálogo de categorías de precio comparables. Solo el administrador/migraciones escriben.';

create index if not exists price_categories_group_sort_idx
  on public.price_categories (group_key, sort_order);

alter table public.price_categories enable row level security;

drop policy if exists price_categories_select_public on public.price_categories;
create policy price_categories_select_public
  on public.price_categories
  for select
  to anon, authenticated
  using (true);

revoke all on public.price_categories from anon, authenticated;
grant select on public.price_categories to anon, authenticated;
