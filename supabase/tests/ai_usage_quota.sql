-- ============================================================================
-- Pruebas pgTAP de Cuota Diaria de IA (`public.ai_usage` y RPCs · VJ-14)
-- ============================================================================
-- Se ejecutan con: supabase test db
-- Verifica en servidor:
--   1. Existencia de `consume_ai_daily_quota`, `refund_ai_daily_quota` y
--      `get_my_ai_quota_status`.
--   2. Bloqueo de `anon` y `authenticated` sobre `consume_ai_daily_quota` y
--      `refund_ai_daily_quota` (exclusivas de `service_role`).
--   3. Consulta propia segura mediante `get_my_ai_quota_status()` en zona
--      horaria `America/Bogota`.
--   4. Consumo atómico hasta el límite configurado (`daily_ai_limit_per_user = 5`)
--      y rechazo en el intento #6 con `allowed = false` y
--      `code = 'AI_DAILY_LIMIT_EXCEEDED'`.
--   5. Aislamiento entre usuarios (Usuario B tiene su propio cupo independiente).
--   6. Reintegro de cuota (`refund_ai_daily_quota`) ante fallos 502/timeout del
--      proveedor sin bajar nunca de 0.
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

delete from public.ai_usage;

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
    "daily_ai_limit_per_user": 5
  }'::jsonb
)
on conflict (key) do update
  set value = excluded.value;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    'aaaa1414-1414-4414-8414-141414141414',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'contract_a@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Contrato A"}'::jsonb, now(), now()
  ),
  (
    'bbbb1414-1414-4414-8414-141414141414',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'contract_b@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Contrato B"}'::jsonb, now(), now()
  )
on conflict (id) do nothing;

create temp table vj14_results (
  label text primary key,
  int_val bigint,
  payload jsonb
);

grant select, insert, update on vj14_results to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1-3 · Existencia de las funciones RPC de cuota de IA
-- ---------------------------------------------------------------------------
select has_function(
  'public',
  'consume_ai_daily_quota',
  array['uuid'],
  'RPC consume_ai_daily_quota(uuid) exists'
);

select has_function(
  'public',
  'refund_ai_daily_quota',
  array['uuid'],
  'RPC refund_ai_daily_quota(uuid) exists'
);

select has_function(
  'public',
  'get_my_ai_quota_status',
  array[]::text[],
  'RPC get_my_ai_quota_status() exists'
);

-- ---------------------------------------------------------------------------
-- 4-5 · `authenticated` no puede ejecutar `consume_ai_daily_quota` ni `refund_ai_daily_quota`
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1414-1414-4414-8414-141414141414","role":"authenticated"}';

do $$
begin
  perform public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414');
  insert into vj14_results (label, int_val) values ('auth_consume_blocked', 0);
exception
  when insufficient_privilege then
    insert into vj14_results (label, int_val) values ('auth_consume_blocked', 1);
end;
$$;

do $$
begin
  perform public.refund_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414');
  insert into vj14_results (label, int_val) values ('auth_refund_blocked', 0);
exception
  when insufficient_privilege then
    insert into vj14_results (label, int_val) values ('auth_refund_blocked', 1);
end;
$$;

insert into vj14_results (label, payload)
values ('initial_status_a', public.get_my_ai_quota_status());

reset role;

select is(
  (select int_val from vj14_results where label = 'auth_consume_blocked'),
  1::bigint,
  'authenticated user cannot call consume_ai_daily_quota directly'
);

select is(
  (select int_val from vj14_results where label = 'auth_refund_blocked'),
  1::bigint,
  'authenticated user cannot call refund_ai_daily_quota directly'
);

-- ---------------------------------------------------------------------------
-- 6 · Estado inicial de cuota para Usuario A (`0/5` en `America/Bogota`)
-- ---------------------------------------------------------------------------
select is(
  (
    select (payload ->> 'used_count') || '/' ||
           (payload ->> 'daily_limit') || ':' ||
           (payload ->> 'remaining') || ':' ||
           (payload ->> 'timezone')
    from vj14_results
    where label = 'initial_status_a'
  ),
  '0/5:5:America/Bogota',
  'get_my_ai_quota_status returns 0/5 used and 5 remaining in America/Bogota timezone'
);

-- ---------------------------------------------------------------------------
-- 7-9 · Consumo atómico con `service_role`: 5 permitidos y 6.° rechazado con AI_DAILY_LIMIT_EXCEEDED
-- ---------------------------------------------------------------------------
set local role service_role;

insert into vj14_results (label, payload)
values ('consume_a_1', public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414'));

select public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414');
select public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414');
select public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414');

insert into vj14_results (label, payload)
values ('consume_a_5', public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414'));

insert into vj14_results (label, payload)
values ('consume_a_6_blocked', public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414'));

-- Usuario B sigue con su cuota intacta
insert into vj14_results (label, payload)
values ('consume_b_1', public.consume_ai_daily_quota('bbbb1414-1414-4414-8414-141414141414'));

reset role;

select is(
  (
    select (payload ->> 'allowed') || ':' ||
           (payload ->> 'used_count') || ':' ||
           (payload ->> 'remaining')
    from vj14_results
    where label = 'consume_a_1'
  ),
  'true:1:4',
  '1st quota consumption for User A succeeds with 1 used and 4 remaining'
);

select is(
  (
    select (payload ->> 'allowed') || ':' ||
           (payload ->> 'used_count') || ':' ||
           (payload ->> 'remaining')
    from vj14_results
    where label = 'consume_a_5'
  ),
  'true:5:0',
  '5th quota consumption for User A reaches daily limit (5 used, 0 remaining)'
);

select is(
  (
    select (payload ->> 'allowed') || ':' ||
           (payload ->> 'code') || ':' ||
           (payload ->> 'used_count') || ':' ||
           (payload ->> 'remaining')
    from vj14_results
    where label = 'consume_a_6_blocked'
  ),
  'false:AI_DAILY_LIMIT_EXCEEDED:5:0',
  '6th quota attempt on same day is rejected with AI_DAILY_LIMIT_EXCEEDED and does not increment count'
);

-- ---------------------------------------------------------------------------
-- 10-12 · Aislamiento de Usuario B y reintegro (`refund_ai_daily_quota`) para reintento seguro
-- ---------------------------------------------------------------------------
select is(
  (
    select (payload ->> 'allowed') || ':' ||
           (payload ->> 'used_count') || ':' ||
           (payload ->> 'remaining')
    from vj14_results
    where label = 'consume_b_1'
  ),
  'true:1:4',
  'User B quota is independent from User A exhausted quota'
);

set local role service_role;

insert into vj14_results (label, payload)
values ('refund_a', public.refund_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414'));

insert into vj14_results (label, payload)
values ('retry_a_after_refund', public.consume_ai_daily_quota('aaaa1414-1414-4414-8414-141414141414'));

reset role;

select is(
  (
    select (payload ->> 'refunded') || ':' ||
           (payload ->> 'used_count') || ':' ||
           (payload ->> 'remaining')
    from vj14_results
    where label = 'refund_a'
  ),
  'true:4:1',
  'refund_ai_daily_quota restores 1 quota unit (used_count = 4, remaining = 1) when provider fails'
);

select is(
  (
    select (payload ->> 'allowed') || ':' ||
           (payload ->> 'used_count') || ':' ||
           (payload ->> 'remaining')
    from vj14_results
    where label = 'retry_a_after_refund'
  ),
  'true:5:0',
  'User A can safely retry after a refunded provider failure without losing quota'
);

select * from finish();
rollback;
