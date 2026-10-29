-- ============================================================================
-- Pruebas pgTAP de Reportes Reales: Aporte, Cuotas, Privacidad y Semáforo (VJ-11)
-- ============================================================================
-- Se ejecutan con: supabase test db
-- Verifica en servidor:
--   1. Existencia y permisos de `submit_price_report` y `moderate_price_report`.
--   2. Asignación forzosa de `user_id := auth.uid()` y limpieza de texto.
--   3. Ofuscación automática de privacidad GPS a 3 decimales (~110 metros).
--   4. Rechazo de montos fuera de rango (< $500 o > $20.000.000 COP).
--   5. Rechazo de categoría inactiva, municipio no piloto o zona inactiva.
--   6. Prohibición de suplantación (`user_id` ajeno) y aislamiento entre cuentas A y B.
--   7. Deduplicación anti-spam en ventana corta (`[PRICE_DUPLICATE_REPORT]`).
--   8. Cuota diaria por usuario en servidor (`[PRICE_RATE_LIMITED]`).
--   9. Sincronización inmediata con `calculate_price_verdict` y moderación
--      administrativa de reportes falsos (`moderate_price_report`).
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

-- ---------------------------------------------------------------------------
-- Preparación aislada de datos de prueba
-- ---------------------------------------------------------------------------
delete from public.price_reports;

insert into public.departments (code, name)
values ('20', 'Cesar')
on conflict (code) do nothing;

insert into public.municipalities (code, department_code, name, is_pilot)
values
  ('20001', '20', 'Valledupar', true),
  ('20011', '20', 'Aguachica', false)
on conflict (code) do update
  set is_pilot = excluded.is_pilot;

insert into public.municipality_zones (id, municipality_code, name_es, name_en, is_active)
values
  ('vup_sur', '20001', 'Zona Sur', 'South Zone', true),
  ('vup_inactiva', '20001', 'Zona Inactiva', 'Inactive Zone', false)
on conflict (id) do update
  set is_active = excluded.is_active;

insert into public.price_categories (
  id, group_key, name_es, name_en, unit_description_es, unit_description_en, is_active
)
values
  ('transport_taxi_minimal', 'transport', 'Taxi', 'Taxi', 'Carrera', 'Ride', true),
  ('inactive_category_test', 'transport', 'Inactiva', 'Inactive', 'N/A', 'N/A', false)
on conflict (id) do update
  set is_active = excluded.is_active;

-- Configurar cuota diaria de prueba en 3 reportes por usuario para verificar el tope
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
    "daily_report_limit_per_user": 3,
    "duplicate_cooldown_minutes": 15,
    "min_report_amount_cop": 500,
    "max_report_amount_cop": 20000000
  }'::jsonb
)
on conflict (key) do update
  set value = excluded.value;

-- Usuarios de prueba: User A, User B y Admin
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    'aaaa1111-1111-4111-8111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'user_a@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Usuario A"}'::jsonb, now(), now()
  ),
  (
    'bbbb2222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'user_b@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Usuario B"}'::jsonb, now(), now()
  ),
  (
    'cccc3333-3333-4333-8333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'admin_c@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Admin C"}'::jsonb, now(), now()
  )
on conflict (id) do nothing;

insert into public.admin_users (user_id)
values ('cccc3333-3333-4333-8333-333333333333')
on conflict (user_id) do nothing;

create temp table vj11_results (
  label text primary key,
  text_val text,
  int_val bigint,
  payload jsonb
);

grant select, insert, update on vj11_results to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1-2 · Existencia de las funciones RPC de VJ-11
-- ---------------------------------------------------------------------------
select has_function(
  'public',
  'submit_price_report',
  array['character varying', 'text', 'character varying', 'integer', 'character varying', 'character varying', 'double precision', 'double precision'],
  'RPC submit_price_report exists with expected signature'
);

select has_function(
  'public',
  'moderate_price_report',
  array['uuid', 'boolean', 'text'],
  'RPC moderate_price_report exists with expected signature'
);

-- ---------------------------------------------------------------------------
-- 3 · Seguridad: `anon` no puede invocar `submit_price_report`
-- ---------------------------------------------------------------------------
set local role anon;

do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20001', 'vup_sur', 10000, 'Terminal', null, null, null
  );
  insert into vj11_results (label, int_val) values ('anon_submit_blocked', 0);
exception
  when insufficient_privilege or sqlstate '42501' then
    insert into vj11_results (label, int_val) values ('anon_submit_blocked', 1);
end;
$$;

reset role;

select is(
  (select int_val from vj11_results where label = 'anon_submit_blocked'),
  1::bigint,
  'anon role cannot execute submit_price_report'
);

-- ---------------------------------------------------------------------------
-- 4-5 · Usuario A aporta reporte real: sanitiza texto y ofusca GPS a 3 decimales
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

insert into vj11_results (label, payload)
values (
  'user_a_report_1',
  public.submit_price_report(
    'transport_taxi_minimal',
    '20001',
    'vup_sur',
    10000,
    '  Terminal de Transporte  ',
    '   ',
    10.463892,
    -73.251489
  )
);

reset role;

select is(
  (
    select (payload ->> 'amount_cop') || ':' ||
           (payload ->> 'place_name') || ':' ||
           coalesce(payload ->> 'source_note', 'NULL') || ':' ||
           (payload ->> 'is_demo')
    from vj11_results
    where label = 'user_a_report_1'
  ),
  '10000:Terminal de Transporte:NULL:false',
  'submit_price_report creates real report, trims place_name and nullifies blank source_note'
);

select is(
  (
    select round(ST_X(location::geometry)::numeric, 6)::text || ',' ||
           round(ST_Y(location::geometry)::numeric, 6)::text
    from public.price_reports
    where id = ((select payload ->> 'id' from vj11_results where label = 'user_a_report_1')::uuid)
  ),
  '-73.251000,10.464000',
  'GPS location is obfuscated on server to 3 decimal places (~110m grid) for citizen privacy'
);

-- ---------------------------------------------------------------------------
-- 6-7 · Validaciones de rango de monto COP (< 500 y > 20.000.000)
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20001', 'vup_sur', 499, null, null, null, null
  );
  insert into vj11_results (label, int_val) values ('below_min_blocked', 0);
exception
  when sqlstate '22023' or check_violation then
    insert into vj11_results (label, int_val) values ('below_min_blocked', 1);
end;
$$;

do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20001', 'vup_sur', 20000001, null, null, null, null
  );
  insert into vj11_results (label, int_val) values ('above_max_blocked', 0);
exception
  when sqlstate '22023' or check_violation then
    insert into vj11_results (label, int_val) values ('above_max_blocked', 1);
end;
$$;

reset role;

select is(
  (select int_val from vj11_results where label = 'below_min_blocked'),
  1::bigint,
  'amount_cop below $500 COP is rejected by server'
);

select is(
  (select int_val from vj11_results where label = 'above_max_blocked'),
  1::bigint,
  'amount_cop above $20.000.000 COP is rejected by server'
);

-- ---------------------------------------------------------------------------
-- 8-10 · Validación de categoría activa, municipio piloto y zona activa
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

do $$
begin
  perform public.submit_price_report(
    'inactive_category_test', '20001', 'vup_sur', 10000, null, null, null, null
  );
  insert into vj11_results (label, int_val) values ('inactive_cat_blocked', 0);
exception
  when sqlstate '22023' then
    insert into vj11_results (label, int_val) values ('inactive_cat_blocked', 1);
end;
$$;

do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20011', 'vup_sur', 10000, null, null, null, null
  );
  insert into vj11_results (label, int_val) values ('non_pilot_blocked', 0);
exception
  when sqlstate '22023' then
    insert into vj11_results (label, int_val) values ('non_pilot_blocked', 1);
end;
$$;

do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20001', 'vup_inactiva', 10000, null, null, null, null
  );
  insert into vj11_results (label, int_val) values ('inactive_zone_blocked', 0);
exception
  when sqlstate '22023' then
    insert into vj11_results (label, int_val) values ('inactive_zone_blocked', 1);
end;
$$;

reset role;

select is(
  (select int_val from vj11_results where label = 'inactive_cat_blocked'),
  1::bigint,
  'inactive price category is rejected with [PRICE_CATEGORY_INACTIVE]'
);

select is(
  (select int_val from vj11_results where label = 'non_pilot_blocked'),
  1::bigint,
  'non-pilot municipality (20011) is rejected with [PRICE_MUNICIPALITY_NOT_PILOT]'
);

select is(
  (select int_val from vj11_results where label = 'inactive_zone_blocked'),
  1::bigint,
  'inactive municipality zone is rejected with [PRICE_ZONE_INACTIVE]'
);

-- ---------------------------------------------------------------------------
-- 11-12 · Anti-suplantación y aislamiento entre Usuario B y Usuario A
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';

do $$
begin
  insert into public.price_reports (
    user_id, category_id, municipality_code, zone_id, amount_cop
  )
  values (
    'aaaa1111-1111-4111-8111-111111111111',
    'transport_taxi_minimal',
    '20001',
    'vup_sur',
    12000
  );
  insert into vj11_results (label, int_val) values ('spoof_user_blocked', 0);
exception
  when sqlstate '42501' then
    insert into vj11_results (label, int_val) values ('spoof_user_blocked', 1);
end;
$$;

update public.price_reports
   set amount_cop = 19000
 where user_id = 'aaaa1111-1111-4111-8111-111111111111';

reset role;

select is(
  (select int_val from vj11_results where label = 'spoof_user_blocked'),
  1::bigint,
  'User B cannot insert a price report spoofing User A user_id'
);

select is(
  (
    select amount_cop
    from public.price_reports
    where id = ((select payload ->> 'id' from vj11_results where label = 'user_a_report_1')::uuid)
  ),
  10000,
  'User B cannot modify User A price report'
);

-- ---------------------------------------------------------------------------
-- 13 · Anti-spam / Deduplicación: envío idéntico dentro de 15 min es rechazado
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20001', 'vup_sur', 10000, 'Intento duplicado', null, null, null
  );
  insert into vj11_results (label, int_val) values ('duplicate_blocked', 0);
exception
  when sqlstate 'P0001' then
    if sqlerrm like '%[PRICE_DUPLICATE_REPORT]%' then
      insert into vj11_results (label, int_val) values ('duplicate_blocked', 1);
    else
      insert into vj11_results (label, int_val) values ('duplicate_blocked', -1);
    end if;
end;
$$;

reset role;

select is(
  (select int_val from vj11_results where label = 'duplicate_blocked'),
  1::bigint,
  'duplicate report within cooldown window is rejected with [PRICE_DUPLICATE_REPORT]'
);

-- ---------------------------------------------------------------------------
-- 14-15 · Cuota diaria: Usuario A completa sus 3 reportes y el 4.° es bloqueado;
--         Usuario B puede aportar normalmente
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

-- Reporte #2 y #3 de Usuario A (montos distintos para no activar anti-duplicado)
insert into vj11_results (label, payload)
values (
  'user_a_report_2',
  public.submit_price_report('transport_taxi_minimal', '20001', 'vup_sur', 11000, 'Terminal Sur', null, null, null)
);

insert into vj11_results (label, payload)
values (
  'user_a_report_3',
  public.submit_price_report('transport_taxi_minimal', '20001', 'vup_sur', 12000, 'Terminal Sur', null, null, null)
);

-- Reporte #4 de Usuario A debe ser rechazado por cuota diaria (daily_report_limit_per_user = 3)
do $$
begin
  perform public.submit_price_report(
    'transport_taxi_minimal', '20001', 'vup_sur', 13000, 'Exceso de cuota', null, null, null
  );
  insert into vj11_results (label, int_val) values ('daily_quota_blocked', 0);
exception
  when sqlstate 'P0001' then
    if sqlerrm like '%[PRICE_RATE_LIMITED]%' then
      insert into vj11_results (label, int_val) values ('daily_quota_blocked', 1);
    else
      insert into vj11_results (label, int_val) values ('daily_quota_blocked', -1);
    end if;
end;
$$;

reset role;

-- Usuario B aporta su primer reporte (12000 COP)
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';

insert into vj11_results (label, payload)
values (
  'user_b_report_1',
  public.submit_price_report('transport_taxi_minimal', '20001', 'vup_sur', 12000, 'Aporte de B', null, null, null)
);

reset role;

select is(
  (select int_val from vj11_results where label = 'daily_quota_blocked'),
  1::bigint,
  'User A 4th report within 24h is rejected by server quota with [PRICE_RATE_LIMITED]'
);

select is(
  (select (payload ->> 'amount_cop')::int from vj11_results where label = 'user_b_report_1'),
  12000,
  'User B can submit report normally while User A is rate-limited'
);

-- ---------------------------------------------------------------------------
-- 16-18 · Sincronización con `calculate_price_verdict` y moderación de reportes
-- ---------------------------------------------------------------------------
-- Muestra actual en vup_sur: 10000, 11000, 12000, 12000 (N = 4, mediana = 11500)
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';

insert into vj11_results (label, payload)
values (
  'verdict_before_moderation',
  public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_sur', 11500)
);

-- Usuario B (no admin) intenta ocultar el reporte de Usuario A -> denegado
do $$
begin
  perform public.moderate_price_report(
    (select (payload ->> 'id')::uuid from vj11_results where label = 'user_a_report_1'),
    true,
    'Intento no autorizado'
  );
  insert into vj11_results (label, int_val) values ('non_admin_mod_blocked', 0);
exception
  when sqlstate '42501' then
    insert into vj11_results (label, int_val) values ('non_admin_mod_blocked', 1);
end;
$$;

reset role;

-- Admin C oculta 2 reportes (dejando N = 2 en vup_sur -> insufficient)
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"cccc3333-3333-4333-8333-333333333333","role":"authenticated"}';

select public.moderate_price_report(
  (select (payload ->> 'id')::uuid from vj11_results where label = 'user_a_report_2'),
  true,
  'Reporte duplicado de prueba'
);

select public.moderate_price_report(
  (select (payload ->> 'id')::uuid from vj11_results where label = 'user_a_report_3'),
  true,
  'Reporte anómalo'
);

insert into vj11_results (label, payload)
values (
  'verdict_after_moderation',
  public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_sur', 11500)
);

reset role;

select is(
  (
    select (payload ->> 'level') || ':' ||
           (payload ->> 'reference_cop') || ':' ||
           (payload ->> 'sample_count')
    from vj11_results
    where label = 'verdict_before_moderation'
  ),
  'green:11500:4',
  'calculate_price_verdict reflects newly submitted real reports (N=4, median=11500)'
);

select is(
  (select int_val from vj11_results where label = 'non_admin_mod_blocked'),
  1::bigint,
  'non-admin user cannot execute moderate_price_report'
);

select is(
  (
    select (payload ->> 'level') || ':' || (payload ->> 'sample_count')
    from vj11_results
    where label = 'verdict_after_moderation'
  ),
  'insufficient:2',
  'moderating/hiding false reports immediately excludes them from calculate_price_verdict (N=2 -> insufficient)'
);

select * from finish();
rollback;
