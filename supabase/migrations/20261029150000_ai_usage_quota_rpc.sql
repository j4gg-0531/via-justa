-- ============================================================================
-- Vía Justa MVP · Migración 0009 · Cuota diaria atómica de IA en `ai_usage` (VJ-14)
-- ============================================================================
-- Implementa en servidor el control transaccional de cuota diaria para la
-- Edge Function `analyze_contract`:
--   1. `public.consume_ai_daily_quota(p_user_id uuid)`:
--      - Exclusiva de `service_role` (invocada desde la Edge Function tras
--        verificar el JWT del usuario autenticado).
--      - Utiliza la zona horaria oficial de Colombia (`America/Bogota`, UTC-5)
--        para determinar el día calendario (`day`).
--      - Lee `daily_ai_limit_per_user` (por defecto 5) desde `public.app_config`.
--      - Serializa peticiones simultáneas del mismo usuario/día mediante
--        `pg_advisory_xact_lock`, impidiendo condiciones de carrera.
--      - Si `count < daily_limit`, incrementa atómicamente y retorna
--        `allowed = true`. Si ya alcanzó el tope, retorna `allowed = false` y
--        `code = 'AI_DAILY_LIMIT_EXCEEDED'`.
--   2. `public.refund_ai_daily_quota(p_user_id uuid)`:
--      - Exclusiva de `service_role`.
--      - Reintegra 1 unidad de cuota (`greatest(count - 1, 0)`) cuando la llamada
--        posterior al proveedor externo (Gemini) falla por timeout, error 502/503
--        o respuesta corrupta, garantizando que el reintento del usuario no
--        duplique cargos ni consuma cuota por fallos de infraestructura.
--   3. `public.get_my_ai_quota_status()`:
--      - Ejecutable por `authenticated` para consultar su propio saldo diario
--        sin abrir acceso directo a la tabla `public.ai_usage`.
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.9 y §4.3
--   docs/seguridad-privacidad.md §4 y §5.2
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Reserva atómica de cuota diaria (`service_role` únicamente)
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
  if p_user_id is null then
    raise exception '[AUTH_UNAUTHORIZED] Se requiere un user_id valido para consumir cuota de IA.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception '[AUTH_UNAUTHORIZED] El usuario especificado no existe en auth.users.'
      using errcode = '42501';
  end if;

  -- Serializar peticiones concurrentes del mismo usuario en el mismo día (America/Bogota)
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

comment on function public.consume_ai_daily_quota(uuid) is
  'Reserva atómicamente 1 análisis diario de contrato en public.ai_usage (zona America/Bogota). Exclusiva de service_role.';

revoke all on function public.consume_ai_daily_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_ai_daily_quota(uuid)
  to service_role;

-- ---------------------------------------------------------------------------
-- 2. Reintegro atómico de cuota ante fallo del proveedor LLM (`service_role`)
-- ---------------------------------------------------------------------------
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

comment on function public.refund_ai_daily_quota(uuid) is
  'Reintegra 1 unidad de cuota en public.ai_usage si la llamada a Gemini falla por error de red/proveedor. Exclusiva de service_role.';

revoke all on function public.refund_ai_daily_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.refund_ai_daily_quota(uuid)
  to service_role;

-- ---------------------------------------------------------------------------
-- 3. Consulta segura del estado de cuota propia (`authenticated`)
-- ---------------------------------------------------------------------------
create or replace function public.get_my_ai_quota_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_today date := (now() at time zone 'America/Bogota')::date;
  v_rules jsonb;
  v_daily_limit integer := 5;
  v_used_count integer := 0;
begin
  if v_actor_id is null then
    raise exception '[AUTH_UNAUTHORIZED] Se requiere una sesion autenticada para consultar la cuota de IA.'
      using errcode = '42501';
  end if;

  select ac.value
    into v_rules
    from public.app_config ac
   where ac.key = 'price_verdict_rules';

  if v_rules is not null then
    v_daily_limit := coalesce((v_rules ->> 'daily_ai_limit_per_user')::integer, v_daily_limit);
  end if;

  select coalesce(au.count, 0)
    into v_used_count
    from public.ai_usage au
   where au.user_id = v_actor_id
     and au.day = v_today;

  v_used_count := coalesce(v_used_count, 0);

  return jsonb_build_object(
    'day', v_today::text,
    'timezone', 'America/Bogota',
    'used_count', v_used_count,
    'daily_limit', v_daily_limit,
    'remaining', greatest(v_daily_limit - v_used_count, 0)
  );
end;
$$;

comment on function public.get_my_ai_quota_status() is
  'Permite al usuario autenticado consultar su cuota diaria restante de análisis de contratos sin exponer public.ai_usage.';

revoke all on function public.get_my_ai_quota_status()
  from public, anon, authenticated;
grant execute on function public.get_my_ai_quota_status()
  to authenticated;
