-- ============================================================================
-- Vía Justa MVP · VJ-18 · Cierre cruzado de seguridad, privacidad y confiabilidad
-- ============================================================================
-- Objetivo (PLAN_MAESTRO §VJ-18 y §10 Gate G2):
--   1. Completar el protocolo transaccional `public.delete_my_account()`
--      (RF-06 / Ley 1581 de 2012) para cubrir todas las entidades introducidas
--      entre VJ-07 y VJ-17:
--        * Saneamiento previo de `public.price_reports` (`source_note = null`,
--          `place_name = null`, `location = null`) conservando solo el dato
--          estadístico anónimo.
--        * Desvinculación de `reviewed_by` en `public.businesses`.
--        * Eliminación de negocios propios (`public.businesses`, con cascada a
--          `business_photos` y `business_dishes`, dejando trazabilidad inmediata
--          en `public.list_orphan_business_media` para limpieza de Storage).
--        * Eliminación explícita de `public.ai_usage`, `public.consents`,
--          `public.interest_registrations` y `public.admin_users`.
--        * Eliminación final en `auth.users` (cascada a `public.profiles` y
--          `ON DELETE SET NULL` en `public.price_reports.user_id`).
--   2. Unificar la detección del rol llamador en `public.enforce_price_report_submission_rules()`
--      usando `private.is_privileged_caller()` (`current_setting('role', true)`)
--      y reforzar el saneamiento contra etiquetas HTML (`<[^>]*>`) en
--      `place_name` y `source_note`.
--   3. Endurecer `public.moderate_price_report(...)` con bloqueo de auto-moderación
--      (`[MODERATION_SELF_REVIEW]`) y soporte para `private.is_privileged_caller()`.
--   4. Añadir defensa en profundidad interna en `public.consume_ai_daily_quota`
--      y `public.refund_ai_daily_quota` para exigir `private.is_privileged_caller()`.
--   5. Revocar privilegios implícitos de `PUBLIC` sobre todas las funciones de
--      `public` y `private`, y fijar `ALTER DEFAULT PRIVILEGES` restrictivos.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Privilegios por defecto restrictivos en esquemas `public` y `private`
-- ---------------------------------------------------------------------------
alter default privileges in schema public
  revoke all on tables from public, anon, authenticated;

alter default privileges in schema public
  revoke all on functions from public, anon, authenticated;

alter default privileges in schema public
  revoke all on sequences from public, anon, authenticated;

alter default privileges in schema private
  revoke all on tables from public, anon, authenticated;

alter default privileges in schema private
  revoke all on functions from public, anon, authenticated;

-- Revocar ejecución pública implícita en funciones utilitarias y de trigger
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated, service_role;

revoke all on function public.is_valid_business_hours(jsonb) from public;
grant execute on function public.is_valid_business_hours(jsonb) to anon, authenticated, service_role;

revoke all on function public.uri_encode_component(text) from public;
grant execute on function public.uri_encode_component(text) to anon, authenticated, service_role;

revoke all on function public.build_business_whatsapp_url(text, text, text) from public;
grant execute on function public.build_business_whatsapp_url(text, text, text) to anon, authenticated, service_role;

revoke all on function public.build_business_maps_url(double precision, double precision, text) from public;
grant execute on function public.build_business_maps_url(double precision, double precision, text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Endurecimiento de `public.enforce_price_report_submission_rules()`
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
  v_recent_duplicate_count integer := 0;
  v_daily_count integer := 0;
  v_lon numeric;
  v_lat numeric;
begin
  -- 2.1 Saneamiento transversal de campos de texto opcionales (sin control chars ni HTML)
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

  -- 2.2 Privacidad geoespacial (VJ-11 / Ley 1581):
  -- Redondea cualquier coordenada GPS a 3 decimales (~110 m de resolución urbana)
  -- para no almacenar jamás la ubicación exacta del domicilio del ciudadano.
  if new.location is not null then
    v_lon := round(extensions.ST_X(new.location::extensions.geometry)::numeric, 3);
    v_lat := round(extensions.ST_Y(new.location::extensions.geometry)::numeric, 3);
    new.location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(v_lon::double precision, v_lat::double precision),
      4326
    )::extensions.geography;
  end if;

  -- 2.3 Reglas estrictas cuando el actor es un cliente (`authenticated` / `anon`),
  -- evaluado tanto por `private.is_privileged_caller()` como por `current_user`.
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

revoke all on function public.enforce_price_report_submission_rules() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Endurecimiento de `public.moderate_price_report(...)`
-- ---------------------------------------------------------------------------
create or replace function public.moderate_price_report(
  p_report_id uuid,
  p_is_hidden boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_privileged boolean := private.is_privileged_caller();
  v_existing public.price_reports%rowtype;
  v_updated public.price_reports%rowtype;
  v_clean_reason text := nullif(
    btrim(pg_catalog.regexp_replace(coalesce(p_reason, ''), '[[:cntrl:]<>]', '', 'g')),
    ''
  );
begin
  if not v_privileged and (auth.uid() is null or not public.is_admin()) then
    raise exception '[PERMISSION_DENIED] Solo un administrador autorizado puede moderar reportes de precio.'
      using errcode = '42501';
  end if;

  select *
    into v_existing
    from public.price_reports pr
   where pr.id = p_report_id
   for update;

  if not found then
    raise exception '[PRICE_REPORT_NOT_FOUND] No existe el reporte de precio especificado (%).',
      p_report_id
      using errcode = 'P0002';
  end if;

  if not v_privileged and v_existing.user_id = auth.uid() and coalesce(p_is_hidden, true) = false then
    raise exception '[MODERATION_SELF_REVIEW] Un administrador no puede restaurar su propio reporte oculto.'
      using errcode = '42501';
  end if;

  update public.price_reports pr
     set is_hidden = coalesce(p_is_hidden, true),
         source_note = case
           when v_clean_reason is not null then
             left(
               coalesce(pr.source_note || ' | ', '') || '[MOD: ' || v_clean_reason || ']',
               255
             )
           else pr.source_note
         end
   where pr.id = p_report_id
   returning * into v_updated;

  return jsonb_build_object(
    'id', v_updated.id,
    'is_hidden', v_updated.is_hidden,
    'category_id', v_updated.category_id,
    'municipality_code', v_updated.municipality_code,
    'zone_id', v_updated.zone_id,
    'amount_cop', v_updated.amount_cop
  );
end;
$$;

revoke all on function public.moderate_price_report(uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.moderate_price_report(uuid, boolean, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Defensa en profundidad interna en cuotas de IA (`service_role` exclusivo)
-- ---------------------------------------------------------------------------
create or replace function public.consume_ai_daily_quota(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'America/Bogota')::date;
  v_rules jsonb;
  v_daily_limit integer := 5;
  v_current_count integer := 0;
  v_new_count integer := 0;
begin
  if not private.is_privileged_caller() then
    raise exception '[AUTH_FORBIDDEN] consume_ai_daily_quota es exclusiva de servidor (service_role).'
      using errcode = '42501';
  end if;

  if p_user_id is null then
    raise exception '[AUTH_UNAUTHORIZED] Se requiere un user_id valido para consumir cuota de IA.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception '[AUTH_UNAUTHORIZED] El usuario especificado no existe en auth.users.'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('ai_usage_quota'),
    pg_catalog.hashtext(p_user_id::text || ':' || v_today::text)
  );

  select ac.value
    into v_rules
    from public.app_config ac
   where ac.key = 'price_verdict_rules';

  if v_rules is not null then
    v_daily_limit := coalesce((v_rules ->> 'daily_ai_limit_per_user')::integer, v_daily_limit);
  end if;

  if v_daily_limit <= 0 then
    v_daily_limit := 5;
  end if;

  select au.count
    into v_current_count
    from public.ai_usage au
   where au.user_id = p_user_id
     and au.day = v_today;

  v_current_count := coalesce(v_current_count, 0);

  if v_current_count >= v_daily_limit then
    return jsonb_build_object(
      'allowed', false,
      'code', 'AI_DAILY_LIMIT_EXCEEDED',
      'day', v_today::text,
      'timezone', 'America/Bogota',
      'used_count', v_current_count,
      'daily_limit', v_daily_limit,
      'remaining', 0
    );
  end if;

  insert into public.ai_usage (user_id, day, count)
  values (p_user_id, v_today, 1)
  on conflict (user_id, day) do update
    set count = public.ai_usage.count + 1
  returning count into v_new_count;

  return jsonb_build_object(
    'allowed', true,
    'code', 'OK',
    'day', v_today::text,
    'timezone', 'America/Bogota',
    'used_count', v_new_count,
    'daily_limit', v_daily_limit,
    'remaining', greatest(v_daily_limit - v_new_count, 0)
  );
end;
$$;

revoke all on function public.consume_ai_daily_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_ai_daily_quota(uuid)
  to service_role;

create or replace function public.refund_ai_daily_quota(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'America/Bogota')::date;
  v_rules jsonb;
  v_daily_limit integer := 5;
  v_new_count integer := 0;
begin
  if not private.is_privileged_caller() then
    raise exception '[AUTH_FORBIDDEN] refund_ai_daily_quota es exclusiva de servidor (service_role).'
      using errcode = '42501';
  end if;

  if p_user_id is null then
    raise exception '[AUTH_UNAUTHORIZED] Se requiere un user_id valido para reintegrar cuota de IA.'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('ai_usage_quota'),
    pg_catalog.hashtext(p_user_id::text || ':' || v_today::text)
  );

  select ac.value
    into v_rules
    from public.app_config ac
   where ac.key = 'price_verdict_rules';

  if v_rules is not null then
    v_daily_limit := coalesce((v_rules ->> 'daily_ai_limit_per_user')::integer, v_daily_limit);
  end if;

  update public.ai_usage au
     set count = greatest(au.count - 1, 0)
   where au.user_id = p_user_id
     and au.day = v_today
  returning au.count into v_new_count;

  v_new_count := coalesce(v_new_count, 0);

  return jsonb_build_object(
    'refunded', true,
    'day', v_today::text,
    'timezone', 'America/Bogota',
    'used_count', v_new_count,
    'daily_limit', v_daily_limit,
    'remaining', greatest(v_daily_limit - v_new_count, 0)
  );
end;
$$;

revoke all on function public.refund_ai_daily_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.refund_ai_daily_quota(uuid)
  to service_role;

-- ---------------------------------------------------------------------------
-- 5. Protocolo transaccional integral `public.delete_my_account()` (RF-06 / VJ-18)
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

  -- Serializa ejecuciones concurrentes de baja sobre la misma cuenta
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('delete_my_account'),
    pg_catalog.hashtext(v_user_id::text)
  );

  -- Fase 1: Depuración contextual y saneamiento espacial en reportes antes de
  -- desvincular la llave foránea (Ley 1581 de 2012, §2.6 del contrato).
  update public.price_reports
     set source_note = null,
         place_name = null,
         location = null
   where user_id = v_user_id;

  -- Fase 2: Desvinculación de auditoría de moderación si el usuario fue revisor
  update public.businesses
     set reviewed_by = null
   where reviewed_by = v_user_id;

  -- Fase 3: Eliminación de negocios propios (cascada automática a business_photos
  -- y business_dishes; los objetos de Storage quedan inmediatamente listados por
  -- public.list_orphan_business_media con razón 'business_deleted').
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

  -- Fase 5: Supresión final en auth.users.
  -- Elimina en cascada public.profiles (ON DELETE CASCADE) y desvincula
  -- public.price_reports.user_id = NULL (ON DELETE SET NULL).
  delete from auth.users
   where id = v_user_id;
end;
$$;

comment on function public.delete_my_account() is
  'VJ-18 / RF-06 (Ley 1581): elimina la cuenta del usuario autenticado tras sanear price_reports y suprimir negocios, platos, fotos, cuotas de IA, consentimientos e intereses.';

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
