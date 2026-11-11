-- ============================================================================
-- Vía Justa MVP · Migración 0014 · Tarifa de taxi con destino por rangos de
-- distancia en SQL (Paso 2 Rediseño Analizar / VJ-10 / VJ-11 / VJ-12)
-- ============================================================================
-- Implementa en PostgreSQL (única fuente de verdad estadística):
--   1. Funciones geoespaciales SQL puras con PostGIS:
--      * public.calculate_taxi_distance_km(orig_lat, orig_lng, dest_lat, dest_lng)
--      * public.classify_taxi_distance_range(distance_km) -> '0_2_km' | '2_5_km' | 'gt_5_km'
--      * public.resolve_nearest_municipality_zone(municipality_code, lat, lng)
--   2. Columnas en `public.price_reports` para trayectos de taxi:
--      * destination_zone_id, destination_location (ofuscado a 3 decimales ~110m),
--        distance_km y distance_range ('0_2_km', '2_5_km', 'gt_5_km').
--   3. Actualización del trigger `public.enforce_price_report_submission_rules()`
--      para calcular `distance_km` y `distance_range` en SQL y aplicar privacidad
--      geoespacial RN-08 sobre `destination_location`.
--   4. Sobrecarga compatible de `public.submit_price_report` y
--      `public.calculate_price_verdict` / `public.evaluate_price_verdict` que
--      calcula la mediana por `distance_range` cuando se consulta/aporta un taxi
--      con origen y destino en el mapa de Google Maps / GPS.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Funciones SQL de distancia en línea recta y clasificación por rango
-- ---------------------------------------------------------------------------
create or replace function public.calculate_taxi_distance_km(
  p_origin_lat double precision,
  p_origin_lng double precision,
  p_dest_lat double precision,
  p_dest_lng double precision
)
returns numeric
language sql
immutable
parallel safe
set search_path = public, extensions
as $$
  select case
    when p_origin_lat is null or p_origin_lng is null
      or p_dest_lat is null or p_dest_lng is null then null
    else round(
      (
        extensions.ST_Distance(
          extensions.ST_SetSRID(extensions.ST_MakePoint(p_origin_lng, p_origin_lat), 4326)::extensions.geography,
          extensions.ST_SetSRID(extensions.ST_MakePoint(p_dest_lng, p_dest_lat), 4326)::extensions.geography
        ) / 1000.0
      )::numeric,
      2
    )
  end;
$$;

comment on function public.calculate_taxi_distance_km(double precision, double precision, double precision, double precision) is
  'Calcula en SQL la distancia geodésica en línea recta (km, 2 decimales) entre origen y destino usando PostGIS.';

create or replace function public.classify_taxi_distance_range(
  p_distance_km numeric
)
returns varchar(20)
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when p_distance_km is null or p_distance_km < 0 then null
    when p_distance_km <= 2.0 then '0_2_km'::varchar(20)
    when p_distance_km <= 5.0 then '2_5_km'::varchar(20)
    else 'gt_5_km'::varchar(20)
  end;
$$;

comment on function public.classify_taxi_distance_range(numeric) is
  'Clasifica la distancia en línea recta de un taxi en 3 rangos comparables: 0_2_km (0-2 km), 2_5_km (2-5 km) y gt_5_km (>5 km).';

create or replace function public.resolve_nearest_municipality_zone(
  p_municipality_code text,
  p_lat double precision,
  p_lng double precision
)
returns varchar(50)
language sql
stable
set search_path = public, extensions
as $$
  select mz.id
  from public.municipality_zones mz
  where mz.municipality_code = p_municipality_code
    and mz.is_active = true
  order by extensions.ST_Distance(
    extensions.ST_SetSRID(extensions.ST_MakePoint(mz.center_lng, mz.center_lat), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography
  ) asc,
  mz.sort_order asc
  limit 1;
$$;

comment on function public.resolve_nearest_municipality_zone(text, double precision, double precision) is
  'Resuelve la zona municipal activa más cercana a unas coordenadas (lat, lng) dentro del municipio.';

grant execute on function public.calculate_taxi_distance_km(double precision, double precision, double precision, double precision)
  to anon, authenticated;
grant execute on function public.classify_taxi_distance_range(numeric)
  to anon, authenticated;
grant execute on function public.resolve_nearest_municipality_zone(text, double precision, double precision)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Nuevas columnas e índices en `public.price_reports`
-- ---------------------------------------------------------------------------
alter table public.price_reports
  add column if not exists destination_zone_id varchar(50),
  add column if not exists destination_location extensions.geography(Point, 4326),
  add column if not exists distance_km numeric(6, 2),
  add column if not exists distance_range varchar(20);

alter table public.price_reports
  drop constraint if exists price_reports_dest_zone_municipality_fk;

alter table public.price_reports
  add constraint price_reports_dest_zone_municipality_fk
  foreign key (destination_zone_id, municipality_code)
  references public.municipality_zones(id, municipality_code)
  on update cascade
  on delete restrict;

alter table public.price_reports
  drop constraint if exists price_reports_distance_km_check;

alter table public.price_reports
  add constraint price_reports_distance_km_check
  check (distance_km is null or (distance_km >= 0 and distance_km <= 500));

alter table public.price_reports
  drop constraint if exists price_reports_distance_range_check;

alter table public.price_reports
  add constraint price_reports_distance_range_check
  check (distance_range is null or distance_range in ('0_2_km', '2_5_km', 'gt_5_km'));

create index if not exists price_reports_taxi_range_stat_idx
  on public.price_reports (municipality_code, category_id, distance_range, created_at)
  where is_hidden = false and is_demo = false and distance_range is not null;

-- ---------------------------------------------------------------------------
-- 3. Trigger actualizado: privacidad en destino y cálculo SQL de rango de taxi
-- ---------------------------------------------------------------------------
create or replace function public.enforce_price_report_submission_rules()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_rules jsonb;
  v_daily_limit integer := 10;
  v_cooldown_minutes integer := 15;
  v_min_amount integer := 500;
  v_max_amount integer := 20000000;
  v_category_active boolean;
  v_municipality_pilot boolean;
  v_zone_active boolean;
  v_dest_zone_active boolean;
  v_recent_duplicate_count integer := 0;
  v_daily_count integer := 0;
  v_lon numeric;
  v_lat numeric;
  v_dest_lon numeric;
  v_dest_lat numeric;
  v_orig_calc_lat double precision;
  v_orig_calc_lng double precision;
  v_dest_calc_lat double precision;
  v_dest_calc_lng double precision;
begin
  -- 3.1 Saneamiento transversal de campos de texto opcionales
  if new.place_name is not null then
    new.place_name := nullif(
      btrim(pg_catalog.regexp_replace(new.place_name, '[[:cntrl:]]', '', 'g')),
      ''
    );
  end if;

  if new.source_note is not null then
    new.source_note := nullif(
      btrim(pg_catalog.regexp_replace(new.source_note, '[[:cntrl:]]', '', 'g')),
      ''
    );
  end if;

  -- 3.2 Privacidad geoespacial RN-08 (origen y destino redondeados a 3 decimales ~110 m)
  if new.location is not null then
    v_lon := round(extensions.ST_X(new.location::extensions.geometry)::numeric, 3);
    v_lat := round(extensions.ST_Y(new.location::extensions.geometry)::numeric, 3);
    new.location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(v_lon::double precision, v_lat::double precision),
      4326
    )::extensions.geography;
  end if;

  if new.destination_location is not null then
    v_dest_lon := round(extensions.ST_X(new.destination_location::extensions.geometry)::numeric, 3);
    v_dest_lat := round(extensions.ST_Y(new.destination_location::extensions.geometry)::numeric, 3);
    new.destination_location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(v_dest_lon::double precision, v_dest_lat::double precision),
      4326
    )::extensions.geography;
  end if;

  -- 3.3 Cálculo en SQL del rango de distancia cuando la categoría es taxi con destino
  if new.category_id = 'transport_taxi_minimal'
     and (new.destination_location is not null or new.destination_zone_id is not null or new.distance_range is not null) then

    if new.destination_location is not null then
      v_dest_calc_lat := extensions.ST_Y(new.destination_location::extensions.geometry);
      v_dest_calc_lng := extensions.ST_X(new.destination_location::extensions.geometry);
      if new.destination_zone_id is null and new.municipality_code is not null then
        new.destination_zone_id := public.resolve_nearest_municipality_zone(
          new.municipality_code,
          v_dest_calc_lat,
          v_dest_calc_lng
        );
      end if;
    elsif new.destination_zone_id is not null then
      select mz.center_lat, mz.center_lng
        into v_dest_calc_lat, v_dest_calc_lng
        from public.municipality_zones mz
       where mz.id = new.destination_zone_id
         and mz.municipality_code = new.municipality_code;
    end if;

    if new.location is not null then
      v_orig_calc_lat := extensions.ST_Y(new.location::extensions.geometry);
      v_orig_calc_lng := extensions.ST_X(new.location::extensions.geometry);
    elsif new.zone_id is not null then
      select mz.center_lat, mz.center_lng
        into v_orig_calc_lat, v_orig_calc_lng
        from public.municipality_zones mz
       where mz.id = new.zone_id
         and mz.municipality_code = new.municipality_code;
    end if;

    if v_orig_calc_lat is not null and v_orig_calc_lng is not null
       and v_dest_calc_lat is not null and v_dest_calc_lng is not null then
      new.distance_km := public.calculate_taxi_distance_km(
        v_orig_calc_lat,
        v_orig_calc_lng,
        v_dest_calc_lat,
        v_dest_calc_lng
      );
      new.distance_range := public.classify_taxi_distance_range(new.distance_km);
    elsif new.distance_km is not null and new.distance_range is null then
      new.distance_range := public.classify_taxi_distance_range(new.distance_km);
    end if;
  elsif new.category_id <> 'transport_taxi_minimal' then
    new.destination_zone_id := null;
    new.destination_location := null;
    new.distance_km := null;
    new.distance_range := null;
  end if;

  -- 3.4 Reglas estrictas cuando el actor es un cliente (`authenticated` / `anon`)
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    v_actor_id := auth.uid();
    if v_actor_id is null then
      raise exception '[AUTH_UNAUTHORIZED] Se requiere una sesion autenticada para reportar precios.'
        using errcode = '42501';
    end if;

    select ac.value
      into v_rules
      from public.app_config ac
     where ac.key = 'price_verdict_rules';

    if v_rules is not null then
      v_daily_limit := coalesce((v_rules ->> 'daily_report_limit_per_user')::integer, v_daily_limit);
      v_cooldown_minutes := coalesce((v_rules ->> 'duplicate_cooldown_minutes')::integer, v_cooldown_minutes);
      v_min_amount := coalesce((v_rules ->> 'min_report_amount_cop')::integer, v_min_amount);
      v_max_amount := coalesce((v_rules ->> 'max_report_amount_cop')::integer, v_max_amount);
    end if;

    if new.amount_cop is null or new.amount_cop < v_min_amount or new.amount_cop > v_max_amount then
      raise exception '[PRICE_INVALID_AMOUNT] El monto en COP (%) esta fuera del rango permitido (% a %).',
        new.amount_cop, v_min_amount, v_max_amount
        using errcode = '22023';
    end if;

    select pc.is_active
      into v_category_active
      from public.price_categories pc
     where pc.id = new.category_id;

    if v_category_active is distinct from true then
      raise exception '[PRICE_CATEGORY_INACTIVE] La categoria de precio "%" no existe o no esta activa.',
        coalesce(new.category_id, '')
        using errcode = '22023';
    end if;

    select m.is_pilot
      into v_municipality_pilot
      from public.municipalities m
     where m.code = new.municipality_code;

    if v_municipality_pilot is distinct from true then
      raise exception '[PRICE_MUNICIPALITY_NOT_PILOT] El municipio "%" no esta habilitado como piloto activo para aportes.',
        coalesce(new.municipality_code, '')
        using errcode = '22023';
    end if;

    select mz.is_active
      into v_zone_active
      from public.municipality_zones mz
     where mz.id = new.zone_id
       and mz.municipality_code = new.municipality_code;

    if v_zone_active is distinct from true then
      raise exception '[PRICE_ZONE_INACTIVE] La zona "%" no pertenece al municipio "%" o no esta activa.',
        coalesce(new.zone_id, ''), coalesce(new.municipality_code, '')
        using errcode = '22023';
    end if;

    if new.destination_zone_id is not null then
      select mz.is_active
        into v_dest_zone_active
        from public.municipality_zones mz
       where mz.id = new.destination_zone_id
         and mz.municipality_code = new.municipality_code;

      if v_dest_zone_active is distinct from true then
        raise exception '[PRICE_DESTINATION_ZONE_INACTIVE] La zona de destino "%" no pertenece al municipio "%" o no esta activa.',
          coalesce(new.destination_zone_id, ''), coalesce(new.municipality_code, '')
          using errcode = '22023';
      end if;
    end if;

    if tg_op = 'INSERT' then
      if new.user_id is not null and new.user_id <> v_actor_id then
        raise exception '[PERMISSION_DENIED] No puedes registrar reportes a nombre de otro usuario.'
          using errcode = '42501';
      end if;

      new.user_id := v_actor_id;
      new.is_seed := false;
      new.is_hidden := false;
      new.created_at := now();

      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtext('price_reports_rate_limit'),
        pg_catalog.hashtext(v_actor_id::text)
      );

      if v_cooldown_minutes > 0 then
        select count(*)::integer
          into v_recent_duplicate_count
          from public.price_reports pr
         where pr.user_id = v_actor_id
           and pr.municipality_code = new.municipality_code
           and pr.zone_id = new.zone_id
           and coalesce(pr.destination_zone_id, '') = coalesce(new.destination_zone_id, '')
           and coalesce(pr.distance_range, '') = coalesce(new.distance_range, '')
           and pr.category_id = new.category_id
           and pr.amount_cop = new.amount_cop
           and pr.is_demo = new.is_demo
           and pr.created_at >= (now() - make_interval(mins => v_cooldown_minutes));

        if v_recent_duplicate_count > 0 then
          raise exception '[PRICE_DUPLICATE_REPORT] Ya registraste este mismo precio en la zona hace menos de % minutos.',
            v_cooldown_minutes
            using errcode = 'P0001';
        end if;
      end if;

      if new.is_demo = false and v_daily_limit > 0 then
        select count(*)::integer
          into v_daily_count
          from public.price_reports pr
         where pr.user_id = v_actor_id
           and pr.is_demo = false
           and pr.created_at >= (now() - interval '24 hours');

        if v_daily_count >= v_daily_limit then
          raise exception '[PRICE_RATE_LIMITED] Has alcanzado el limite diario de % aportes de precio en 24 horas.',
            v_daily_limit
            using errcode = 'P0001';
        end if;
      end if;

    elsif tg_op = 'UPDATE' then
      if new.user_id is distinct from old.user_id
         or new.category_id is distinct from old.category_id
         or new.municipality_code is distinct from old.municipality_code
         or new.zone_id is distinct from old.zone_id
         or new.destination_zone_id is distinct from old.destination_zone_id
         or new.is_seed is distinct from old.is_seed
         or new.is_hidden is distinct from old.is_hidden
         or new.is_demo is distinct from old.is_demo
         or new.created_at is distinct from old.created_at then
        raise exception '[PERMISSION_DENIED] No se permite alterar metadatos inmutables ni banderas de moderacion del reporte.'
          using errcode = '42501';
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Sobrecarga de `public.submit_price_report` con soporte de destino (11 args)
-- ---------------------------------------------------------------------------
create or replace function public.submit_price_report(
  p_category_id varchar,
  p_municipality_code text,
  p_zone_id varchar,
  p_amount_cop integer,
  p_place_name varchar,
  p_source_note varchar,
  p_latitude double precision,
  p_longitude double precision,
  p_destination_zone_id varchar,
  p_destination_latitude double precision default null,
  p_destination_longitude double precision default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_location extensions.geography(Point, 4326) := null;
  v_dest_location extensions.geography(Point, 4326) := null;
  v_resolved_zone_id varchar(50);
  v_resolved_dest_zone_id varchar(50);
  v_inserted public.price_reports%rowtype;
begin
  if auth.uid() is null then
    raise exception '[AUTH_UNAUTHORIZED] Se requiere una sesion autenticada para aportar un precio.'
      using errcode = '42501';
  end if;

  if (p_latitude is not null and p_longitude is null)
     or (p_latitude is null and p_longitude is not null) then
    raise exception '[PRICE_INVALID_LOCATION] Debes enviar latitud y longitud de origen juntas o ninguna.'
      using errcode = '22023';
  end if;

  if (p_destination_latitude is not null and p_destination_longitude is null)
     or (p_destination_latitude is null and p_destination_longitude is not null) then
    raise exception '[PRICE_INVALID_LOCATION] Debes enviar latitud y longitud de destino juntas o ninguna.'
      using errcode = '22023';
  end if;

  if p_latitude is not null and p_longitude is not null then
    if p_latitude < -4.5 or p_latitude > 13.5 or p_longitude < -82.0 or p_longitude > -66.0 then
      raise exception '[PRICE_INVALID_LOCATION] Las coordenadas de origen estan fuera del territorio colombiano.'
        using errcode = '22023';
    end if;

    v_location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_longitude, p_latitude),
      4326
    )::extensions.geography;
  end if;

  if p_destination_latitude is not null and p_destination_longitude is not null then
    if p_destination_latitude < -4.5 or p_destination_latitude > 13.5
       or p_destination_longitude < -82.0 or p_destination_longitude > -66.0 then
      raise exception '[PRICE_INVALID_LOCATION] Las coordenadas de destino estan fuera del territorio colombiano.'
        using errcode = '22023';
    end if;

    v_dest_location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_destination_longitude, p_destination_latitude),
      4326
    )::extensions.geography;
  end if;

  v_resolved_zone_id := nullif(btrim(coalesce(p_zone_id, '')), '');
  if v_resolved_zone_id is null and p_latitude is not null and p_longitude is not null then
    v_resolved_zone_id := public.resolve_nearest_municipality_zone(
      btrim(p_municipality_code),
      p_latitude,
      p_longitude
    );
  end if;

  v_resolved_dest_zone_id := nullif(btrim(coalesce(p_destination_zone_id, '')), '');
  if v_resolved_dest_zone_id is null and p_destination_latitude is not null and p_destination_longitude is not null then
    v_resolved_dest_zone_id := public.resolve_nearest_municipality_zone(
      btrim(p_municipality_code),
      p_destination_latitude,
      p_destination_longitude
    );
  end if;

  insert into public.price_reports (
    user_id,
    category_id,
    municipality_code,
    zone_id,
    destination_zone_id,
    amount_cop,
    location,
    destination_location,
    place_name,
    source_note,
    is_demo
  )
  values (
    auth.uid(),
    btrim(p_category_id),
    btrim(p_municipality_code),
    coalesce(v_resolved_zone_id, btrim(p_zone_id)),
    v_resolved_dest_zone_id,
    p_amount_cop,
    v_location,
    v_dest_location,
    p_place_name,
    p_source_note,
    false
  )
  returning * into v_inserted;

  return jsonb_build_object(
    'id', v_inserted.id,
    'category_id', v_inserted.category_id,
    'municipality_code', v_inserted.municipality_code,
    'zone_id', v_inserted.zone_id,
    'destination_zone_id', v_inserted.destination_zone_id,
    'distance_km', v_inserted.distance_km,
    'distance_range', v_inserted.distance_range,
    'amount_cop', v_inserted.amount_cop,
    'place_name', v_inserted.place_name,
    'source_note', v_inserted.source_note,
    'is_demo', v_inserted.is_demo,
    'created_at', v_inserted.created_at
  );
end;
$$;

comment on function public.submit_price_report(varchar, text, varchar, integer, varchar, varchar, double precision, double precision, varchar, double precision, double precision) is
  'Registra un aporte ciudadano real de precio (incluyendo destino y rango de distancia en SQL para taxi), validando cuotas y ofuscando GPS a 3 decimales.';

revoke all on function public.submit_price_report(varchar, text, varchar, integer, varchar, varchar, double precision, double precision, varchar, double precision, double precision)
  from public, anon, authenticated;
grant execute on function public.submit_price_report(varchar, text, varchar, integer, varchar, varchar, double precision, double precision, varchar, double precision, double precision)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Función SQL `public.calculate_price_verdict` con soporte de rango de taxi
-- ---------------------------------------------------------------------------
create or replace function public.calculate_price_verdict(
  p_category_id varchar,
  p_municipality_code varchar,
  p_zone_id varchar,
  p_amount_cop integer,
  p_destination_zone_id varchar,
  p_origin_lat double precision default null,
  p_origin_lng double precision default null,
  p_destination_lat double precision default null,
  p_destination_lng double precision default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := auth.uid();
  v_rules jsonb;
  v_window_days integer := 60;
  v_min_reports integer := 3;
  v_threshold_green numeric := 15.0;
  v_threshold_yellow numeric := 40.0;
  v_underpriced_threshold numeric := -40.0;
  v_cap_factor numeric := 1.15;

  v_resolved_zone_id varchar(50);
  v_resolved_dest_zone_id varchar(50);
  v_orig_lat double precision;
  v_orig_lng double precision;
  v_dest_lat double precision;
  v_dest_lng double precision;
  v_distance_km numeric := null;
  v_distance_range varchar(20) := null;
  v_use_taxi_range boolean := false;

  v_sample_count integer := 0;
  v_baseline_median numeric;
  v_baseline_deviation numeric;

  v_event_id uuid;
  v_event_name varchar(150);
  v_event_starts timestamptz;
  v_event_ends timestamptz;
  v_event_is_demo boolean;
  v_event_sample_count integer := 0;
  v_event_median numeric;
  v_event_deviation numeric;
  v_use_event_reference boolean := false;

  v_effective_median numeric;
  v_effective_deviation numeric;
  v_level text;
  v_underpriced_alert boolean := false;
  v_recommended_cap integer;
  v_event_details jsonb := null;
begin
  -- 1. Autorización: requiere sesión autenticada
  if v_caller_id is null then
    raise exception 'AUTH_REQUIRED: authentication is required to evaluate prices'
      using errcode = '42501';
  end if;

  -- 2. Validación de monto en COP
  if p_amount_cop is null or p_amount_cop <= 0 or p_amount_cop > 100000000 then
    raise exception 'INVALID_AMOUNT_COP: amount_cop must be between 1 and 100000000 COP'
      using errcode = '22023';
  end if;

  -- 3. Validación de categoría activa
  if p_category_id is null or not exists (
    select 1
    from public.price_categories c
    where c.id = p_category_id
      and c.is_active = true
  ) then
    raise exception 'INVALID_CATEGORY: category % does not exist or is inactive', p_category_id
      using errcode = '22023';
  end if;

  -- Resolver zona de origen si se enviaron coordenadas precisas y p_zone_id está vacío
  v_resolved_zone_id := nullif(btrim(coalesce(p_zone_id, '')), '');
  if v_resolved_zone_id is null and p_origin_lat is not null and p_origin_lng is not null then
    v_resolved_zone_id := public.resolve_nearest_municipality_zone(
      p_municipality_code,
      p_origin_lat,
      p_origin_lng
    );
  end if;

  if p_municipality_code is null or v_resolved_zone_id is null or not exists (
    select 1
    from public.municipality_zones z
    where z.id = v_resolved_zone_id
      and z.municipality_code = p_municipality_code
      and z.is_active = true
  ) then
    raise exception 'INVALID_ZONE_OR_MUNICIPALITY: zone % does not belong to municipality %', coalesce(v_resolved_zone_id, p_zone_id), p_municipality_code
      using errcode = '22023';
  end if;

  -- 4. Si es taxi y se suministró destino (por coordenadas en el mapa o por zona), calcular rango en SQL
  v_resolved_dest_zone_id := nullif(btrim(coalesce(p_destination_zone_id, '')), '');
  if p_category_id = 'transport_taxi_minimal'
     and (v_resolved_dest_zone_id is not null or (p_destination_lat is not null and p_destination_lng is not null)) then

    if p_origin_lat is not null and p_origin_lng is not null then
      if p_origin_lat < -4.5 or p_origin_lat > 13.5 or p_origin_lng < -82.0 or p_origin_lng > -66.0 then
        raise exception 'INVALID_ORIGIN_COORDINATES: origin coordinates are outside Colombia'
          using errcode = '22023';
      end if;
      v_orig_lat := p_origin_lat;
      v_orig_lng := p_origin_lng;
    else
      select z.center_lat, z.center_lng
        into v_orig_lat, v_orig_lng
        from public.municipality_zones z
       where z.id = v_resolved_zone_id
         and z.municipality_code = p_municipality_code;
    end if;

    if p_destination_lat is not null and p_destination_lng is not null then
      if p_destination_lat < -4.5 or p_destination_lat > 13.5 or p_destination_lng < -82.0 or p_destination_lng > -66.0 then
        raise exception 'INVALID_DESTINATION_COORDINATES: destination coordinates are outside Colombia'
          using errcode = '22023';
      end if;
      v_dest_lat := p_destination_lat;
      v_dest_lng := p_destination_lng;
      if v_resolved_dest_zone_id is null then
        v_resolved_dest_zone_id := public.resolve_nearest_municipality_zone(
          p_municipality_code,
          v_dest_lat,
          v_dest_lng
        );
      end if;
    end if;

    if v_resolved_dest_zone_id is not null then
      if not exists (
        select 1
        from public.municipality_zones z
        where z.id = v_resolved_dest_zone_id
          and z.municipality_code = p_municipality_code
          and z.is_active = true
      ) then
        raise exception 'INVALID_DESTINATION_ZONE: destination zone % does not belong to municipality %',
          v_resolved_dest_zone_id, p_municipality_code
          using errcode = '22023';
      end if;

      if v_dest_lat is null or v_dest_lng is null then
        select z.center_lat, z.center_lng
          into v_dest_lat, v_dest_lng
          from public.municipality_zones z
         where z.id = v_resolved_dest_zone_id
           and z.municipality_code = p_municipality_code;
      end if;
    end if;

    v_distance_km := public.calculate_taxi_distance_km(
      v_orig_lat,
      v_orig_lng,
      v_dest_lat,
      v_dest_lng
    );
    v_distance_range := public.classify_taxi_distance_range(v_distance_km);
    v_use_taxi_range := (v_distance_range is not null);
  end if;

  -- 5. Lectura de parámetros dinámicos desde public.app_config
  select ac.value
  into v_rules
  from public.app_config ac
  where ac.key = 'price_verdict_rules';

  if v_rules is not null then
    v_window_days := coalesce((v_rules ->> 'window_days')::integer, v_window_days);
    v_min_reports := coalesce((v_rules ->> 'min_reports')::integer, v_min_reports);
    v_threshold_green := coalesce((v_rules ->> 'threshold_green')::numeric, v_threshold_green);
    v_threshold_yellow := coalesce((v_rules ->> 'threshold_yellow')::numeric, v_threshold_yellow);
    v_underpriced_threshold := coalesce((v_rules ->> 'underpriced_alert_threshold')::numeric, v_underpriced_threshold);
    v_cap_factor := coalesce((v_rules ->> 'recommended_cap_factor')::numeric, v_cap_factor);
  end if;

  -- 6. Conteo y mediana (percentile_cont(0.5)) en ventana de 60 días:
  --    * Si es taxi con destino -> agrupa por distance_range en el municipio.
  --    * En caso contrario -> agrupa por zone_id como antes.
  if v_use_taxi_range then
    select
      count(*)::integer,
      (percentile_cont(0.5) within group (order by r.amount_cop))::numeric
    into
      v_sample_count,
      v_baseline_median
    from public.price_reports r
    where r.municipality_code = p_municipality_code
      and r.category_id = p_category_id
      and r.distance_range = v_distance_range
      and r.is_hidden = false
      and r.is_demo = false
      and r.created_at >= (now() - make_interval(days => v_window_days));
  else
    select
      count(*)::integer,
      (percentile_cont(0.5) within group (order by r.amount_cop))::numeric
    into
      v_sample_count,
      v_baseline_median
    from public.price_reports r
    where r.municipality_code = p_municipality_code
      and r.zone_id = v_resolved_zone_id
      and r.category_id = p_category_id
      and r.is_hidden = false
      and r.is_demo = false
      and r.created_at >= (now() - make_interval(days => v_window_days));
  end if;

  -- 7. Muestra insuficiente (N < 3 o mediana inválida): sin color ni umbrales
  if v_sample_count < v_min_reports or v_baseline_median is null or v_baseline_median <= 0 then
    return jsonb_build_object(
      'rule_version', 'v1.1',
      'level', 'insufficient',
      'category_id', p_category_id,
      'municipality_code', p_municipality_code,
      'zone_id', v_resolved_zone_id,
      'destination_zone_id', v_resolved_dest_zone_id,
      'distance_km', v_distance_km,
      'distance_range', v_distance_range,
      'amount_cop', p_amount_cop,
      'reference_cop', null,
      'baseline_reference_cop', null,
      'deviation_percent', null,
      'baseline_deviation_percent', null,
      'sample_count', v_sample_count,
      'underpriced_alert', false,
      'recommended_cap_cop', null,
      'window_days', v_window_days,
      'is_event_context', false,
      'event_details', null,
      'is_demo', false
    );
  end if;

  v_baseline_deviation := ((p_amount_cop::numeric - v_baseline_median) / v_baseline_median) * 100.0;

  -- 8. Evaluación de evento activo real (is_demo = false)
  select
    e.id,
    e.name,
    e.starts_at,
    e.ends_at,
    e.is_demo
  into
    v_event_id,
    v_event_name,
    v_event_starts,
    v_event_ends,
    v_event_is_demo
  from public.events e
  where e.municipality_code = p_municipality_code
    and e.is_demo = false
    and now() >= e.starts_at
    and now() <= e.ends_at
  order by e.starts_at desc, e.id asc
  limit 1;

  if v_event_id is not null then
    if v_use_taxi_range then
      select
        count(*)::integer,
        (percentile_cont(0.5) within group (order by r.amount_cop))::numeric
      into
        v_event_sample_count,
        v_event_median
      from public.price_reports r
      where r.municipality_code = p_municipality_code
        and r.category_id = p_category_id
        and r.distance_range = v_distance_range
        and r.is_hidden = false
        and r.is_demo = false
        and r.created_at >= v_event_starts
        and r.created_at <= v_event_ends;
    else
      select
        count(*)::integer,
        (percentile_cont(0.5) within group (order by r.amount_cop))::numeric
      into
        v_event_sample_count,
        v_event_median
      from public.price_reports r
      where r.municipality_code = p_municipality_code
        and r.zone_id = v_resolved_zone_id
        and r.category_id = p_category_id
        and r.is_hidden = false
        and r.is_demo = false
        and r.created_at >= v_event_starts
        and r.created_at <= v_event_ends;
    end if;

    if v_event_sample_count >= v_min_reports and v_event_median is not null and v_event_median > 0 then
      v_use_event_reference := true;
      v_event_deviation := ((p_amount_cop::numeric - v_event_median) / v_event_median) * 100.0;
      v_event_details := jsonb_build_object(
        'event_name', v_event_name,
        'event_reference_cop', round(v_event_median)::integer,
        'event_deviation_pct', round(v_event_deviation, 2),
        'event_sample_count', v_event_sample_count,
        'is_demo', false
      );
    end if;
  end if;

  if v_use_event_reference then
    v_effective_median := v_event_median;
    v_effective_deviation := v_event_deviation;
  else
    v_effective_median := v_baseline_median;
    v_effective_deviation := v_baseline_deviation;
  end if;

  if v_effective_deviation <= v_threshold_green then
    v_level := 'green';
  elsif v_effective_deviation <= v_threshold_yellow then
    v_level := 'yellow';
  else
    v_level := 'red';
  end if;

  v_underpriced_alert := (v_effective_deviation < v_underpriced_threshold);
  v_recommended_cap := round(v_effective_median * v_cap_factor)::integer;

  return jsonb_build_object(
    'rule_version', 'v1.1',
    'level', v_level,
    'category_id', p_category_id,
    'municipality_code', p_municipality_code,
    'zone_id', v_resolved_zone_id,
    'destination_zone_id', v_resolved_dest_zone_id,
    'distance_km', v_distance_km,
    'distance_range', v_distance_range,
    'amount_cop', p_amount_cop,
    'reference_cop', round(v_effective_median)::integer,
    'baseline_reference_cop', round(v_baseline_median)::integer,
    'deviation_percent', round(v_effective_deviation, 2),
    'baseline_deviation_percent', round(v_baseline_deviation, 2),
    'sample_count', v_sample_count,
    'underpriced_alert', v_underpriced_alert,
    'recommended_cap_cop', v_recommended_cap,
    'window_days', v_window_days,
    'is_event_context', v_use_event_reference,
    'event_details', v_event_details,
    'is_demo', false
  );
end;
$$;

comment on function public.calculate_price_verdict(varchar, varchar, varchar, integer, varchar, double precision, double precision, double precision, double precision) is
  'Única fuente de verdad del semáforo de precios (v1.1). Soporta cálculo de rango de distancia en SQL (0_2_km, 2_5_km, gt_5_km) para taxi con origen y destino precisos.';

-- Mantener sobrecarga de 4 argumentos delegando en la versión de 9 argumentos
create or replace function public.calculate_price_verdict(
  p_category_id varchar,
  p_municipality_code varchar,
  p_zone_id varchar,
  p_amount_cop integer
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.calculate_price_verdict(
    p_category_id,
    p_municipality_code,
    p_zone_id,
    p_amount_cop,
    null::varchar,
    null::double precision,
    null::double precision,
    null::double precision,
    null::double precision
  );
$$;

create or replace function public.evaluate_price_verdict(
  p_category_id varchar,
  p_municipality_code varchar,
  p_zone_id varchar,
  p_amount_cop integer,
  p_destination_zone_id varchar,
  p_origin_lat double precision default null,
  p_origin_lng double precision default null,
  p_destination_lat double precision default null,
  p_destination_lng double precision default null
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select public.calculate_price_verdict(
    p_category_id,
    p_municipality_code,
    p_zone_id,
    p_amount_cop,
    p_destination_zone_id,
    p_origin_lat,
    p_origin_lng,
    p_destination_lat,
    p_destination_lng
  );
$$;

revoke all on function public.calculate_price_verdict(varchar, varchar, varchar, integer, varchar, double precision, double precision, double precision, double precision)
  from public, anon;
grant execute on function public.calculate_price_verdict(varchar, varchar, varchar, integer, varchar, double precision, double precision, double precision, double precision)
  to authenticated;

revoke all on function public.calculate_price_verdict(varchar, varchar, varchar, integer)
  from public, anon;
grant execute on function public.calculate_price_verdict(varchar, varchar, varchar, integer)
  to authenticated;

revoke all on function public.evaluate_price_verdict(varchar, varchar, varchar, integer, varchar, double precision, double precision, double precision, double precision)
  from public, anon;
grant execute on function public.evaluate_price_verdict(varchar, varchar, varchar, integer, varchar, double precision, double precision, double precision, double precision)
  to authenticated;
