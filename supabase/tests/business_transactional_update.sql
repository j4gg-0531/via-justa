-- VJ-17: edición transaccional atómica de datos, platos y fotos del negocio propio.
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
    'owner.txedit@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Owner TxEdit"}'::jsonb,
    now(),
    now()
  ),
  (
    'bbbb2222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'other.txedit@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Other TxEdit"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

create temp table tx_edit_state (
  business_id uuid
);
grant select, insert, update, delete on tx_edit_state to anon, authenticated;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

insert into tx_edit_state (business_id)
select (
  public.submit_business(
    p_client_request_id := '30000000-0000-4000-8000-000000000001'::uuid,
    p_type := 'restaurant',
    p_name := 'Cocina Inicial',
    p_description_es := 'Cocina casera tradicional en el centro de Valledupar.',
    p_description_en := 'Traditional home-style cooking in downtown Valledupar.',
    p_latitude := 10.4742,
    p_longitude := -73.2436,
    p_address := 'Calle 15 #10-20',
    p_phone := '6055712345',
    p_publication_consent := true,
    p_dishes := '[{"name":"Sancocho inicial","price_cop":18000}]'::jsonb,
    p_municipality_code := '20001'
  )
).id;

insert into storage.objects (bucket_id, name, owner, metadata)
select 'business-media', format('%s/%s/photo_0.jpg', auth.uid(), business_id), auth.uid(),
  '{"mimetype":"image/jpeg","size":120000}'::jsonb
from tx_edit_state;

insert into public.business_photos (business_id, storage_path, position, is_cover)
select business_id, format('%s/%s/photo_0.jpg', auth.uid(), business_id), 0, true
from tx_edit_state;

select is(
  (public.publish_business((select business_id from tx_edit_state), 1)).status,
  'approved',
  'El negocio inicial queda publicado antes de editar'
);

-- 1. Si un plato o foto falla en update_own_business, toda la transacción hace rollback
select throws_ok(
  $$select public.update_own_business(
      p_business_id := (select business_id from tx_edit_state),
      p_name := 'Cocina Que Debe Revertirse',
      p_description_es := 'Descripción actualizada que debe revertirse con los platos.',
      p_description_en := 'Updated description that should roll back.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 15 #10-20 Local 2',
      p_phone := '6055712345',
      p_dishes := '[{"name":"Plato inválido","price_cop":100}]'::jsonb,
      p_photos := '[]'::jsonb
    )$$,
  '23514',
  null,
  'Un fallo en un plato revierte la actualización completa del negocio y sus fotos'
);

select is(
  (select name from public.businesses where id = (select business_id from tx_edit_state)),
  'Cocina Inicial',
  'El rollback conserva el nombre original'
);
select is(
  (select count(*)::int from public.business_dishes where business_id = (select business_id from tx_edit_state) and name = 'Sancocho inicial'),
  1,
  'El rollback conserva el plato original'
);
select is(
  (select count(*)::int from public.business_photos where business_id = (select business_id from tx_edit_state)),
  1,
  'El rollback conserva la foto original'
);

-- 2. Otra cuenta no puede actualizar el negocio
set local request.jwt.claims =
  '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';
select throws_ok(
  $$select public.update_own_business(
      p_business_id := (select business_id from tx_edit_state),
      p_name := 'Intento ajeno',
      p_description_es := 'Descripción válida de al menos veinte caracteres.',
      p_description_en := 'Valid description of at least twenty characters.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 15 #10-20'
    )$$,
  'P0002',
  null,
  'Otra cuenta autenticada no puede editar un negocio ajeno'
);

-- 3. Edición válida reemplaza datos, platos y fotos atómicamente y devuelve fotos desplazadas
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

insert into storage.objects (bucket_id, name, owner, metadata)
select 'business-media', format('%s/%s/edit_new_0.png', auth.uid(), business_id), auth.uid(),
  '{"mimetype":"image/png","size":95000}'::jsonb
from tx_edit_state;

select is(
  (
    select jsonb_array_length(
      public.update_own_business(
        p_business_id := (select business_id from tx_edit_state),
        p_name := 'Cocina Renovada',
        p_description_es := 'Cocina tradicional renovada en el centro de Valledupar.',
        p_description_en := 'Renewed traditional kitchen in downtown Valledupar.',
        p_latitude := 10.4750,
        p_longitude := -73.2440,
        p_address := 'Calle 16 #9-10',
        p_phone := '6055799999',
        p_dishes := '[{"name":"Chivo asado","price_cop":28000}]'::jsonb,
        p_photos := jsonb_build_array(
          jsonb_build_object(
            'storage_path', format('aaaa1111-1111-4111-8111-111111111111/%s/edit_new_0.png', (select business_id from tx_edit_state)),
            'position', 0,
            'is_cover', true
          )
        )
      )->'removed_photo_paths'
    )
  ),
  1,
  'La edición atómica devuelve la ruta de la foto anterior desplazada para limpiarla después'
);

select is(
  (select row(name, status)::text from public.businesses where id = (select business_id from tx_edit_state)),
  '("Cocina Renovada",approved)',
  'La edición transaccional actualiza los datos y conserva status = approved'
);
select is(
  (select name from public.business_dishes where business_id = (select business_id from tx_edit_state)),
  'Chivo asado',
  'La edición transaccional actualiza los platos destacados'
);
select is(
  (select count(*)::int from public.business_photos where business_id = (select business_id from tx_edit_state) and storage_path like '%edit_new_0.png'),
  1,
  'La edición transaccional enlaza la nueva foto en business_photos'
);

reset role;
select * from finish();
rollback;
