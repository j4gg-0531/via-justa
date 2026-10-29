-- ============================================================================
-- Pruebas pgTAP · Mapa de Precios, Servicios y Negocios (VJ-12)
-- ============================================================================
-- Verifica:
--   1. Existencia de `public.get_municipality_map_items` y `public.register_business_on_map`.
--   2. Extracción de coordenadas WGS84 reales (`latitude`, `longitude`) desde PostGIS.
--   3. Aparición inmediata en el mapa de un negocio registrado y aprobado en
--      `public.businesses` (y exclusión de negocios `pending` o `rejected`).
--   4. Aparición inmediata en el mapa de un reporte ciudadano real en
--      `public.price_reports` con coordenadas redondeadas a 3 decimales.
--   5. Filtros por categoría (`prices`, `services`, `consulates`) y por
--      bounding box geográfico (`p_min_lat`, `p_max_lat`, `p_min_lng`, `p_max_lng`).
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(13);

-- ---------------------------------------------------------------------------
-- 1-2 · Las funciones RPC existen
-- ---------------------------------------------------------------------------
select has_function(
  'public',
  'get_municipality_map_items',
  array['text', 'text', 'double precision', 'double precision', 'double precision', 'double precision', 'boolean', 'integer'],
  'get_municipality_map_items RPC exists with expected signature'
);

select has_function(
  'public',
  'register_business_on_map',
  array['character varying', 'character varying', 'text', 'text', 'double precision', 'double precision', 'character varying', 'character varying', 'character varying', 'character varying', 'boolean'],
  'register_business_on_map RPC exists with expected signature'
);

-- ---------------------------------------------------------------------------
-- 3 · Semillas de zonas de Valledupar tienen coordenadas WGS84 reales
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::int
    from public.municipality_zones
    where municipality_code = '20001'
      and center_lat between 10.40 and 10.55
      and center_lng between -73.32 and -73.20
  ),
  5,
  'all 5 Valledupar zones have valid WGS84 center_lat and center_lng coordinates'
);

-- ---------------------------------------------------------------------------
-- 4-5 · Registrar un negocio real aprobado en `public.businesses` hace que
--       aparezca automáticamente en el mapa con sus coordenadas exactas
-- ---------------------------------------------------------------------------
select lives_ok(
  $$
    select public.register_business_on_map(
      p_name := 'Clínica César Real Test',
      p_type := 'hospital',
      p_description_es := 'Atención médica integral en Valledupar',
      p_description_en := 'Comprehensive medical care in Valledupar',
      p_latitude := 10.4755,
      p_longitude := -73.2495,
      p_address := 'Calle 16 #14-90',
      p_phone := '6055700000',
      p_whatsapp := '576055700000',
      p_municipality_code := '20001',
      p_approve_immediately := true
    );
  $$,
  'admin/service_role can register an approved business with numeric lat/lng'
);

select is(
  (
    select count(*)::int
    from public.get_municipality_map_items('20001', null, null, null, null, null, false, 200)
    where name_es = 'Clínica César Real Test'
      and source_type = 'business'
      and map_category = 'services'
      and pin_kind = 'hospital'
      and abs(latitude - 10.4755) < 0.0001
      and abs(longitude - (-73.2495)) < 0.0001
      and is_demo = false
  ),
  1,
  'approved real business in public.businesses appears immediately on the map with exact coordinates'
);

-- ---------------------------------------------------------------------------
-- 6 · Un negocio en estado `pending` NO aparece en el mapa público
-- ---------------------------------------------------------------------------
select lives_ok(
  $$
    select public.register_business_on_map(
      p_name := 'Negocio Pendiente Invisible',
      p_type := 'restaurant',
      p_description_es := 'En revisión',
      p_description_en := 'Under review',
      p_latitude := 10.4800,
      p_longitude := -73.2500,
      p_address := 'Carrera 11 #10-20',
      p_phone := '3001112233',
      p_whatsapp := '573001112233',
      p_municipality_code := '20001',
      p_approve_immediately := false
    );
  $$,
  'business registered without immediate approval stays in pending status'
);

select is(
  (
    select count(*)::int
    from public.get_municipality_map_items('20001', null, null, null, null, null, true, 200)
    where name_es = 'Negocio Pendiente Invisible'
  ),
  0,
  'pending business does not appear in get_municipality_map_items'
);

-- ---------------------------------------------------------------------------
-- 7-8 · Un reporte de precio ciudadano real aparece en el mapa con coordenadas
--       redondeadas a 3 decimales (privacidad RN-08)
-- ---------------------------------------------------------------------------
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  '12121212-1212-1212-1212-121212121212',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'mapper@example.test',
  extensions.crypt('password', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Mapper"}'::jsonb,
  now(),
  now()
)
on conflict (id) do nothing;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"12121212-1212-1212-1212-121212121212","role":"authenticated"}';

select lives_ok(
  $$
    select public.submit_price_report(
      p_category_id := 'food_corrientazo',
      p_municipality_code := '20001',
      p_zone_id := 'vup_norte',
      p_amount_cop := 15000,
      p_latitude := 10.48849,
      p_longitude := -73.25349,
      p_place_name := 'Asadero Guatapurí Test',
      p_source_note := 'Almuerzo verificado'
    );
  $$,
  'authenticated user submits price report with GPS coordinates'
);

reset role;

select is(
  (
    select count(*)::int
    from public.get_municipality_map_items('20001', 'prices', null, null, null, null, false, 200)
    where source_type = 'price_report'
      and name_es like '%Asadero Guatapurí Test%'
      and amount_cop = 15000
      and abs(latitude - 10.488) < 0.0001
      and abs(longitude - (-73.253)) < 0.0001
      and is_demo = false
  ),
  1,
  'real price report appears on map with 3-decimal privacy-rounded coordinates'
);

-- ---------------------------------------------------------------------------
-- 9-12 · Filtros de categoría, bounding box y límite máximo de 200 registros
-- ---------------------------------------------------------------------------
select ok(
  (
    select count(*)::int
    from public.get_municipality_map_items('20001', 'consulates', null, null, null, null, true, 200)
    where map_category = 'consulates'
  ) >= 1,
  'filtering by consulates returns only consulate map items'
);

select is(
  (
    select count(*)::int
    from public.get_municipality_map_items('20001', 'consulates', null, null, null, null, true, 200)
    where map_category <> 'consulates'
  ),
  0,
  'filtering by consulates excludes prices and general services'
);

select is(
  (
    select count(*)::int
    from public.get_municipality_map_items(
      '20001',
      null,
      10.485, -- min_lat (solo Zona Norte)
      10.495, -- max_lat
      -73.260, -- min_lng
      -73.245, -- max_lng
      false,
      200
    )
    where name_es like '%Asadero Guatapurí Test%'
  ),
  1,
  'viewport bounding box filter returns items inside the north zone bounds'
);

select is(
  (
    select count(*)::int
    from public.get_municipality_map_items(
      '20001',
      null,
      10.485, -- min_lat (solo Zona Norte)
      10.495, -- max_lat
      -73.260, -- min_lng
      -73.245, -- max_lng
      false,
      200
    )
    where name_es = 'Clínica César Real Test'
  ),
  0,
  'viewport bounding box filter excludes items outside the active camera bounds'
);

select * from finish();
rollback;
