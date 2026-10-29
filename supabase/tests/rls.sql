-- ============================================================================
-- Pruebas de RLS y constraints · Vía Justa MVP
-- ============================================================================
-- Se ejecutan con: supabase test db
-- Requieren el CLI de Supabase y Docker. Cada prueba corre dentro de una
-- transacción que termina en ROLLBACK, por lo que no deja datos.
--
-- Objetivo: demostrar que un usuario no lee datos ajenos, que los catálogos
-- públicos son legibles, que los reportes demo/ocultos no se filtran y que
-- las columnas de auditoría no son editables por el cliente.
-- ============================================================================

begin;

-- pgTAP no está garantizado en todas las instalaciones locales/remotas.
create extension if not exists pgtap with schema extensions;

-- Rutas de búsqueda deterministas (pgTAP y PostGIS viven en `extensions`).
set local search_path = public, extensions;

select plan(26);

-- ---------------------------------------------------------------------------
-- Datos de referencia mínimos (independientes de las seeds)
-- ---------------------------------------------------------------------------
insert into public.departments (code, name)
values ('20', 'Cesar')
on conflict (code) do nothing;

insert into public.municipalities (code, department_code, name, is_pilot)
values ('20001', '20', 'Valledupar', true)
on conflict (code) do nothing;

insert into public.municipality_zones (id, municipality_code, name_es, name_en)
values ('vup_centro', '20001', 'Zona Centro', 'Downtown Zone')
on conflict (id) do nothing;

insert into public.price_categories (
  id, group_key, name_es, name_en, unit_description_es, unit_description_en
)
values (
  'transport_taxi_minimal', 'transport', 'Taxi', 'Taxi', 'Carrera', 'Ride'
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Usuarios de prueba (el trigger handle_new_user crea sus perfiles)
-- ---------------------------------------------------------------------------
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'alice@example.test',
    extensions.crypt('password', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Alice"}'::jsonb,
    now(),
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'bob@example.test',
    extensions.crypt('password', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Bob"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

create temp table rls_results (
  label text primary key,
  value bigint not null
);

grant select, insert on rls_results to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1-6 · Las tablas existen
-- ---------------------------------------------------------------------------
select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'consents', 'consents table exists');
select has_table('public', 'departments', 'departments table exists');
select has_table('public', 'municipalities', 'municipalities table exists');
select has_table('public', 'price_reports', 'price_reports table exists');
select has_table('public', 'businesses', 'businesses table exists');

-- ---------------------------------------------------------------------------
-- 7 · RLS activo en las 16 tablas públicas
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::int
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relrowsecurity
  ),
  16,
  'RLS enabled on all 16 public tables'
);

-- ---------------------------------------------------------------------------
-- 8-11 · Alice solo ve su perfil y solo edita columnas permitidas
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

insert into rls_results (label, value)
select 'alice_profiles', count(*) from public.profiles;

insert into rls_results (label, value)
select 'alice_name_ok', count(*)
from public.profiles
where display_name = 'Alice';

update public.profiles
set display_name = 'Alice Updated'
where id = auth.uid();

insert into rls_results (label, value)
select 'alice_updated', count(*)
from public.profiles
where display_name = 'Alice Updated';

-- Intento de editar una columna de auditoría (sin GRANT UPDATE).
do $$
begin
  update public.profiles
  set created_at = now()
  where id = auth.uid();

  insert into rls_results (label, value)
  values ('protected_blocked', 0);
exception
  when insufficient_privilege then
    insert into rls_results (label, value)
    values ('protected_blocked', 1);
end;
$$;

reset role;

select is(
  (select value from rls_results where label = 'alice_profiles'),
  1::bigint,
  'alice only sees her own profile'
);

select is(
  (select value from rls_results where label = 'alice_name_ok'),
  1::bigint,
  'alice sees her display name'
);

select is(
  (select value from rls_results where label = 'alice_updated'),
  1::bigint,
  'alice can update her own display_name'
);

select is(
  (select value from rls_results where label = 'protected_blocked'),
  1::bigint,
  'alice cannot update audit columns'
);

-- ---------------------------------------------------------------------------
-- 12 · Bob tampoco ve el perfil de Alice
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

insert into rls_results (label, value)
select 'bob_profiles', count(*) from public.profiles;

reset role;

select is(
  (select value from rls_results where label = 'bob_profiles'),
  1::bigint,
  'bob only sees his own profile'
);

-- ---------------------------------------------------------------------------
-- 13-15 · Catálogos públicos vs. datos privados
-- ---------------------------------------------------------------------------
-- Nota: sobre app_config y ai_usage no existe GRANT para anon, por lo que una
-- consulta directa abortaría con `permission denied` en lugar de devolver 0
-- filas. Se verifica el privilegio efectivo, que es la garantía real.
set local role anon;

insert into rls_results (label, value)
select 'anon_departments', count(*) from public.departments;

reset role;

select ok(
  (select value from rls_results where label = 'anon_departments') > 0,
  'anon can read departments'
);

select is(
  pg_catalog.has_table_privilege('anon', 'public.app_config', 'SELECT'),
  false,
  'anon has no SELECT privilege on app_config'
);

select is(
  pg_catalog.has_table_privilege('anon', 'public.ai_usage', 'SELECT'),
  false,
  'anon has no SELECT privilege on ai_usage'
);

-- ---------------------------------------------------------------------------
-- 16-17 · Negocios: anon ve solo aprobados; el dueño ve los suyos
-- ---------------------------------------------------------------------------
insert into public.businesses (
  owner_id,
  municipality_code,
  type,
  name,
  description_es,
  description_en,
  location,
  whatsapp,
  whatsapp_consent_at,
  status
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    '20001',
    'restaurant',
    'Approved Business',
    'Descripción',
    'Description',
    ST_SetSRID(ST_MakePoint(-73.25, 10.46), 4326)::geography,
    '573001234567',
    now(),
    'approved'
  ),
  (
    '11111111-1111-1111-1111-111111111111',
    '20001',
    'restaurant',
    'Pending Business',
    'Descripción',
    'Description',
    ST_SetSRID(ST_MakePoint(-73.25, 10.46), 4326)::geography,
    '573001234567',
    now(),
    'pending'
  );

set local role anon;
insert into rls_results (label, value)
select 'anon_businesses', count(*) from public.businesses;
reset role;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
insert into rls_results (label, value)
select 'owner_businesses', count(*) from public.businesses;
reset role;

select is(
  (select value from rls_results where label = 'anon_businesses'),
  1::bigint,
  'anon sees only approved businesses'
);

select is(
  (select value from rls_results where label = 'owner_businesses'),
  2::bigint,
  'owner sees own businesses in any status'
);

-- ---------------------------------------------------------------------------
-- 18-19 · Reportes: anon no ve demo/ocultos; el autor ve los suyos
-- ---------------------------------------------------------------------------
insert into public.price_reports (
  user_id,
  category_id,
  municipality_code,
  zone_id,
  amount_cop,
  is_demo,
  is_hidden
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    10000,
    false,
    false
  ),
  (
    '11111111-1111-1111-1111-111111111111',
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    11000,
    true,
    false
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    12000,
    false,
    true
  );

set local role anon;
insert into rls_results (label, value)
select 'anon_reports', count(*) from public.price_reports;
reset role;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
insert into rls_results (label, value)
select 'owner_reports', count(*) from public.price_reports;
reset role;

select is(
  (select value from rls_results where label = 'anon_reports'),
  1::bigint,
  'anon sees only public non-demo reports'
);

select is(
  (select value from rls_results where label = 'owner_reports'),
  2::bigint,
  'owner sees own reports including demo'
);

-- ---------------------------------------------------------------------------
-- 20-21 · Interés único y consentimiento propio
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

insert into public.interest_registrations (user_id, municipality_code)
values (auth.uid(), '20001');

insert into public.consents (user_id, doc_type, version)
values (auth.uid(), 'terms_and_conditions', 'v1.0');

do $$
begin
  insert into public.interest_registrations (user_id, municipality_code)
  values (auth.uid(), '20001');

  insert into rls_results (label, value)
  values ('duplicate_blocked', 0);
exception
  when unique_violation then
    insert into rls_results (label, value)
    values ('duplicate_blocked', 1);
end;
$$;

insert into rls_results (label, value)
select 'alice_consents', count(*) from public.consents;

reset role;

select is(
  (select value from rls_results where label = 'duplicate_blocked'),
  1::bigint,
  'duplicate interest registration is rejected'
);

select is(
  (select value from rls_results where label = 'alice_consents'),
  1::bigint,
  'alice can insert and read her own consent'
);

-- ---------------------------------------------------------------------------
-- 22 · D11 ratificada: el perfil `resident` es aceptado en `public.profiles`
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

update public.profiles
set profile_type = 'resident'
where id = auth.uid();

insert into rls_results (label, value)
select 'alice_resident_ok', count(*)
from public.profiles
where id = auth.uid() and profile_type = 'resident';

reset role;

select is(
  (select value from rls_results where label = 'alice_resident_ok'),
  1::bigint,
  'D11: profile_type accepts resident'
);

-- ---------------------------------------------------------------------------
-- 23-24 · Defensa por columnas en `price_reports`: bloquea `is_seed` e `is_hidden`
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
begin
  insert into public.price_reports (
    user_id,
    category_id,
    municipality_code,
    zone_id,
    amount_cop,
    is_seed
  )
  values (
    auth.uid(),
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    10000,
    true
  );

  insert into rls_results (label, value)
  values ('seed_insert_blocked', 0);
exception
  when insufficient_privilege then
    insert into rls_results (label, value)
    values ('seed_insert_blocked', 1);
end;
$$;

do $$
begin
  update public.price_reports
  set is_hidden = true
  where user_id = auth.uid();

  insert into rls_results (label, value)
  values ('hidden_update_blocked', 0);
exception
  when insufficient_privilege then
    insert into rls_results (label, value)
    values ('hidden_update_blocked', 1);
end;
$$;

reset role;

select is(
  (select value from rls_results where label = 'seed_insert_blocked'),
  1::bigint,
  'authenticated user cannot set is_seed on price_reports'
);

select is(
  (select value from rls_results where label = 'hidden_update_blocked'),
  1::bigint,
  'authenticated user cannot update is_hidden on price_reports'
);

-- ---------------------------------------------------------------------------
-- 25-26 · RF-06 / Ley 1581: `delete_my_account()` sanea reportes y borra cuenta
-- ---------------------------------------------------------------------------
insert into public.price_reports (
  id,
  user_id,
  category_id,
  municipality_code,
  zone_id,
  amount_cop,
  location,
  place_name,
  source_note
)
values (
  '99999999-9999-9999-9999-999999999999',
  '22222222-2222-2222-2222-222222222222',
  'transport_taxi_minimal',
  '20001',
  'vup_centro',
  14000,
  ST_SetSRID(ST_MakePoint(-73.25, 10.46), 4326)::geography,
  'Casa privada de Bob',
  'Nota personal de Bob'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select public.delete_my_account();

reset role;

select is(
  (
    select count(*)::int
    from public.profiles
    where id = '22222222-2222-2222-2222-222222222222'
  ),
  0,
  'delete_my_account removes user profile via cascade'
);

select is(
  (
    select count(*)::int
    from public.price_reports
    where id = '99999999-9999-9999-9999-999999999999'
      and user_id is null
      and place_name is null
      and source_note is null
      and location is null
      and amount_cop = 14000
  ),
  1,
  'delete_my_account anonymizes and sanitizes price_reports while keeping statistical amount'
);

select * from finish();
rollback;
