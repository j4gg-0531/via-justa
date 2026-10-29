-- ============================================================================
-- Pruebas SQL pgTAP de la Función del Semáforo · Vía Justa MVP (VJ-10 / RNF-09)
-- ============================================================================
-- Se ejecutan con: supabase test db
-- Cubre todos los casos límite obligatorios de la sección 8 de PLAN_MAESTRO:
--   1. Desviación 0 % -> green
--   2. Umbral exacto 15.00 % -> green
--   3. Umbral +0.01 % (15.01 %) -> yellow
--   4. Umbral exacto 40.00 % -> yellow
--   5. Umbral +0.01 % (40.01 %) -> red
--   6. Precio -40.00 % exacto -> green SIN underpriced_alert
--   7. Precio -40.01 % (más de 40 % bajo) -> green CON underpriced_alert
--   8. Reportes insuficientes (0, 1 y 2 reportes) -> insufficient
--   9. Mediana con N par (4 observaciones) -> promedio exacto de los 2 centrales
--  10. Ventana de 60 días -> reporte de hace 61 días no cuenta; de 59 días sí
--  11. Datos invisibles (is_hidden, is_demo, otra categoría, otra zona) -> excluidos
--  12. Evento activo real con >= 3 reportes en su ventana -> usa mediana de evento
--  13. Evento activo real con < 3 reportes en su ventana -> mantiene mediana general
--  14. Evento marcado como is_demo = true -> nunca altera el veredicto real
--  15. Validación de entradas inválidas (monto 0, negativo, extremo, categoría inválida)
--  16. Seguridad RPC: usuario anónimo rechazado y el JSON no expone PII ni coordenadas
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

-- ---------------------------------------------------------------------------
-- Datos base aislados para la prueba (dentro de transacción con ROLLBACK)
-- ---------------------------------------------------------------------------
insert into public.departments (code, name)
values ('20', 'Cesar')
on conflict (code) do nothing;

insert into public.municipalities (code, department_code, name, is_pilot)
values ('20001', '20', 'Valledupar', true)
on conflict (code) do nothing;

insert into public.municipality_zones (id, municipality_code, name_es, name_en, is_active)
values
  ('vup_centro', '20001', 'Zona Centro', 'Downtown Zone', true),
  ('vup_norte', '20001', 'Zona Norte', 'North Zone', true),
  ('vup_sur', '20001', 'Zona Sur', 'South Zone', true),
  ('vup_oriente', '20001', 'Zona Oriente', 'East Zone', true),
  ('vup_occidente', '20001', 'Zona Occidente', 'West Zone', true)
on conflict (id) do nothing;

insert into public.price_categories (
  id, group_key, name_es, name_en, unit_description_es, unit_description_en, is_active
)
values
  ('transport_taxi_minimal', 'transport', 'Taxi', 'Taxi', 'Carrera', 'Ride', true),
  ('food_corrientazo', 'food', 'Almuerzo', 'Lunch', 'Plato', 'Dish', true)
on conflict (id) do nothing;

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
on conflict (key) do update set value = excluded.value;

-- Limpiamos reportes y eventos previos de las seeds para tener control matemático exacto
delete from public.price_reports where municipality_code = '20001';
delete from public.events where municipality_code = '20001';

-- Usuario autenticado para ejecutar las pruebas
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  '33333333-3333-3333-3333-333333333333',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'tester@example.test',
  extensions.crypt('password123', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Tester"}'::jsonb,
  now(),
  now()
)
on conflict (id) do nothing;

create temp table verdict_test_results (
  label text primary key,
  payload jsonb,
  flag integer
);
grant select, insert, update on verdict_test_results to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1 · Seguridad: anon NO tiene privilegio EXECUTE sobre calculate_price_verdict
-- ---------------------------------------------------------------------------
select is(
  pg_catalog.has_function_privilege(
    'anon',
    'public.calculate_price_verdict(varchar, varchar, varchar, integer)',
    'EXECUTE'
  ),
  false,
  'anon role cannot execute calculate_price_verdict'
);

-- Activar sesión de usuario autenticado para las pruebas funcionales
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

-- ---------------------------------------------------------------------------
-- 2-4 · Muestra insuficiente: 0, 1 y 2 reportes en vup_occidente
-- ---------------------------------------------------------------------------
insert into verdict_test_results (label, payload)
values (
  'n0',
  public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_occidente', 10000)
);

insert into public.price_reports (user_id, category_id, municipality_code, zone_id, amount_cop)
values ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_occidente', 10000);

insert into verdict_test_results (label, payload)
values (
  'n1',
  public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_occidente', 10000)
);

insert into public.price_reports (user_id, category_id, municipality_code, zone_id, amount_cop)
values ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_occidente', 12000);

insert into verdict_test_results (label, payload)
values (
  'n2',
  public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_occidente', 10000)
);

reset role;

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'n0'),
  'insufficient',
  'N = 0 returns insufficient'
);

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'n1'),
  'insufficient',
  'N = 1 returns insufficient'
);

select is(
  (
    select (payload ->> 'level') || ':' || coalesce(payload ->> 'reference_cop', 'null')
    from verdict_test_results
    where label = 'n2'
  ),
  'insufficient:null',
  'N = 2 returns insufficient with null reference_cop'
);

-- ---------------------------------------------------------------------------
-- 5-11 · Casos límite exactos de porcentaje sobre mediana = 10.000 COP (vup_centro)
-- ---------------------------------------------------------------------------
-- Insertamos 3 reportes en vup_centro con mediana = 10000 (9000, 10000, 11000)
insert into public.price_reports (user_id, category_id, municipality_code, zone_id, amount_cop)
values
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_centro', 9000),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_centro', 10000),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_centro', 11000);

-- También insertamos ruido que NO debe contarse:
--   a) is_hidden = true (monto extremo 900000)
--   b) is_demo = true (monto extremo 800000)
--   c) reporte viejo de hace 61 días (monto extremo 700000)
--   d) otra categoría en la misma zona (food_corrientazo = 600000)
--   e) otra zona en el mismo municipio (vup_sur = 500000)
insert into public.price_reports (
  user_id, category_id, municipality_code, zone_id, amount_cop, is_hidden, is_demo, created_at
)
values
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_centro', 900000, true, false, now()),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_centro', 800000, false, true, now()),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_centro', 700000, false, false, now() - interval '61 days'),
  ('33333333-3333-3333-3333-333333333333', 'food_corrientazo', '20001', 'vup_centro', 600000, false, false, now()),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_sur', 500000, false, false, now());

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

-- 0 % -> 10000 vs 10000
insert into verdict_test_results (label, payload)
values ('dev_0', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 10000));

-- 15.00 % exacto -> 11500 vs 10000 (green)
insert into verdict_test_results (label, payload)
values ('dev_15', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 11500));

-- 15.01 % -> 11501 vs 10000 (yellow)
insert into verdict_test_results (label, payload)
values ('dev_15_01', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 11501));

-- 40.00 % exacto -> 14000 vs 10000 (yellow)
insert into verdict_test_results (label, payload)
values ('dev_40', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 14000));

-- 40.01 % -> 14001 vs 10000 (red)
insert into verdict_test_results (label, payload)
values ('dev_40_01', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 14001));

-- -40.00 % exacto -> 6000 vs 10000 (green, underpriced_alert = false)
insert into verdict_test_results (label, payload)
values ('dev_minus_40', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 6000));

-- -40.01 % -> 5999 vs 10000 (-40.01 %, green, underpriced_alert = true)
insert into verdict_test_results (label, payload)
values ('dev_minus_40_01', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 5999));

reset role;

select is(
  (
    select (payload ->> 'level') || ':' || (payload ->> 'reference_cop') || ':' || (payload ->> 'sample_count') || ':' || (payload ->> 'recommended_cap_cop')
    from verdict_test_results
    where label = 'dev_0'
  ),
  'green:10000:3:11500',
  '0% deviation returns green, reference 10000, N=3 (excluding hidden/demo/old/other), cap 11500'
);

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'dev_15'),
  'green',
  'exact 15.00% deviation returns green'
);

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'dev_15_01'),
  'yellow',
  '15.01% deviation returns yellow (unrounded comparison)'
);

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'dev_40'),
  'yellow',
  'exact 40.00% deviation returns yellow'
);

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'dev_40_01'),
  'red',
  '40.01% deviation returns red (unrounded comparison)'
);

select is(
  (
    select (payload ->> 'level') || ':' || (payload ->> 'underpriced_alert')
    from verdict_test_results
    where label = 'dev_minus_40'
  ),
  'green:false',
  'exact -40.00% deviation stays green without underpriced_alert'
);

select is(
  (
    select (payload ->> 'level') || ':' || (payload ->> 'underpriced_alert')
    from verdict_test_results
    where label = 'dev_minus_40_01'
  ),
  'green:true',
  '-40.01% deviation stays green and triggers underpriced_alert = true'
);

-- ---------------------------------------------------------------------------
-- 12 · Mediana con N par (4 observaciones en vup_norte): promedio de centrales
-- ---------------------------------------------------------------------------
-- Datos: 10000, 12000, 14000, 20000 -> mediana exacta = (12000 + 14000) / 2 = 13000
insert into public.price_reports (user_id, category_id, municipality_code, zone_id, amount_cop, created_at)
values
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_norte', 10000, now() - interval '59 days'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_norte', 12000, now() - interval '30 days'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_norte', 14000, now() - interval '10 days'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_norte', 20000, now() - interval '1 day');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

insert into verdict_test_results (label, payload)
values ('even_median', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_norte', 13000));

reset role;

select is(
  (
    select (payload ->> 'reference_cop') || ':' || (payload ->> 'sample_count')
    from verdict_test_results
    where label = 'even_median'
  ),
  '13000:4',
  'even sample N=4 computes exact percentile_cont(0.5) median (13000) and includes 59-day report'
);

-- ---------------------------------------------------------------------------
-- 13-15 · Eventos: evento DEMO ignorado, evento real con <3 reportes vs >=3 reportes
-- ---------------------------------------------------------------------------
-- 13: Evento DEMO activo hoy con 3 reportes recientes NO debe activar is_event_context en producción
insert into public.events (id, municipality_code, name, starts_at, ends_at, is_demo)
values (
  'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  '20001',
  'Evento Demo Activo',
  now() - interval '2 days',
  now() + interval '2 days',
  true
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

insert into verdict_test_results (label, payload)
values ('demo_event_ignored', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 12000));

reset role;

select is(
  (select payload ->> 'is_event_context' from verdict_test_results where label = 'demo_event_ignored'),
  'false',
  'active event marked as is_demo = true does not alter real verdict'
);

delete from public.events where id = 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

-- 14: Evento REAL activo hoy, pero con solo 2 reportes dentro de sus fechas (vup_oriente)
-- Base histórica en vup_oriente (hace 20 días): 3 reportes de 10000
-- Dentro del evento (últimas 24h): solo 2 reportes de 20000
insert into public.events (id, municipality_code, name, starts_at, ends_at, is_demo)
values (
  'bbbbbbb2-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
  '20001',
  'Festival Vallenato Oficial',
  now() - interval '2 days',
  now() + interval '2 days',
  false
);

insert into public.price_reports (user_id, category_id, municipality_code, zone_id, amount_cop, created_at)
values
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_oriente', 10000, now() - interval '20 days'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_oriente', 10000, now() - interval '19 days'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_oriente', 10000, now() - interval '18 days'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_oriente', 20000, now() - interval '1 hour'),
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_oriente', 20000, now() - interval '30 minutes');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

insert into verdict_test_results (label, payload)
values ('event_under_3', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_oriente', 15000));

reset role;

select is(
  (
    select (payload ->> 'is_event_context') || ':' || (payload ->> 'reference_cop') || ':' || (payload ->> 'level')
    from verdict_test_results
    where label = 'event_under_3'
  ),
  'false:10000:red',
  'active event with <3 reports in window keeps baseline median (10000) and level red for 15000'
);

-- 15: Agregamos el 3er reporte dentro del rango del evento en vup_oriente (20000)
-- Ahora hay 3 reportes en el evento con mediana de evento = 20000 (y mediana general de los 6 = 15000)
-- Para un precio consultado de 15000, frente a la mediana del evento (20000) la desviación es -25% -> green
insert into public.price_reports (user_id, category_id, municipality_code, zone_id, amount_cop, created_at)
values
  ('33333333-3333-3333-3333-333333333333', 'transport_taxi_minimal', '20001', 'vup_oriente', 20000, now() - interval '10 minutes');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

insert into verdict_test_results (label, payload)
values ('event_with_3', public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_oriente', 15000));

reset role;

select is(
  (
    select (payload ->> 'is_event_context') || ':' ||
           (payload ->> 'reference_cop') || ':' ||
           (payload ->> 'baseline_reference_cop') || ':' ||
           (payload ->> 'level') || ':' ||
           (payload -> 'event_details' ->> 'event_reference_cop')
    from verdict_test_results
    where label = 'event_with_3'
  ),
  'true:20000:15000:green:20000',
  'active event with >=3 reports switches displayed reference to event median (20000) and includes baseline comparison (15000)'
);

-- ---------------------------------------------------------------------------
-- 16-20 · Entradas inválidas (monto 0, negativo, extremo, categoría inexistente, zona ajena)
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
begin
  perform public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 0);
  insert into verdict_test_results (label, flag) values ('err_zero', 0);
exception
  when invalid_parameter_value then
    insert into verdict_test_results (label, flag) values ('err_zero', 1);
end;
$$;

do $$
begin
  perform public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', -5000);
  insert into verdict_test_results (label, flag) values ('err_neg', 0);
exception
  when invalid_parameter_value then
    insert into verdict_test_results (label, flag) values ('err_neg', 1);
end;
$$;

do $$
begin
  perform public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 999999999);
  insert into verdict_test_results (label, flag) values ('err_huge', 0);
exception
  when invalid_parameter_value then
    insert into verdict_test_results (label, flag) values ('err_huge', 1);
end;
$$;

do $$
begin
  perform public.calculate_price_verdict('non_existent_cat', '20001', 'vup_centro', 10000);
  insert into verdict_test_results (label, flag) values ('err_cat', 0);
exception
  when invalid_parameter_value then
    insert into verdict_test_results (label, flag) values ('err_cat', 1);
end;
$$;

do $$
begin
  perform public.calculate_price_verdict('transport_taxi_minimal', '20001', 'invalid_zone', 10000);
  insert into verdict_test_results (label, flag) values ('err_zone', 0);
exception
  when invalid_parameter_value then
    insert into verdict_test_results (label, flag) values ('err_zone', 1);
end;
$$;

-- 21 · Alias evaluate_price_verdict funciona idéntico y el JSON no filtra PII
insert into verdict_test_results (label, payload)
values ('alias_ok', public.evaluate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 10000));

reset role;

select is((select flag from verdict_test_results where label = 'err_zero'), 1, 'amount 0 raises controlled 22023 error');
select is((select flag from verdict_test_results where label = 'err_neg'), 1, 'negative amount raises controlled 22023 error');
select is((select flag from verdict_test_results where label = 'err_huge'), 1, 'extreme amount (>100M COP) raises controlled 22023 error');
select is((select flag from verdict_test_results where label = 'err_cat'), 1, 'invalid category raises controlled 22023 error');
select is((select flag from verdict_test_results where label = 'err_zone'), 1, 'invalid zone raises controlled 22023 error');

select is(
  (select payload ->> 'level' from verdict_test_results where label = 'alias_ok'),
  'green',
  'evaluate_price_verdict alias returns the same verdict'
);

select is(
  (
    select ((payload ? 'user_id') or (payload ? 'location') or (payload ? 'source_note'))
    from verdict_test_results
    where label = 'alias_ok'
  ),
  false,
  'verdict JSON never exposes user_id, location, or private notes'
);

-- 24 · Sin JWT (auth.uid() null), la función rechaza la ejecución con 42501
set local role authenticated;
set local request.jwt.claims = '{}';

do $$
begin
  perform public.calculate_price_verdict('transport_taxi_minimal', '20001', 'vup_centro', 10000);
  insert into verdict_test_results (label, flag) values ('err_no_uid', 0);
exception
  when insufficient_privilege then
    insert into verdict_test_results (label, flag) values ('err_no_uid', 1);
end;
$$;

reset role;

select is(
  (select flag from verdict_test_results where label = 'err_no_uid'),
  1,
  'caller without auth.uid() is rejected with 42501 insufficient_privilege'
);

select * from finish();
rollback;
