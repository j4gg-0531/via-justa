-- ============================================================================
-- Vía Justa MVP · Migración 0010 (VJ-12) · Coordenadas de mapa, negocios y RPC
-- ============================================================================
-- Implementa el soporte geoespacial de backend para el mapa real de Google Maps
-- (VJ-12) y la visualización en mapa de negocios aprobados (VJ-16/VJ-17):
--
--   1. Añade coordenadas WGS84 reales de referencia (`center_lat`, `center_lng`)
--      a `public.municipality_zones` para Valledupar (`20001`).
--   2. Extiende `public.businesses` con `is_demo`, `address`, `owner_id` opcional
--      para semillas/altas administrativas y subtipos de servicio (`transport`,
--      `hospital`, `consulate`), manteniendo RLS estricta para clientes.
--   3. Crea `public.register_business_on_map(...)` para facilitar el registro
--      de negocios con latitud/longitud numéricas sin construir WKT manual.
--   4. Crea `public.get_municipality_map_items(...)`: consulta unificada y
--      acotada por viewport (máx. 200 pines) que combina reportes de precios
--      (`public.price_reports` con privacidad de 3 decimales y veredicto) y
--      negocios/servicios aprobados (`public.businesses`).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Coordenadas centrales WGS84 en `public.municipality_zones`
-- ---------------------------------------------------------------------------
alter table public.municipality_zones
  add column if not exists center_lat double precision not null default 10.4742
    check (center_lat between -4.5 and 13.5),
  add column if not exists center_lng double precision not null default -73.2436
    check (center_lng between -82.0 and -66.0);

update public.municipality_zones
set center_lat = case id
      when 'vup_norte'     then 10.4885
      when 'vup_centro'    then 10.4742
      when 'vup_sur'       then 10.4452
      when 'vup_oriente'   then 10.4980
      when 'vup_occidente' then 10.4680
      else center_lat
    end,
    center_lng = case id
      when 'vup_norte'     then -73.2535
      when 'vup_centro'    then -73.2436
      when 'vup_sur'       then -73.2468
      when 'vup_oriente'   then -73.2610
      when 'vup_occidente' then -73.2785
      else center_lng
    end
where municipality_code = '20001';

-- ---------------------------------------------------------------------------
-- 2. Extensión de `public.businesses` para mapa y segregación DEMO vs. REAL
-- ---------------------------------------------------------------------------
alter table public.businesses
  alter column owner_id drop not null;

alter table public.businesses
  add column if not exists address varchar(200),
  add column if not exists is_demo boolean not null default false;

alter table public.businesses
  drop constraint if exists businesses_type_check;

alter table public.businesses
  add constraint businesses_type_check
  check (
    type in (
      'restaurant',
      'hotel',
      'service',
      'handicraft',
      'transport',
      'hospital',
      'consulate'
    )
  );

-- Segrega registros demo en consultas directas de tabla para preservar las
-- garantías de RLS (solo negocios reales aprobados o propios).
drop policy if exists businesses_select_public_or_owner on public.businesses;
create policy businesses_select_public_or_owner
  on public.businesses
  for select
  to anon, authenticated
  using (
    (status = 'approved' and is_demo = false)
    or owner_id = auth.uid()
  );

-- Garantiza que el cliente autenticado solo pueda insertar/editar columnas
-- permitidas sin forzar `status = 'approved'` ni `is_demo = true`.
revoke insert, update on public.businesses from authenticated;
grant insert (
  owner_id,
  municipality_code,
  type,
  name,
  description_es,
  description_en,
  address,
  location,
  place_id,
  phone,
  whatsapp,
  whatsapp_consent_at,
  order_url,
  hours
) on public.businesses to authenticated;

grant update (
  name,
  description_es,
  description_en,
  address,
  location,
  place_id,
  phone,
  whatsapp,
  whatsapp_consent_at,
  order_url,
  hours
) on public.businesses to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Helper RPC para registrar negocios con latitud/longitud numéricas
-- ---------------------------------------------------------------------------
create or replace function public.register_business_on_map(
  p_name varchar(150),
  p_type varchar(50),
  p_description_es text,
  p_description_en text default null,
  p_latitude double precision default 10.4742,
  p_longitude double precision default -73.2436,
  p_address varchar(200) default null,
  p_phone varchar(20) default null,
  p_whatsapp varchar(20) default '573000000000',
  p_municipality_code varchar(5) default '20001',
  p_approve_immediately boolean default false
)
returns public.businesses
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := public.is_admin();
  v_is_service boolean := current_user in ('postgres', 'service_role', 'supabase_admin');
  v_status text := 'pending';
  v_inserted public.businesses;
begin
  if v_uid is null and not v_is_service then
    raise exception '[AUTH_REQUIRED] Debes iniciar sesión para registrar un negocio.'
      using errcode = '42501';
  end if;

  if p_latitude < -4.5 or p_latitude > 13.5 or p_longitude < -82.0 or p_longitude > -66.0 then
    raise exception '[BUSINESS_INVALID_LOCATION] Las coordenadas (%, %) están fuera del territorio colombiano.',
      p_latitude, p_longitude
      using errcode = '22023';
  end if;

  if p_approve_immediately and (v_is_admin or v_is_service) then
    v_status := 'approved';
  end if;

  insert into public.businesses (
    owner_id,
    municipality_code,
    type,
    name,
    description_es,
    description_en,
    address,
    location,
    phone,
    whatsapp,
    whatsapp_consent_at,
    status,
    is_demo
  )
  values (
    v_uid,
    coalesce(nullif(btrim(p_municipality_code), ''), '20001'),
    btrim(p_type),
    btrim(p_name),
    btrim(p_description_es),
    coalesce(nullif(btrim(p_description_en), ''), btrim(p_description_es)),
    nullif(btrim(coalesce(p_address, '')), ''),
    extensions.ST_SetSRID(extensions.ST_MakePoint(p_longitude, p_latitude), 4326)::extensions.geography,
    nullif(btrim(coalesce(p_phone, '')), ''),
    coalesce(nullif(btrim(p_whatsapp), ''), '573000000000'),
    now(),
    v_status,
    false
  )
  returning * into v_inserted;

  return v_inserted;
end;
$$;

revoke all on function public.register_business_on_map(
  varchar, varchar, text, text, double precision, double precision, varchar, varchar, varchar, varchar, boolean
) from public, anon;

grant execute on function public.register_business_on_map(
  varchar, varchar, text, text, double precision, double precision, varchar, varchar, varchar, varchar, boolean
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. RPC unificada del mapa (`public.get_municipality_map_items`)
-- ---------------------------------------------------------------------------
create or replace function public.get_municipality_map_items(
  p_municipality_code text default '20001',
  p_category text default null,
  p_min_lat double precision default null,
  p_max_lat double precision default null,
  p_min_lng double precision default null,
  p_max_lng double precision default null,
  p_include_demo boolean default true,
  p_limit integer default 200
)
returns table (
  id text,
  source_type text,
  name_es text,
  name_en text,
  description_es text,
  description_en text,
  map_category text,
  pin_kind text,
  pin_status text,
  pin_label text,
  badge_text text,
  latitude double precision,
  longitude double precision,
  normalized_x double precision,
  normalized_y double precision,
  phone text,
  whatsapp text,
  address text,
  municipality_code text,
  zone_id text,
  amount_cop integer,
  is_demo boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_window_days integer := 60;
  v_min_reports integer := 3;
  v_green_max numeric := 15.0;
  v_yellow_max numeric := 40.0;
  v_effective_limit integer := least(greatest(coalesce(p_limit, 200), 1), 200);
begin
  select
    coalesce((select value::numeric::integer from public.app_config where key = 'report_window_days'), 60),
    coalesce((select value::numeric::integer from public.app_config where key = 'min_reports_for_verdict'), 3),
    coalesce((select value::numeric from public.app_config where key = 'green_max_deviation_pct'), 15.0),
    coalesce((select value::numeric from public.app_config where key = 'yellow_max_deviation_pct'), 40.0)
  into v_window_days, v_min_reports, v_green_max, v_yellow_max;

  return query
  with zone_medians as (
    select
      pr.municipality_code as m_code,
      pr.zone_id as z_id,
      pr.category_id as c_id,
      count(*) filter (where pr.is_demo = false)::integer as real_n,
      percentile_cont(0.5) within group (order by pr.amount_cop::numeric)
        filter (where pr.is_demo = false)::numeric as real_median,
      count(*)::integer as all_n,
      percentile_cont(0.5) within group (order by pr.amount_cop::numeric)::numeric as all_median
    from public.price_reports pr
    where pr.municipality_code = p_municipality_code
      and pr.is_hidden = false
      and (pr.is_demo = false or p_include_demo = true)
      and pr.created_at >= (now() - make_interval(days => v_window_days))
    group by pr.municipality_code, pr.zone_id, pr.category_id
  ),
  price_items as (
    select
      pr.id::text as id,
      'price_report'::text as source_type,
      (
        case when pr.is_demo then '[DEMO] ' else '' end
        || pc.name_es
        || ' · '
        || coalesce(nullif(btrim(pr.place_name), ''), mz.name_es)
      )::text as name_es,
      (
        case when pr.is_demo then '[DEMO] ' else '' end
        || pc.name_en
        || ' · '
        || coalesce(nullif(btrim(pr.place_name), ''), mz.name_en)
      )::text as name_en,
      (
        case
          when pr.is_demo then
            'Muestra DEMO — ' || pc.unit_description_es || ' en ' || mz.name_es
          when coalesce(zm.real_n, 0) >= v_min_reports and zm.real_median > 0 then
            'Reporte ciudadano en ' || mz.name_es || ' (mediana zonal: $'
            || replace(to_char(round(zm.real_median), 'FM999,999,999'), ',', '.')
            || ' COP, N=' || zm.real_n::text || ')'
          else
            'Reporte ciudadano en ' || mz.name_es || ' · ' || pc.unit_description_es
        end
      )::text as description_es,
      (
        case
          when pr.is_demo then
            'DEMO sample — ' || pc.unit_description_en || ' in ' || mz.name_en
          when coalesce(zm.real_n, 0) >= v_min_reports and zm.real_median > 0 then
            'Community report in ' || mz.name_en || ' (zone median: $'
            || to_char(round(zm.real_median), 'FM999,999,999')
            || ' COP, N=' || zm.real_n::text || ')'
          else
            'Community report in ' || mz.name_en || ' · ' || pc.unit_description_en
        end
      )::text as description_en,
      'prices'::text as map_category,
      (
        case pc.group_key
          when 'food'      then 'food'
          when 'transport' then 'transport'
          when 'lodging'   then 'lodging'
          else 'assistance'
        end
      )::text as pin_kind,
      (
        case
          -- Reportes reales: color de veredicto solo si N >= min_reports_for_verdict
          when pr.is_demo = false and coalesce(zm.real_n, 0) >= v_min_reports and coalesce(zm.real_median, 0) > 0 then
            case
              when ((pr.amount_cop::numeric - zm.real_median) / zm.real_median * 100.0) <= v_green_max then 'fair'
              when ((pr.amount_cop::numeric - zm.real_median) / zm.real_median * 100.0) <= v_yellow_max then 'moderate'
              else 'alert'
            end
          -- Reportes reales con N < 3: estado informativo hasta completar muestra
          when pr.is_demo = false then
            'fair'
          -- Reportes demo: usan la mediana del conjunto demo para ilustrar los 3 colores del semáforo
          when pr.is_demo = true and coalesce(zm.all_median, 0) > 0 then
            case
              when ((pr.amount_cop::numeric - zm.all_median) / zm.all_median * 100.0) <= v_green_max then 'fair'
              when ((pr.amount_cop::numeric - zm.all_median) / zm.all_median * 100.0) <= v_yellow_max then 'moderate'
              else 'alert'
            end
          else 'fair'
        end
      )::text as pin_status,
      (
        '$' || greatest(1, round(pr.amount_cop::numeric / 1000.0))::integer::text || 'k'
      )::text as pin_label,
      (
        '$' || replace(to_char(pr.amount_cop, 'FM999,999,999'), ',', '.')
      )::text as badge_text,
      coalesce(
        extensions.ST_Y(pr.location::extensions.geometry),
        mz.center_lat,
        10.4742
      )::double precision as latitude,
      coalesce(
        extensions.ST_X(pr.location::extensions.geometry),
        mz.center_lng,
        -73.2436
      )::double precision as longitude,
      mz.normalized_x::double precision as normalized_x,
      mz.normalized_y::double precision as normalized_y,
      null::text as phone,
      null::text as whatsapp,
      coalesce(pr.place_name, mz.name_es)::text as address,
      pr.municipality_code::text as municipality_code,
      pr.zone_id::text as zone_id,
      pr.amount_cop::integer as amount_cop,
      pr.is_demo::boolean as is_demo,
      pr.created_at as created_at
    from public.price_reports pr
    join public.price_categories pc
      on pc.id = pr.category_id
    join public.municipality_zones mz
      on mz.id = pr.zone_id
     and mz.municipality_code = pr.municipality_code
    left join zone_medians zm
      on zm.m_code = pr.municipality_code
     and zm.z_id = pr.zone_id
     and zm.c_id = pr.category_id
    where pr.municipality_code = p_municipality_code
      and pr.is_hidden = false
      and (pr.is_demo = false or p_include_demo = true)
      and pr.created_at >= (now() - make_interval(days => v_window_days))
  ),
  business_items as (
    select
      b.id::text as id,
      'business'::text as source_type,
      b.name::text as name_es,
      b.name::text as name_en,
      b.description_es::text as description_es,
      b.description_en::text as description_en,
      (
        case
          when b.type = 'consulate' then 'consulates'
          else 'services'
        end
      )::text as map_category,
      (
        case b.type
          when 'restaurant' then 'food'
          when 'hotel'      then 'lodging'
          when 'transport'  then 'transport'
          when 'hospital'   then 'hospital'
          when 'consulate'  then 'consulate'
          else 'assistance'
        end
      )::text as pin_kind,
      'info'::text as pin_status,
      ''::text as pin_label,
      coalesce(
        nullif(btrim(b.address), ''),
        case b.type
          when 'restaurant' then 'Restaurante'
          when 'hotel'      then 'Alojamiento'
          when 'transport'  then 'Transporte'
          when 'hospital'   then 'Salud 24h'
          when 'consulate'  then 'Orientación'
          else 'Servicio local'
        end
      )::text as badge_text,
      extensions.ST_Y(b.location::extensions.geometry)::double precision as latitude,
      extensions.ST_X(b.location::extensions.geometry)::double precision as longitude,
      greatest(0.05, least(0.95, (extensions.ST_X(b.location::extensions.geometry) - (-73.290)) / 0.080))::double precision as normalized_x,
      greatest(0.05, least(0.95, (10.510 - extensions.ST_Y(b.location::extensions.geometry)) / 0.080))::double precision as normalized_y,
      b.phone::text as phone,
      b.whatsapp::text as whatsapp,
      b.address::text as address,
      b.municipality_code::text as municipality_code,
      'vup_centro'::text as zone_id,
      null::integer as amount_cop,
      b.is_demo::boolean as is_demo,
      b.created_at as created_at
    from public.businesses b
    where b.municipality_code = p_municipality_code
      and b.status = 'approved'
      and (b.is_demo = false or p_include_demo = true)
  ),
  combined as (
    select * from price_items
    union all
    select * from business_items
  )
  select
    c.id,
    c.source_type,
    c.name_es,
    c.name_en,
    c.description_es,
    c.description_en,
    c.map_category,
    c.pin_kind,
    c.pin_status,
    c.pin_label,
    c.badge_text,
    c.latitude,
    c.longitude,
    c.normalized_x,
    c.normalized_y,
    c.phone,
    c.whatsapp,
    c.address,
    c.municipality_code,
    c.zone_id,
    c.amount_cop,
    c.is_demo,
    c.created_at
  from combined c
  where (p_category is null or c.map_category = p_category)
    and (p_min_lat is null or c.latitude >= p_min_lat)
    and (p_max_lat is null or c.latitude <= p_max_lat)
    and (p_min_lng is null or c.longitude >= p_min_lng)
    and (p_max_lng is null or c.longitude <= p_max_lng)
  order by c.is_demo asc, c.created_at desc, c.id asc
  limit v_effective_limit;
end;
$$;

comment on function public.get_municipality_map_items(
  text, text, double precision, double precision, double precision, double precision, boolean, integer
) is
  'Devuelve hasta 200 marcadores georreferenciados (reportes de precio + negocios aprobados) dentro del municipio y bounding box indicados.';

revoke all on function public.get_municipality_map_items(
  text, text, double precision, double precision, double precision, double precision, boolean, integer
) from public;

grant execute on function public.get_municipality_map_items(
  text, text, double precision, double precision, double precision, double precision, boolean, integer
) to anon, authenticated, service_role;
