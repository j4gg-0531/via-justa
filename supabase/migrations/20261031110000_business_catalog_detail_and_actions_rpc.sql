-- ============================================================================
-- Vía Justa MVP · VJ-17 · Catálogo de negocios, ficha de detalle y acciones
-- ============================================================================
-- Objetivo (PLAN_MAESTRO §VJ-17, pasos 1 a 6):
--   1. Exponer el catálogo paginado y filtrado de negocios aprobados
--      (`public.get_business_catalog`) para el municipio activo, con búsqueda
--      insensible a tildes (`unaccent`), filtro por tipo o grupo de categoría
--      (`food`, `lodging`, `transport`, `services`) y carga liviana (solo
--      portada `cover_photo_path` y conteo de fotos/platos, sin traer fotos
--      gigantes en el listado).
--   2. Exponer la ficha completa de detalle (`public.get_business_detail`)
--      con descripción localizada (`es`/`en` + fallback a `es`), horarios,
--      hasta 5 fotos permitidas, hasta 5 platos destacados, coordenadas WGS84
--      y enlaces de acciones externas pre-validados (`whatsapp_url`,
--      `tel_url`, `maps_url`, `order_url`).
--   3. Funciones puras en servidor (`public.build_business_whatsapp_url` y
--      `public.build_business_maps_url`) que validan E.164 sin `+` para
--      `wa.me`, codifican el mensaje en `es`/`en` de forma segura contra
--      inyección/espacios y desactivan acciones (`null` / `false`) cuando el
--      comercio no tiene WhatsApp consentido, teléfono o enlace de pedido.
--   4. Exponer `public.get_my_businesses` para que el comerciante autenticado
--      consulte el estado de sus negocios (`pending`, `approved`, `rejected`)
--      y el motivo de rechazo.
-- ============================================================================

create extension if not exists unaccent with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Funciones puras de codificación URI y construcción de enlaces externos
-- ---------------------------------------------------------------------------
create or replace function public.uri_encode_component(p_input text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_bytes bytea;
  v_len integer;
  v_i integer;
  v_byte integer;
  v_out text := '';
begin
  if p_input is null or p_input = '' then
    return '';
  end if;

  v_bytes := convert_to(p_input, 'UTF8');
  v_len := octet_length(v_bytes);

  for v_i in 0..(v_len - 1) loop
    v_byte := get_byte(v_bytes, v_i);
    -- RFC 3986 unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~"
    if (v_byte between 48 and 57)
       or (v_byte between 65 and 90)
       or (v_byte between 97 and 122)
       or v_byte in (45, 46, 95, 126) then
      v_out := v_out || chr(v_byte);
    else
      v_out := v_out || '%' || upper(lpad(to_hex(v_byte), 2, '0'));
    end if;
  end loop;

  return v_out;
end;
$$;

comment on function public.uri_encode_component(text) is
  'VJ-17: codifica en porcentaje (RFC 3986 UTF-8) cualquier texto para parámetros seguros de URL.';

grant execute on function public.uri_encode_component(text) to anon, authenticated, service_role;

create or replace function public.build_business_whatsapp_url(
  p_whatsapp text,
  p_business_name text default null,
  p_locale text default 'es'
)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_digits text := nullif(regexp_replace(coalesce(p_whatsapp, ''), '[\s()+.-]', '', 'g'), '');
  v_clean_name text := btrim(regexp_replace(coalesce(p_business_name, ''), '[[:cntrl:]<>]', '', 'g'));
  v_is_en boolean := lower(btrim(coalesce(p_locale, 'es'))) like 'en%';
  v_message text;
begin
  -- Valida estrictamente E.164 sin '+' (10 a 15 dígitos, sin iniciar en 0).
  if v_digits is null or v_digits !~ '^[1-9][0-9]{9,14}$' then
    return null;
  end if;

  if v_clean_name = '' then
    v_message := case
      when v_is_en then 'Hello, I saw your business on Vía Justa and would like more information.'
      else 'Hola, vi tu negocio en Vía Justa y quisiera más información.'
    end;
  else
    v_message := case
      when v_is_en then format('Hello %s, I saw your listing on Vía Justa and would like more information.', left(v_clean_name, 120))
      else format('Hola %s, vi tu ficha en Vía Justa y quisiera más información.', left(v_clean_name, 120))
    end;
  end if;

  return 'https://wa.me/' || v_digits || '?text=' || public.uri_encode_component(v_message);
end;
$$;

comment on function public.build_business_whatsapp_url(text, text, text) is
  'VJ-17: valida E.164 sin + para wa.me y codifica el mensaje localizado (es/en) sin inyección ni espacios sin escapar.';

grant execute on function public.build_business_whatsapp_url(text, text, text) to anon, authenticated, service_role;

create or replace function public.build_business_maps_url(
  p_latitude double precision,
  p_longitude double precision,
  p_place_id text default null
)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_place_id text := nullif(btrim(coalesce(p_place_id, '')), '');
  v_url text;
begin
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    return null;
  end if;

  v_url := 'https://www.google.com/maps/dir/?api=1&destination='
    || trim(to_char(p_latitude, 'FM990.000000'))
    || ','
    || trim(to_char(p_longitude, 'FM990.000000'));

  if v_place_id is not null and v_place_id ~ '^[A-Za-z0-9_-]{10,150}$' then
    v_url := v_url || '&destination_place_id=' || public.uri_encode_component(v_place_id);
  end if;

  return v_url;
end;
$$;

comment on function public.build_business_maps_url(double precision, double precision, text) is
  'VJ-17: construye el enlace oficial de navegación externa hacia Google Maps con coordenadas y place_id opcional.';

grant execute on function public.build_business_maps_url(double precision, double precision, text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. RPC de Catálogo Paginado (`public.get_business_catalog`)
-- ---------------------------------------------------------------------------
create or replace function public.get_business_catalog(
  p_municipality_code text default '20001',
  p_type text default null,
  p_search text default null,
  p_locale text default 'es',
  p_include_demo boolean default false,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  municipality_code varchar,
  type varchar,
  category_group text,
  name varchar,
  description text,
  resolved_locale text,
  address varchar,
  latitude double precision,
  longitude double precision,
  place_id varchar,
  phone varchar,
  whatsapp varchar,
  has_whatsapp boolean,
  whatsapp_url text,
  tel_url text,
  maps_url text,
  order_url text,
  has_external_order boolean,
  hours jsonb,
  cover_photo_path text,
  photos_count integer,
  dishes_count integer,
  min_dish_price_cop integer,
  is_demo boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_mun_code text := btrim(coalesce(p_municipality_code, '20001'));
  v_type_filter text := nullif(lower(btrim(coalesce(p_type, ''))), '');
  v_search_norm text := nullif(lower(extensions.unaccent(btrim(coalesce(p_search, '')))), '');
  v_req_locale text := case
    when lower(btrim(coalesce(p_locale, 'es'))) like 'en%' then 'en'
    else 'es'
  end;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if v_type_filter in ('all', 'todos') then
    v_type_filter := null;
  end if;

  return query
  select
    b.id,
    b.municipality_code,
    b.type,
    case
      when b.type = 'restaurant' then 'food'
      when b.type = 'hotel' then 'lodging'
      when b.type = 'transport' then 'transport'
      else 'services'
    end as category_group,
    b.name,
    case
      when v_req_locale = 'en' and length(btrim(coalesce(b.description_en, ''))) > 0
        then b.description_en
      else b.description_es
    end as description,
    case
      when v_req_locale = 'en' and length(btrim(coalesce(b.description_en, ''))) > 0
        then 'en'
      else 'es'
    end as resolved_locale,
    coalesce(b.address, 'Valledupar, Cesar')::varchar as address,
    round(extensions.ST_Y(b.location::extensions.geometry)::numeric, 6)::double precision as latitude,
    round(extensions.ST_X(b.location::extensions.geometry)::numeric, 6)::double precision as longitude,
    b.place_id,
    b.phone,
    case
      when b.whatsapp is not null and b.whatsapp_consent_at is not null then b.whatsapp
      else null
    end as whatsapp,
    (b.whatsapp is not null and b.whatsapp_consent_at is not null) as has_whatsapp,
    case
      when b.whatsapp is not null and b.whatsapp_consent_at is not null
        then public.build_business_whatsapp_url(b.whatsapp, b.name, v_req_locale)
      else null
    end as whatsapp_url,
    case
      when b.phone is not null and b.phone ~ '^\+?[0-9]{7,15}$'
        then 'tel:' || b.phone
      else null
    end as tel_url,
    public.build_business_maps_url(
      round(extensions.ST_Y(b.location::extensions.geometry)::numeric, 6)::double precision,
      round(extensions.ST_X(b.location::extensions.geometry)::numeric, 6)::double precision,
      b.place_id
    ) as maps_url,
    b.order_url,
    (b.order_url is not null) as has_external_order,
    b.hours,
    (
      select p.storage_path
      from public.business_photos p
      where p.business_id = b.id
      order by p.is_cover desc, p.position asc
      limit 1
    ) as cover_photo_path,
    (
      select count(*)::integer
      from public.business_photos p
      where p.business_id = b.id
    ) as photos_count,
    (
      select count(*)::integer
      from public.business_dishes d
      where d.business_id = b.id
    ) as dishes_count,
    (
      select min(d.price_cop)::integer
      from public.business_dishes d
      where d.business_id = b.id
    ) as min_dish_price_cop,
    b.is_demo,
    b.created_at
  from public.businesses b
  where b.municipality_code = v_mun_code
    and b.status = 'approved'
    and (p_include_demo or b.is_demo = false)
    and (
      v_type_filter is null
      or lower(b.type) = v_type_filter
      or (v_type_filter = 'food' and b.type = 'restaurant')
      or (v_type_filter = 'lodging' and b.type = 'hotel')
      or (v_type_filter = 'services' and b.type in ('service', 'handicraft', 'hospital', 'consulate'))
    )
    and (
      v_search_norm is null
      or lower(extensions.unaccent(b.name)) like '%' || v_search_norm || '%'
      or lower(extensions.unaccent(b.description_es)) like '%' || v_search_norm || '%'
      or lower(extensions.unaccent(b.description_en)) like '%' || v_search_norm || '%'
      or lower(extensions.unaccent(coalesce(b.address, ''))) like '%' || v_search_norm || '%'
      or exists (
        select 1
        from public.business_dishes d
        where d.business_id = b.id
          and lower(extensions.unaccent(d.name)) like '%' || v_search_norm || '%'
      )
    )
  order by b.is_demo asc, b.created_at desc, b.name asc
  limit v_limit
  offset v_offset;
end;
$$;

comment on function public.get_business_catalog(text, text, text, text, boolean, integer, integer) is
  'VJ-17: catálogo paginado de negocios aprobados con filtro por tipo/grupo, búsqueda sin tildes y enlaces externos seguros.';

revoke all on function public.get_business_catalog(text, text, text, text, boolean, integer, integer) from public;
grant execute on function public.get_business_catalog(text, text, text, text, boolean, integer, integer)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. RPC de Ficha Completa de Detalle (`public.get_business_detail`)
-- ---------------------------------------------------------------------------
create or replace function public.get_business_detail(
  p_business_id uuid,
  p_locale text default 'es',
  p_include_demo boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_b public.businesses;
  v_is_anon boolean := coalesce(current_setting('role', true), '') = 'anon';
  v_can_view_unapproved boolean := false;
  v_req_locale text := case
    when lower(btrim(coalesce(p_locale, 'es'))) like 'en%' then 'en'
    else 'es'
  end;
  v_resolved_locale text;
  v_lat double precision;
  v_lng double precision;
  v_has_wa boolean;
  v_wa_url text;
  v_tel_url text;
  v_maps_url text;
  v_photos jsonb;
  v_dishes jsonb;
begin
  select * into v_b
  from public.businesses b
  where b.id = p_business_id;

  if not found then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no está disponible.'
      using errcode = 'P0002';
  end if;

  if not v_is_anon then
    v_can_view_unapproved := (
      private.is_privileged_caller()
      or v_b.owner_id = auth.uid()
      or public.is_admin()
    );
  end if;

  -- El público solo puede ver negocios `approved` (y no-demo salvo p_include_demo = true).
  if v_b.status <> 'approved' and not v_can_view_unapproved then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no está disponible.'
      using errcode = 'P0002';
  end if;

  if v_b.is_demo and not p_include_demo and not v_can_view_unapproved then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no está disponible.'
      using errcode = 'P0002';
  end if;

  v_resolved_locale := case
    when v_req_locale = 'en' and length(btrim(coalesce(v_b.description_en, ''))) > 0 then 'en'
    else 'es'
  end;

  v_lat := round(extensions.ST_Y(v_b.location::extensions.geometry)::numeric, 6)::double precision;
  v_lng := round(extensions.ST_X(v_b.location::extensions.geometry)::numeric, 6)::double precision;

  v_has_wa := (v_b.whatsapp is not null and v_b.whatsapp_consent_at is not null);
  v_wa_url := case
    when v_has_wa then public.build_business_whatsapp_url(v_b.whatsapp, v_b.name, v_req_locale)
    else null
  end;
  v_tel_url := case
    when v_b.phone is not null and v_b.phone ~ '^\+?[0-9]{7,15}$' then 'tel:' || v_b.phone
    else null
  end;
  v_maps_url := public.build_business_maps_url(v_lat, v_lng, v_b.place_id);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'storage_path', p.storage_path,
        'position', p.position,
        'is_cover', p.is_cover,
        'mime_type', p.mime_type,
        'size_bytes', p.size_bytes
      )
      order by p.is_cover desc, p.position asc
    ),
    '[]'::jsonb
  )
  into v_photos
  from public.business_photos p
  where p.business_id = v_b.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'name', d.name,
        'price_cop', d.price_cop,
        'description', d.description,
        'sort_order', d.sort_order
      )
      order by d.sort_order asc
    ),
    '[]'::jsonb
  )
  into v_dishes
  from public.business_dishes d
  where d.business_id = v_b.id;

  return jsonb_build_object(
    'id', v_b.id,
    'municipality_code', v_b.municipality_code,
    'type', v_b.type,
    'category_group', case
      when v_b.type = 'restaurant' then 'food'
      when v_b.type = 'hotel' then 'lodging'
      when v_b.type = 'transport' then 'transport'
      else 'services'
    end,
    'name', v_b.name,
    'description', case when v_resolved_locale = 'en' then v_b.description_en else v_b.description_es end,
    'description_es', v_b.description_es,
    'description_en', v_b.description_en,
    'requested_locale', v_req_locale,
    'resolved_locale', v_resolved_locale,
    'address', coalesce(v_b.address, 'Valledupar, Cesar'),
    'latitude', v_lat,
    'longitude', v_lng,
    'place_id', v_b.place_id,
    'phone', v_b.phone,
    'whatsapp', case when v_has_wa then v_b.whatsapp else null end,
    'order_url', v_b.order_url,
    'hours', v_b.hours,
    'status', v_b.status,
    'rejection_reason', case when v_can_view_unapproved then v_b.rejection_reason else null end,
    'is_demo', v_b.is_demo,
    'created_at', v_b.created_at,
    'updated_at', v_b.updated_at,
    'actions', jsonb_build_object(
      'can_call', v_tel_url is not null,
      'tel_url', v_tel_url,
      'can_whatsapp', v_wa_url is not null,
      'whatsapp_url', v_wa_url,
      'can_directions', v_maps_url is not null,
      'maps_url', v_maps_url,
      'can_order_external', v_b.order_url is not null,
      'order_url', v_b.order_url,
      'external_order_disclaimer', case
        when v_req_locale = 'en'
          then 'Orders and payments take place directly with the merchant outside Vía Justa.'
        else 'Los pedidos y pagos se realizan directamente con el comercio fuera de Vía Justa.'
      end
    ),
    'photos', v_photos,
    'dishes', v_dishes
  );
end;
$$;

comment on function public.get_business_detail(uuid, text, boolean) is
  'VJ-17: ficha completa de negocio con descripción localizada, fotos, platos destacados y enlaces de acción externa.';

revoke all on function public.get_business_detail(uuid, text, boolean) from public;
grant execute on function public.get_business_detail(uuid, text, boolean)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. RPC para que el comerciante consulte sus propios negocios (`get_my_businesses`)
-- ---------------------------------------------------------------------------
create or replace function public.get_my_businesses()
returns table (
  id uuid,
  municipality_code varchar,
  type varchar,
  name varchar,
  status text,
  rejection_reason text,
  address varchar,
  photos_count integer,
  dishes_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  reviewed_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '[BUSINESS_AUTH_REQUIRED] Debes iniciar sesión para consultar tus negocios registrados.'
      using errcode = '42501';
  end if;

  return query
  select
    b.id,
    b.municipality_code,
    b.type,
    b.name,
    b.status,
    b.rejection_reason,
    b.address,
    (select count(*)::integer from public.business_photos p where p.business_id = b.id),
    (select count(*)::integer from public.business_dishes d where d.business_id = b.id),
    b.created_at,
    b.updated_at,
    b.reviewed_at
  from public.businesses b
  where b.owner_id = v_uid
  order by b.updated_at desc;
end;
$$;

comment on function public.get_my_businesses() is
  'VJ-17: lista los negocios del comerciante autenticado en cualquier estado (pending, approved, rejected).';

revoke all on function public.get_my_businesses() from public, anon;
grant execute on function public.get_my_businesses() to authenticated;
