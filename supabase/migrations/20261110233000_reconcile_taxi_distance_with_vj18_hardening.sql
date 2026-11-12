-- ============================================================================
-- Vía Justa MVP · Migración 0016 · Conciliación de Taxi por Distancia
-- (`20261101100000`) con el Endurecimiento Cruzado de Seguridad (`VJ-18`)
-- ============================================================================
-- Objetivo:
--   1. Garantizar que tras ejecutar `20261108220000` (en `supabase db reset`
--      local o en la nube), el trigger `public.enforce_price_report_submission_rules()`
--      conserve TANTO el cálculo automático de `destination_zone_id`,
--      `destination_location` (redondeo a 3 decimales), `distance_km` y
--      `distance_range` (`0_2_km`, `2_5_km`, `gt_5_km`) de `20261101100000`,
--      COMO el blindaje anti-HTML (`<[^>]*>`) y `private.is_privileged_caller()`
--      de `20261108220000` (VJ-18).
--   2. Actualizar `public.delete_my_account()` (RF-06 / Ley 1581) para que en
--      la Fase 1 de saneamiento espacial disocie también `destination_location = null`.
--   3. Revocar privilegios implícitos de `PUBLIC` sobre las nuevas funciones
--      geoespaciales de taxi para mantener el invariante de mínimo privilegio.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Higiene de privilegios sobre funciones geoespaciales de taxi
-- ---------------------------------------------------------------------------
revoke all on function public.calculate_taxi_distance_km(double precision, double precision, double precision, double precision)
  from public;
grant execute on function public.calculate_taxi_distance_km(double precision, double precision, double precision, double precision)
  to anon, authenticated, service_role;

revoke all on function public.classify_taxi_distance_range(numeric)
  from public;
grant execute on function public.classify_taxi_distance_range(numeric)
  to anon, authenticated, service_role;

revoke all on function public.resolve_nearest_municipality_zone(text, double precision, double precision)
  from public;
grant execute on function public.resolve_nearest_municipality_zone(text, double precision, double precision)
  to anon, authenticated, service_role;

-- Asegurar permisos de columna para que `authenticated` pueda insertar trayectos de taxi
grant insert (
  user_id,
  category_id,
  municipality_code,
  zone_id,
  destination_zone_id,
  amount_cop,
  location,
  destination_location,
  distance_km,
  distance_range,
  place_name,
  source_note,
  is_demo
) on public.price_reports to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Trigger unificado `public.enforce_price_report_submission_rules()`
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
  -- 2.1 Saneamiento transversal de texto (sin caracteres de control ni etiquetas HTML)
  if new.place_name is not null then
    new.place_name := nullif(
      btrim(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(new.place_name, '<[^>]*>', '', 'g'),
          '[[:cntrl:]<>]',
          '',
          'g'
        )
      ),
      ''
    );
  end if;

  if new.source_note is not null then
    new.source_note := nullif(
      btrim(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(new.source_note, '<[^>]*>', '', 'g'),
          '[[:cntrl:]<>]',
          '',
          'g'
        )
      ),
      ''
    );
  end if;

  -- 2.2 Privacidad geoespacial RN-08 (origen y destino redondeados a 3 decimales ~110 m)
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

  -- 2.3 Cálculo en SQL del rango de distancia cuando la categoría es taxi con destino
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

  -- 2.4 Reglas estrictas cuando el actor es un cliente (`authenticated` / `anon`)
  if (not private.is_privileged_caller() or current_user in ('authenticated', 'anon'))
     and not public.is_admin() then
    v_actor_id := auth.uid();
    if v_actor_id is null or coalesce(current_setting('role', true), '') = 'anon' then
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

revoke all on function public.enforce_price_report_submission_rules()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Actualizar `public.delete_my_account()` para limpiar también `destination_location`
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or coalesce(current_setting('role', true), '') = 'anon' then
    raise exception 'AUTH_REQUIRED: must be authenticated to delete account'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('delete_my_account'),
    pg_catalog.hashtext(v_user_id::text)
  );

  -- Fase 1: Depuración contextual y saneamiento espacial (origen y destino) en reportes
  update public.price_reports
     set source_note = null,
         place_name = null,
         location = null,
         destination_location = null
   where user_id = v_user_id;

  -- Fase 2: Desvinculación de auditoría de moderación si el usuario fue revisor
  update public.businesses
     set reviewed_by = null
   where reviewed_by = v_user_id;

  -- Fase 3: Eliminación de negocios propios (cascada a business_photos y business_dishes)
  delete from public.businesses
   where owner_id = v_user_id;

  -- Fase 4: Supresión explícita de registros personales directos y cuotas
  delete from public.ai_usage
   where user_id = v_user_id;

  delete from public.consents
   where user_id = v_user_id;

  delete from public.interest_registrations
   where user_id = v_user_id;

  delete from public.admin_users
   where user_id = v_user_id;

  -- Fase 5: Supresión final en auth.users
  delete from auth.users
   where id = v_user_id;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
