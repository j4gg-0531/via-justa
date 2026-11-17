-- Valoraciones con estrellas: reglas de dominio, bloqueo de autovaloración del dueño,
-- modificación de voto y cálculo de promedio y conteo en get_business_detail.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

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
    'aaaa1111-1111-4111-8111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'owner.ratings@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Owner Ratings"}'::jsonb,
    now(),
    now()
  ),
  (
    'bbbb2222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'voter1.ratings@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Voter One"}'::jsonb,
    now(),
    now()
  ),
  (
    'cccc3333-3333-4333-8333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'voter2.ratings@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Voter Two"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

create temp table rating_test_state (
  business_id uuid
);
grant select, insert, update, delete on rating_test_state to anon, authenticated;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

insert into rating_test_state (business_id)
select (
  public.publish_business(
    (
      public.submit_business(
        p_client_request_id := '20000000-0000-4000-8000-000000000001'::uuid,
        p_type := 'restaurant',
        p_name := 'Cocina del Patio',
        p_description_es := 'Almuerzos y comida casera tradicional en el centro de Valledupar.',
        p_description_en := 'Traditional home-style lunches in downtown Valledupar.',
        p_latitude := 10.4742,
        p_longitude := -73.2436,
        p_address := 'Sector Centro Calle 15 #10-20',
        p_phone := '6055712345',
        p_publication_consent := true,
        p_municipality_code := '20001'
      )
    ).id,
    0
  )
).id;

-- 1. Un negocio recién publicado no tiene valoraciones.
select is(
  (public.get_business_detail((select business_id from rating_test_state))->>'rating_count')::int,
  0,
  'Un negocio nuevo devuelve rating_count = 0 (Sin valoraciones)'
);
select is(
  public.get_business_detail((select business_id from rating_test_state))->'rating_average',
  'null'::jsonb,
  'Un negocio nuevo devuelve rating_average = null'
);

-- 2. El dueño no puede valorar su propio negocio.
select throws_ok(
  $$select public.rate_business((select business_id from rating_test_state), 5)$$,
  '22023',
  null,
  'El dueño no puede valorar su propio comercio'
);

-- 3. Visitante sin sesión no puede valorar.
reset role;
set local role anon;
select throws_ok(
  $$select public.rate_business((select business_id from rating_test_state), 5)$$,
  '42501',
  null,
  'Un visitante anónimo no puede ejecutar rate_business'
);

-- 4. Cuenta autenticada distinta al dueño vota y modifica su voto sin duplicar.
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';

select throws_ok(
  $$select public.rate_business((select business_id from rating_test_state), 0)$$,
  '22023',
  null,
  'Se rechaza valoración menor a 1 estrella'
);
select throws_ok(
  $$select public.rate_business((select business_id from rating_test_state), 6)$$,
  '22023',
  null,
  'Se rechaza valoración mayor a 5 estrellas'
);

select is(
  (public.rate_business((select business_id from rating_test_state), 4)->>'rating_count')::int,
  1,
  'Primera valoración registra 1 voto'
);
select is(
  (public.rate_business((select business_id from rating_test_state), 5)->>'rating_count')::int,
  1,
  'Modificar el voto actualiza la misma fila sin duplicar el conteo'
);
select is(
  (public.get_business_detail((select business_id from rating_test_state))->>'my_rating')::int,
  5,
  'get_business_detail devuelve my_rating = 5 para el votante autenticado'
);

-- 5. Segunda cuenta autenticada vota y actualiza el promedio a 3.5 (5 y 2).
set local request.jwt.claims =
  '{"sub":"cccc3333-3333-4333-8333-333333333333","role":"authenticated"}';

select is(
  (public.rate_business((select business_id from rating_test_state), 2)->>'rating_average')::numeric,
  3.5,
  'El promedio con votos de 5 y 2 estrellas es 3.5'
);
select is(
  (public.get_business_detail((select business_id from rating_test_state))->>'rating_count')::int,
  2,
  'get_business_detail devuelve rating_count = 2'
);

-- 6. Una cuenta no puede alterar ni borrar el voto de otra cuenta.
update public.business_ratings
set stars = 1
where business_id = (select business_id from rating_test_state)
  and user_id = 'bbbb2222-2222-4222-8222-222222222222';

delete from public.business_ratings
where business_id = (select business_id from rating_test_state)
  and user_id = 'bbbb2222-2222-4222-8222-222222222222';

select is(
  (
    select stars::int
    from public.business_ratings
    where business_id = (select business_id from rating_test_state)
      and user_id = 'bbbb2222-2222-4222-8222-222222222222'
  ),
  5,
  'Otra cuenta autenticada no puede editar ni eliminar una valoración ajena'
);

reset role;
select * from finish();
rollback;
