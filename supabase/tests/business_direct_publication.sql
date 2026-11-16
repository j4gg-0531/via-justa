-- VJ-16: publicación del dueño, aislamiento y visibilidad inmediata.
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
    'alice.merchant@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Alice Merchant"}'::jsonb,
    now(),
    now()
  ),
  (
    'bbbb2222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'bob.other@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Bob Other"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

-- Alice tiene perfil `visitor` (verifica que `resident` NO sea requisito)
update public.profiles
set profile_type = 'visitor',
    current_municipality_code = '20001'
where id = 'aaaa1111-1111-4111-8111-111111111111';

create temp table vj16_state (
  business_id uuid
);
grant select, insert, update, delete on vj16_state to anon, authenticated;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';
insert into vj16_state (business_id)
select (
  public.submit_business(
    p_client_request_id := '10000000-0000-4000-8000-000000000010'::uuid,
    p_type := 'restaurant',
    p_name := 'Sabores del Río Guatapurí',
    p_description_es := 'Cocina tradicional vallenata con sancocho de gallina, chivo guisado y jugos naturales.',
    p_description_en := 'Traditional vallenato kitchen serving hen sancocho, stewed goat and fresh juices.',
    p_latitude := 10.4765,
    p_longitude := -73.2445,
    p_address := 'Carrera 9 #14-22 Barrio Novalito',
    p_phone := '6055712345',
    p_whatsapp := '573009876543',
    p_whatsapp_consent := true,
    p_publication_consent := true,
    p_order_url := 'https://menu.saboresguatapuri.co/carta',
    p_hours := '{"mon":[{"open":"08:00","close":"16:00"}],"sat":[{"open":"09:00","close":"21:00"}],"sun":[]}'::jsonb,
    p_place_id := 'ChIJ_ValleduparPlaceId001',
    p_dishes := '[
      {"name":"Sancocho de gallina criolla","price_cop":22000,"description":"Con arroz de fideo y aguacate"},
      {"name":"Chivo guisado con arroz de camarón","price_cop":28000,"description":"Porción tradicional"}
    ]'::jsonb,
    p_municipality_code := '20001'
  )
).id;

select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), null)$$,
  '22023', null, 'La cantidad esperada de fotos es obligatoria'
);
select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), 6)$$,
  '22023', null, 'Se rechazan más de cinco fotos'
);
select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), -1)$$,
  '22023', null, 'Se rechaza una cantidad negativa de fotos'
);
select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), 1)$$,
  '22023', null, 'Una subida incompleta permite reintentar y mantiene el registro privado'
);
select is((select status from public.businesses where id = (select business_id from vj16_state)),
  'pending', 'El fallo de publicación conserva la preparación');

insert into storage.objects (bucket_id, name, owner, metadata)
select 'business-media', format('%s/%s/cover.jpg', auth.uid(), business_id), auth.uid(),
  '{"mimetype":"image/jpeg","size":245760}'::jsonb
from vj16_state;
insert into public.business_photos (business_id, storage_path, position, is_cover)
select business_id, format('%s/%s/cover.jpg', auth.uid(), business_id), 0, true
from vj16_state;

reset role;
set local role anon;
select is((select count(*)::int from public.businesses where id = (select business_id from vj16_state)),
  0, 'El público no ve una preparación incompleta');
select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), 1)$$,
  '42501', null, 'Un visitante sin sesión no publica'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), 1)$$,
  '42501', null, 'Una sesión sin identidad no puede publicar'
);
set local request.jwt.claims = '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';
select throws_ok(
  $$select public.publish_business((select business_id from vj16_state), 1)$$,
  'P0002', null, 'Una segunda cuenta no puede publicar un negocio ajeno'
);

set local request.jwt.claims = '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';
select is((public.publish_business((select business_id from vj16_state), 1)).status,
  'approved', 'El dueño publica inmediatamente sin administrador');
select is((public.publish_business((select business_id from vj16_state), 1)).id,
  (select business_id from vj16_state), 'Repetir la publicación devuelve el mismo negocio');
select ok((select reviewed_by is null and reviewed_at is null from public.businesses
  where id = (select business_id from vj16_state)), 'La publicación directa no inventa una revisión administrativa');

update public.businesses set address = 'Carrera 9 #14-22 Local 2 Barrio Novalito'
where id = (select business_id from vj16_state);
select is((select status from public.businesses where id = (select business_id from vj16_state)),
  'approved', 'Editar datos conserva la publicación');
update public.business_photos set is_cover = false where business_id = (select business_id from vj16_state);
select is((select status from public.businesses where id = (select business_id from vj16_state)),
  'approved', 'Editar fotos conserva la publicación');
update public.business_dishes set price_cop = 25000 where business_id = (select business_id from vj16_state);
select is((select status from public.businesses where id = (select business_id from vj16_state)),
  'approved', 'Editar platos conserva la publicación');

reset role;
set local role anon;
select is((select count(*)::int from public.get_business_catalog('20001')
  where id = (select business_id from vj16_state)), 1, 'El catálogo público devuelve el negocio publicado');
select is(public.get_business_detail((select business_id from vj16_state))->>'id',
  (select business_id::text from vj16_state), 'La ficha pública devuelve el negocio publicado');
select is((select count(*)::int from public.get_municipality_map_items('20001', null, null, null, null, null, false, 200)
  where source_type = 'business' and name_es = 'Sabores del Río Guatapurí'),
  1, 'El negocio aparece inmediatamente en el mapa');
select is((select count(*)::int from storage.objects where bucket_id = 'business-media'
  and name = format('aaaa1111-1111-4111-8111-111111111111/%s/cover.jpg', (select business_id from vj16_state))),
  1, 'La foto publicada es visible para el público');

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';
update public.businesses set name = 'Nombre cambiado por otra cuenta' where id = (select business_id from vj16_state);
delete from public.businesses where id = (select business_id from vj16_state);
select is((select name from public.businesses where id = (select business_id from vj16_state)),
  'Sabores del Río Guatapurí', 'Otra cuenta no puede editar ni eliminar el negocio publicado');

set local request.jwt.claims = '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';
select throws_ok(
  $$update public.businesses set status = 'approved' where id = (select business_id from vj16_state)$$,
  '42501', null, 'El cliente no escribe directamente la columna de estado'
);
delete from public.businesses where id = (select business_id from vj16_state);
select is((select count(*)::int from public.businesses where id = (select business_id from vj16_state)),
  0, 'El dueño puede retirar su negocio');

select is((public.publish_business((public.submit_business(
  p_client_request_id := '10000000-0000-4000-8000-000000000011'::uuid,
  p_type := 'service',
  p_name := 'Lavandería sin fotos',
  p_description_es := 'Servicio de lavandería por tandas en Valledupar.',
  p_description_en := 'Laundry services for residents and visitors in Valledupar.',
  p_latitude := 10.4765,
  p_longitude := -73.2445,
  p_address := 'Carrera 9 #14-22 Local 3',
  p_phone := '6055712345',
  p_publication_consent := true
)).id, 0)).status, 'approved', 'Un registro sin fotos se publica en el mismo envío');

reset role;
select * from finish();
rollback;
