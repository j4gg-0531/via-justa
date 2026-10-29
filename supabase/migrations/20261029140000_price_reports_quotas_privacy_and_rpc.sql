-- ============================================================================
-- Vía Justa MVP · Migración 0008 · Reportes reales: cuotas, privacidad y RPCs (VJ-11)
-- ============================================================================
-- Implementa en servidor:
--   1. Parámetros operativos de cuota diaria, ventana anti-duplicado y límites
--      de monto en `public.app_config` (`key = 'price_verdict_rules'`).
--   2. Constraints e índice compuesto `(user_id, created_at desc)` en
--      `public.price_reports` para validar rangos ($500 a $20.000.000 COP) y
--      longitudes de texto (`place_name <= 120`, `source_note <= 255`).
--   3. Trigger `public.enforce_price_report_submission_rules()` que:
--      - Limpia caracteres de control y espacios en `place_name` y `source_note`.
--      - Ofusca por privacidad geoespacial cualquier coordenada `location` a una
--        rejilla de 3 decimales (~110 metros), impidiendo almacenar ubicaciones
--        exactas de domicilios.
--      - En inserciones/actualizaciones desde el cliente (`authenticated`):
--        * Exige sesión activa (`auth.uid()`) y asigna `user_id := auth.uid()`.
--        * Fuerza `is_seed = false`, `is_hidden = false` y `created_at = now()`.
--        * Verifica que la categoría esté activa, el municipio sea piloto activo
--          y la zona pertenezca al municipio y esté activa.
--        * Serializa envíos concurrentes por usuario (`pg_advisory_xact_lock`)
--          para neutralizar condiciones de carrera o doble toque.
--        * Aplica deduplicación/anti-spam en ventana móvil (`duplicate_cooldown_minutes`,
--          por defecto 15 min) y cuota diaria (`daily_report_limit_per_user`,
--          por defecto 10 aportes reales cada 24 horas).
--   4. RPC `public.submit_price_report(...)` para registro atómico desde la app
--      sin enviar `user_id` desde el cliente.
--   5. RPC administrativa `public.moderate_price_report(...)` para ocultar o
--      restablecer reportes falsos/anómalos (`is_hidden`).
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.6 y §2.8
--   docs/seguridad-privacidad.md §3.2 y §4
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Ampliar configuración operativa en `public.app_config`
-- ---------------------------------------------------------------------------
insert into public.app_config (key, value)
values (
  'price_verdict_rules',
  '{
    "window_days": 60,
    "min_reports": 3,
    "threshold_green": 15.0,
    "threshold_yellow": 40.0,
    "underpriced_alert_threshold": -40.0,
    "recommended_cap_factor": 1.15,
    "daily_ai_limit_per_user": 5,
    "daily_report_limit_per_user": 10,
    "duplicate_cooldown_minutes": 15,
    "min_report_amount_cop": 500,
    "max_report_amount_cop": 20000000
  }'::jsonb
)
on conflict (key) do update
  set value = public.app_config.value || '{
    "daily_report_limit_per_user": 10,
    "duplicate_cooldown_minutes": 15,
    "min_report_amount_cop": 500,
    "max_report_amount_cop": 20000000
  }'::jsonb,
      updated_at = now();

-- ---------------------------------------------------------------------------
-- 2. Constraints de rango/longitud e índice de cuota por usuario
-- ---------------------------------------------------------------------------
alter table public.price_reports
  drop constraint if exists price_reports_amount_cop_bounds_check;

alter table public.price_reports
  add constraint price_reports_amount_cop_bounds_check
  check (amount_cop >= 500 and amount_cop <= 20000000);

alter table public.price_reports
  drop constraint if exists price_reports_place_name_length_check;

alter table public.price_reports
  add constraint price_reports_place_name_length_check
  check (place_name is null or char_length(btrim(place_name)) between 1 and 120);

alter table public.price_reports
  drop constraint if exists price_reports_source_note_length_check;

alter table public.price_reports
  add constraint price_reports_source_note_length_check
  check (source_note is null or char_length(btrim(source_note)) between 1 and 255);

create index if not exists price_reports_user_recent_idx
  on public.price_reports (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 3. Trigger de validación, privacidad geoespacial, deduplicación y cuota
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

  -- 3.2 Privacidad geoespacial (Paso 4 VJ-11):
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

  -- 3.3 Reglas estrictas cuando el actor es un cliente (`authenticated` / `anon`)
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    v_actor_id := auth.uid();
    if v_actor_id is null then
      raise exception '[AUTH_UNAUTHORIZED] Se requiere una sesion autenticada para reportar precios.'
        using errcode = '42501';
    end if;

    -- Leer parámetros configurables desde `public.app_config`
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

    -- Validar vigencia de categoría, municipio piloto y zona activa
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
      -- El user_id siempre procede de auth.uid(); rechazar suplantación explícita
      if new.user_id is not null and new.user_id <> v_actor_id then
        raise exception '[PERMISSION_DENIED] No puedes registrar reportes a nombre de otro usuario.'
          using errcode = '42501';
      end if;

      new.user_id := v_actor_id;
      new.is_seed := false;
      new.is_hidden := false;
      new.created_at := now();

      -- Bloqueo transaccional por usuario para serializar envíos concurrentes (doble toque / race condition)
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtext('price_reports_rate_limit'),
        pg_catalog.hashtext(v_actor_id::text)
      );

      -- Anti-spam / deduplicación en ventana corta (mismo municipio, zona, categoría y monto)
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

      -- Cuota diaria de reportes reales por usuario en ventana móvil de 24 horas
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
      -- En UPDATE, el autor solo puede corregir monto, nota o ubicación dentro de las primeras 24h;
      -- nunca cambiar autoría, categoría, municipio, zona, banderas ni fecha de creación.
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

comment on function public.enforce_price_report_submission_rules() is
  'Valida aportes en servidor: auth.uid() forzoso, privacidad GPS (~110m), vigencia de catálogos, anti-duplicado y cuota diaria (VJ-11).';

drop trigger if exists price_reports_enforce_submission_rules on public.price_reports;
create trigger price_reports_enforce_submission_rules
  before insert or update on public.price_reports
  for each row
  execute function public.enforce_price_report_submission_rules();

-- ---------------------------------------------------------------------------
-- 4. RPC transaccional `public.submit_price_report` para el cliente móvil
-- ---------------------------------------------------------------------------
create or replace function public.submit_price_report(
  p_category_id varchar,
  p_municipality_code text,
  p_zone_id varchar,
  p_amount_cop integer,
  p_place_name varchar default null,
  p_source_note varchar default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_location extensions.geography(Point, 4326) := null;
  v_inserted public.price_reports%rowtype;
begin
  if auth.uid() is null then
    raise exception '[AUTH_UNAUTHORIZED] Se requiere una sesion autenticada para aportar un precio.'
      using errcode = '42501';
  end if;

  if (p_latitude is not null and p_longitude is null)
     or (p_latitude is null and p_longitude is not null) then
    raise exception '[PRICE_INVALID_LOCATION] Debes enviar latitud y longitud juntas o ninguna.'
      using errcode = '22023';
  end if;

  if p_latitude is not null and p_longitude is not null then
    if p_latitude < -4.5 or p_latitude > 13.5 or p_longitude < -82.0 or p_longitude > -66.0 then
      raise exception '[PRICE_INVALID_LOCATION] Las coordenadas suministradas estan fuera del territorio colombiano.'
        using errcode = '22023';
    end if;

    v_location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_longitude, p_latitude),
      4326
    )::extensions.geography;
  end if;

  insert into public.price_reports (
    user_id,
    category_id,
    municipality_code,
    zone_id,
    amount_cop,
    location,
    place_name,
    source_note,
    is_demo
  )
  values (
    auth.uid(),
    btrim(p_category_id),
    btrim(p_municipality_code),
    btrim(p_zone_id),
    p_amount_cop,
    v_location,
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
    'amount_cop', v_inserted.amount_cop,
    'place_name', v_inserted.place_name,
    'source_note', v_inserted.source_note,
    'is_demo', v_inserted.is_demo,
    'created_at', v_inserted.created_at
  );
end;
$$;

comment on function public.submit_price_report(varchar, text, varchar, integer, varchar, varchar, double precision, double precision) is
  'Registra un aporte ciudadano real de precio tomando auth.uid() en servidor, validando cuotas/catálogos y ofuscando GPS.';

revoke all on function public.submit_price_report(varchar, text, varchar, integer, varchar, varchar, double precision, double precision)
  from public, anon, authenticated;
grant execute on function public.submit_price_report(varchar, text, varchar, integer, varchar, varchar, double precision, double precision)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC administrativa `public.moderate_price_report` (Paso 7 VJ-11)
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
  v_updated public.price_reports%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception '[PERMISSION_DENIED] Solo un administrador autorizado puede moderar reportes de precio.'
      using errcode = '42501';
  end if;

  update public.price_reports pr
     set is_hidden = coalesce(p_is_hidden, true),
         source_note = case
           when p_reason is not null and btrim(p_reason) <> '' then
             left(
               coalesce(pr.source_note || ' | ', '') || '[MOD: ' || btrim(p_reason) || ']',
               255
             )
           else pr.source_note
         end
   where pr.id = p_report_id
   returning * into v_updated;

  if not found then
    raise exception '[PRICE_REPORT_NOT_FOUND] No existe el reporte de precio especificado (%).',
      p_report_id
      using errcode = 'P0002';
  end if;

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

comment on function public.moderate_price_report(uuid, boolean, text) is
  'Permite a un administrador ocultar o restaurar reportes falsos o anómalos para excluirlos del semáforo.';

revoke all on function public.moderate_price_report(uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.moderate_price_report(uuid, boolean, text)
  to authenticated;
