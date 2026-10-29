-- ============================================================================
-- Vía Justa MVP · Migración 0005 · Negocios, contenido cultural e interés
-- ============================================================================
-- Crea:
--   * public.businesses: directorio de negocios registrados por usuarios.
--   * public.business_photos / public.business_dishes: multimedia y carta.
--   * public.city_content: contenido cultural bilingüe de la ciudad piloto.
--   * public.interest_registrations: botón "Notificarme" para municipios no piloto.
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.10 a §2.14
--   docs/seguridad-privacidad.md §4
--
-- Storage (bucket business-media) se configura en VJ-16.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Negocios
-- ---------------------------------------------------------------------------
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  municipality_code varchar(5) not null
    references public.municipalities(code)
    on update cascade
    on delete restrict,
  type varchar(50) not null
    check (type in ('restaurant', 'hotel', 'service', 'handicraft')),
  name varchar(150) not null,
  description_es text not null,
  description_en text not null,
  location extensions.geography(Point, 4326) not null,
  place_id varchar(150),
  phone varchar(20),
  whatsapp varchar(20) not null,
  whatsapp_consent_at timestamptz not null,
  order_url text
    check (order_url is null or order_url ~ '^https?://'),
  hours jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text,
  created_at timestamptz not null default now()
);

comment on table public.businesses is
  'Negocios propuestos por usuarios. Nacen en pending y solo el administrador cambia el estado.';

create index if not exists businesses_approved_idx
  on public.businesses (municipality_code, type)
  where status = 'approved';

create index if not exists businesses_owner_idx
  on public.businesses (owner_id);

create index if not exists businesses_location_idx
  on public.businesses using gist (location);

alter table public.businesses enable row level security;

drop policy if exists businesses_select_public_or_owner on public.businesses;
create policy businesses_select_public_or_owner
  on public.businesses
  for select
  to anon, authenticated
  using (status = 'approved' or owner_id = auth.uid());

drop policy if exists businesses_insert_own_pending on public.businesses;
create policy businesses_insert_own_pending
  on public.businesses
  for insert
  to authenticated
  with check (owner_id = auth.uid() and status = 'pending');

drop policy if exists businesses_update_own on public.businesses;
create policy businesses_update_own
  on public.businesses
  for update
  to authenticated
  using (owner_id = auth.uid() and status in ('pending', 'approved'))
  with check (owner_id = auth.uid());

-- El dueño solo edita columnas descriptivas; status/owner_id/municipality_code
-- quedan fuera del GRANT y solo el administrador (service_role) los cambia.
revoke all on public.businesses from anon, authenticated;
grant select on public.businesses to anon, authenticated;
grant insert on public.businesses to authenticated;
grant update (
  name,
  description_es,
  description_en,
  location,
  place_id,
  phone,
  whatsapp,
  whatsapp_consent_at,
  order_url,
  hours
) on public.businesses to authenticated;

-- ---------------------------------------------------------------------------
-- Fotos del negocio (máximo 5 posiciones)
-- ---------------------------------------------------------------------------
create table if not exists public.business_photos (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null
    references public.businesses(id)
    on delete cascade,
  storage_path text not null,
  position integer not null default 0 check (position between 0 and 4),
  is_cover boolean not null default false,
  unique (business_id, position)
);

create index if not exists business_photos_business_idx
  on public.business_photos (business_id, position);

alter table public.business_photos enable row level security;

drop policy if exists business_photos_select_public_or_owner on public.business_photos;
create policy business_photos_select_public_or_owner
  on public.business_photos
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and (b.status = 'approved' or b.owner_id = auth.uid())
    )
  );

drop policy if exists business_photos_write_owner on public.business_photos;
create policy business_photos_write_owner
  on public.business_photos
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and b.owner_id = auth.uid()
    )
  );

revoke all on public.business_photos from anon, authenticated;
grant select on public.business_photos to anon, authenticated;
grant insert, update, delete on public.business_photos to authenticated;

-- ---------------------------------------------------------------------------
-- Platos / servicios destacados (máximo 5 posiciones)
-- ---------------------------------------------------------------------------
create table if not exists public.business_dishes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null
    references public.businesses(id)
    on delete cascade,
  name varchar(100) not null,
  price_cop integer not null check (price_cop > 0),
  description text,
  sort_order integer not null default 0 check (sort_order between 0 and 4),
  unique (business_id, sort_order)
);

create index if not exists business_dishes_business_idx
  on public.business_dishes (business_id, sort_order);

alter table public.business_dishes enable row level security;

drop policy if exists business_dishes_select_public_or_owner on public.business_dishes;
create policy business_dishes_select_public_or_owner
  on public.business_dishes
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and (b.status = 'approved' or b.owner_id = auth.uid())
    )
  );

drop policy if exists business_dishes_write_owner on public.business_dishes;
create policy business_dishes_write_owner
  on public.business_dishes
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and b.owner_id = auth.uid()
    )
  );

revoke all on public.business_dishes from anon, authenticated;
grant select on public.business_dishes to anon, authenticated;
grant insert, update, delete on public.business_dishes to authenticated;

-- ---------------------------------------------------------------------------
-- Contenido cultural de la ciudad (es/en)
-- ---------------------------------------------------------------------------
create table if not exists public.city_content (
  id uuid primary key default gen_random_uuid(),
  municipality_code varchar(5) not null
    references public.municipalities(code)
    on update cascade
    on delete cascade,
  locale varchar(2) not null check (locale in ('es', 'en')),
  section varchar(50) not null,
  title varchar(150) not null,
  body text not null,
  image_path text,
  source_citation varchar(255) not null,
  unique (municipality_code, locale, section, title)
);

comment on table public.city_content is
  'Contenido cultural curado por sección e idioma. Toda fila exige fuente citada.';

create index if not exists city_content_municipality_idx
  on public.city_content (municipality_code, locale, section);

alter table public.city_content enable row level security;

drop policy if exists city_content_select_public on public.city_content;
create policy city_content_select_public
  on public.city_content
  for select
  to anon, authenticated
  using (true);

revoke all on public.city_content from anon, authenticated;
grant select on public.city_content to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Registro de interés en municipios no piloto
-- ---------------------------------------------------------------------------
create table if not exists public.interest_registrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  municipality_code varchar(5) not null
    references public.municipalities(code)
    on update cascade
    on delete restrict,
  created_at timestamptz not null default now(),
  unique (user_id, municipality_code)
);

comment on table public.interest_registrations is
  'Solicitudes de apertura de municipios no piloto. Solo registra interés; no promete notificaciones.';

create index if not exists interest_registrations_municipality_idx
  on public.interest_registrations (municipality_code);

alter table public.interest_registrations enable row level security;

drop policy if exists interest_registrations_select_own on public.interest_registrations;
create policy interest_registrations_select_own
  on public.interest_registrations
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists interest_registrations_insert_own on public.interest_registrations;
create policy interest_registrations_insert_own
  on public.interest_registrations
  for insert
  to authenticated
  with check (user_id = auth.uid());

revoke all on public.interest_registrations from anon, authenticated;
grant select, insert on public.interest_registrations to authenticated;
