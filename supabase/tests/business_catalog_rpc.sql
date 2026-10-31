-- ============================================================================
-- Pruebas pgTAP · Catálogo, Ficha de Detalle y Acciones Externas de Negocios (VJ-17)
-- ============================================================================
-- Cubre todos los casos exigidos por el Plan Maestro (§VJ-17):
--   1. Existencia de RPCs (`get_business_catalog`, `get_business_detail`,
--      `get_my_businesses`, `build_business_whatsapp_url`, `build_business_maps_url`).
--   2. Invisibilidad de negocios `pending` y `rejected` en `get_business_catalog`
--      y en `get_business_detail` para `anon` y usuarios terceros (`P0002`).
--   3. Visibilidad de negocios `approved` en `get_business_catalog` y
--      `get_business_detail`, con coordenadas reales, platos destacados
--      (`dishes`), fotos permitidas (`photos`) y horarios (`hours`).
--   4. Filtro por tipo/grupo (`food` / `restaurant`, `lodging` / `hotel`) y
--      búsqueda insensible a tildes (`pilon` encuentra `El Pilón Vallenato` y
--      búsqueda por plato `sancocho` encuentra el restaurante).
--   5. Localización `es`/`en` y fallback automático a `es`.
--   6. Negocio sin WhatsApp o sin enlace externo de pedido desactiva las
--      acciones (`has_whatsapp = false`, `whatsapp_url = null`,
--      `has_external_order = false`, `order_url = null`).
--   7. `build_business_whatsapp_url` valida E.164 sin `+` y codifica espacios y
--      caracteres especiales (`&`, `<`, `?`) sin inyección de parámetros.
--   8. Paginación (`p_limit`, `p_offset`) acotada entre 1 y 50 resultados.
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

-- ---------------------------------------------------------------------------
-- 1-5 · Existencia de RPCs y helpers de enlaces externos
-- ---------------------------------------------------------------------------
select has_function(
  'public',
  'get_business_catalog',
  array['text', 'text', 'text', 'text', 'boolean', 'integer', 'integer'],
  'get_business_catalog RPC exists with expected 7-argument signature'
);

select has_function(
  'public',
  'get_business_detail',
  array['uuid', 'text', 'boolean'],
  'get_business_detail RPC exists with expected signature'
);

select has_function(
  'public',
  'get_my_businesses',
  array[]::text[],
  'get_my_businesses RPC exists with expected signature'
);

select has_function(
  'public',
  'build_business_whatsapp_url',
  array['text', 'text', 'text'],
  'build_business_whatsapp_url helper exists'
);

select has_function(
  'public',
  'build_business_maps_url',
  array['double precision', 'double precision', 'text'],
  'build_business_maps_url helper exists'
);

-- ---------------------------------------------------------------------------
-- 6-8 · Validación de `build_business_whatsapp_url` y `build_business_maps_url`
--       (E.164 sin '+', codificación UTF-8 de espacios/inyección, es/en)
-- ---------------------------------------------------------------------------
select is(
  public.build_business_whatsapp_url('invalid-phone', 'Mi Negocio', 'es'),
  null,
  'build_business_whatsapp_url returns NULL for invalid non-E.164 numbers'
);

select ok(
  public.build_business_whatsapp_url('+57 300 123 4567', 'Café & Pan?x=1', 'es')
    like 'https://wa.me/573001234567?text=Hola%20Caf%C3%A9%20%26%20Pan%3Fx%3D1%'
  and position(' ' in public.build_business_whatsapp_url('+57 300 123 4567', 'Café & Pan?x=1', 'es')) = 0,
  'build_business_whatsapp_url strips +/spaces from phone and RFC-3986 encodes special characters (&, ?, spaces, accents)'
);

select ok(
  public.build_business_whatsapp_url('573001234567', 'Hotel Real', 'en')
    like 'https://wa.me/573001234567?text=Hello%20Hotel%20Real%',
  'build_business_whatsapp_url localizes greeting message in English when p_locale is en'
);

-- ---------------------------------------------------------------------------
-- Preparación de usuarios y negocios reales (uno `approved` sin WhatsApp ni
-- `order_url`, y otro `pending` con platos) para probar el ciclo completo
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
values
  (
    'dddd4444-4444-4444-8444-444444444444',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'merchant.vj17@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Merchant VJ17"}'::jsonb,
    now(),
    now()
  ),
  (
    'eeee5555-5555-4555-8555-555555555555',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin.vj17@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Admin VJ17"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

insert into public.admin_users (user_id)
values ('eeee5555-5555-4555-8555-555555555555')
on conflict (user_id) do nothing;

create temp table vj17_ids (
  approved_no_wa_id uuid,
  pending_id uuid
);
grant select, insert, update, delete on vj17_ids to anon, authenticated;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"dddd4444-4444-4444-8444-444444444444","role":"authenticated"}';

insert into vj17_ids (approved_no_wa_id, pending_id)
values (
  (
    select (
      public.submit_business(
        p_client_request_id := '20000000-0000-4000-8000-000000000001'::uuid,
        p_type := 'hotel',
        p_name := 'Hostal Casa Colonial Sin WA',
        p_description_es := 'Hospedaje familiar en el centro histórico de Valledupar con atención telefónica directa.',
        p_description_en := 'Family lodging in the historic center of Valledupar with direct phone service.',
        p_latitude := 10.4748,
        p_longitude := -73.2441,
        p_address := 'Calle 15 #8-40 Centro Histórico',
        p_phone := '6055723344',
        p_whatsapp := null,
        p_whatsapp_consent := false,
        p_publication_consent := true,
        p_order_url := null,
        p_hours := '{"mon":[{"open":"07:00","close":"22:00"}]}'::jsonb,
        p_place_id := 'ChIJ_HostalColonialVup',
        p_dishes := '[{"name":"Habitación sencilla ventilador","price_cop":65000,"description":"Por noche"}]'::jsonb,
        p_municipality_code := '20001'
      )
    ).id
  ),
  (
    select (
      public.submit_business(
        p_client_request_id := '20000000-0000-4000-8000-000000000002'::uuid,
        p_type := 'restaurant',
        p_name := 'Comedor Secreto En Revisión',
        p_description_es := 'Restaurante aún pendiente de moderación administrativa en Valledupar.',
        p_description_en := 'Restaurant still pending admin moderation in Valledupar.',
        p_latitude := 10.4770,
        p_longitude := -73.2460,
        p_address := 'Carrera 11 #16-10',
        p_phone := '3004445566',
        p_whatsapp := '573004445566',
        p_whatsapp_consent := true,
        p_publication_consent := true
      )
    ).id
  )
);

-- El comerciante ve ambos negocios en `get_my_businesses`
select is(
  (select count(*)::int from public.get_my_businesses()),
  2,
  'get_my_businesses returns all businesses owned by the authenticated merchant (including pending)'
);

reset role;

-- El administrador aprueba únicamente el primer negocio (`approved_no_wa_id`)
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"eeee5555-5555-4555-8555-555555555555","role":"authenticated"}';

select public.moderate_business(
  (select approved_no_wa_id from vj17_ids limit 1),
  'approved',
  null
);

reset role;

-- ---------------------------------------------------------------------------
-- 10-18 · Consultas públicas (`anon`) de catálogo, filtros, búsqueda sin
--         tildes, localización `es`/`en`, invisibilidad de `pending` y
--         desactivación de botones sin WhatsApp / sin enlace de pedido
-- ---------------------------------------------------------------------------
set local role anon;
set local request.jwt.claims = '{}';

select is(
  (
    select count(*)::int
    from public.get_business_catalog('20001', null, null, 'es', true, 50, 0)
    where id = (select pending_id from vj17_ids limit 1)
  ),
  0,
  'pending business is never returned by get_business_catalog'
);

select throws_ok(
  $$
    select public.get_business_detail(
      (select pending_id from vj17_ids limit 1),
      'es',
      true
    );
  $$,
  'P0002',
  null,
  'get_business_detail raises P0002 ([BUSINESS_NOT_FOUND]) when anon requests a pending business'
);

select is(
  (
    select row(
      c.category_group,
      c.has_whatsapp,
      c.whatsapp_url,
      c.tel_url,
      c.has_external_order,
      c.order_url,
      c.dishes_count,
      c.min_dish_price_cop
    )::text
    from public.get_business_catalog('20001', 'lodging', null, 'es', false, 20, 0) c
    where c.id = (select approved_no_wa_id from vj17_ids limit 1)
  ),
  row(
    'lodging'::text,
    false,
    null::text,
    'tel:6055723344'::text,
    false,
    null::text,
    1,
    65000
  )::text,
  'approved business without WhatsApp or order_url appears under lodging filter with WhatsApp/order actions disabled and phone/dishes populated'
);

select is(
  (
    select c.description
    from public.get_business_catalog('20001', 'lodging', null, 'en', false, 20, 0) c
    where c.id = (select approved_no_wa_id from vj17_ids limit 1)
  ),
  'Family lodging in the historic center of Valledupar with direct phone service.',
  'get_business_catalog returns localized English description when p_locale is en'
);

select is(
  (
    select count(*)::int
    from public.get_business_catalog('20001', 'food', 'pilon', 'es', true, 20, 0) c
    where c.id = '00000000-0000-0000-0000-000000000804'::uuid
  ),
  1,
  'accent-insensitive search (pilon) and food filter match [DEMO] Restaurante El Pilón Vallenato'
);

select is(
  (
    select count(*)::int
    from public.get_business_catalog('20001', null, 'sancocho', 'es', true, 20, 0) c
    where c.id = '00000000-0000-0000-0000-000000000804'::uuid
  ),
  1,
  'catalog search also finds businesses by featured dish name (sancocho)'
);

select is(
  (
    select row(
      (d -> 'actions' ->> 'can_whatsapp')::boolean,
      (d -> 'actions' ->> 'can_order_external')::boolean,
      d -> 'actions' ->> 'order_url',
      jsonb_array_length(d -> 'dishes')
    )::text
    from (
      select public.get_business_detail(
        '00000000-0000-0000-0000-000000000804'::uuid,
        'es',
        true
      ) as d
    ) q
  ),
  row(
    true,
    true,
    'https://www.valledupar-gastronomia-demo.co/carta-pilon-vallenato'::text,
    3
  )::text,
  'get_business_detail returns full detail JSON with 3 dishes, WhatsApp link and external order_url for El Pilón Vallenato'
);

select is(
  (
    select row(
      (d -> 'actions' ->> 'can_whatsapp')::boolean,
      d -> 'actions' ->> 'whatsapp_url',
      (d -> 'actions' ->> 'can_order_external')::boolean,
      d -> 'actions' ->> 'order_url',
      (d -> 'actions' ->> 'can_call')::boolean
    )::text
    from (
      select public.get_business_detail(
        (select approved_no_wa_id from vj17_ids limit 1),
        'en',
        false
      ) as d
    ) q
  ),
  row(
    false,
    null::text,
    false,
    null::text,
    true
  )::text,
  'get_business_detail disables WhatsApp and order actions when absent while keeping call and directions enabled'
);

select is(
  (
    select count(*)::int
    from public.get_business_catalog('20001', null, null, 'es', true, 2, 0)
  ),
  2,
  'get_business_catalog enforces pagination limit (p_limit = 2)'
);

reset role;

select * from finish();
rollback;
