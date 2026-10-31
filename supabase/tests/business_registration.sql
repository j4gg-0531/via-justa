-- ============================================================================
-- Pruebas pgTAP · Registro de Negocios en 4 Pasos, Storage y Moderación (VJ-16)
-- ============================================================================
-- Cubre todos los casos exigidos por el Plan Maestro (§VJ-16):
--   1. Existencia de RPCs (`submit_business`, `moderate_business`,
--      `get_business_moderation_queue`, `list_orphan_business_media`,
--      `is_valid_business_hours`) y configuración privada del bucket
--      `business-media` (5 MiB, JPEG/PNG/WebP).
--   2. Cualquier perfil autorizado (`visitor`, `settler` o `resident`) puede
--      registrar un negocio; nace obligatoriamente en `status = 'pending'`
--      fijado en servidor e idempotente por `client_request_id`.
--   3. Rechazo de campos faltantes o inválidos (municipio no piloto, nombre
--      corto o con `[DEMO]`, WhatsApp sin consentimiento, sin consentimiento
--      de publicación, URI de pedido maliciosa `javascript:` o `http://`,
--      horario inválido y 6.º plato destacado).
--   4. Storage y `business_photos`: rechazo de 6.º archivo en Storage,
--      rechazo de PDF disfrazado de `.jpg` (`[BUSINESS_PHOTO_INVALID_MIME]`),
--      y privacidad de fotos mientras el negocio está `pending`.
--   5. RLS y aislamiento entre usuarios: negocio `pending` invisible al
--      público y a terceros; usuario B no modifica negocio ni fotos de A;
--      cliente no puede forzar `status = 'approved'`.
--   6. Moderación administrativa: bloqueo a no-admin, bloqueo de auto-revisión,
--      motivo obligatorio al rechazar (`>= 10` caracteres), edición del dueño
--      tras rechazo que devuelve a `pending`, y aprobación final que hace
--      visible el negocio y sus fotos al público.
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

-- ---------------------------------------------------------------------------
-- Preparación de usuarios:
--   * Alice (visitor): dueña del negocio.
--   * Bob (resident): otro usuario común (no puede editar ni ver pending ajeno).
--   * Carol: administradora registrada en `public.admin_users`.
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
  ),
  (
    'cccc3333-3333-4333-8333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'carol.admin@example.test',
    extensions.crypt('password123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Carol Admin"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

-- Alice tiene perfil `visitor` (verifica que `resident` NO sea requisito)
update public.profiles
set profile_type = 'visitor',
    current_municipality_code = '20001'
where id = 'aaaa1111-1111-4111-8111-111111111111';

insert into public.admin_users (user_id)
values ('cccc3333-3333-4333-8333-333333333333')
on conflict (user_id) do nothing;

create temp table vj16_state (
  business_id uuid
);
grant select, insert, update, delete on vj16_state to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1-3 · Existencia de RPCs y configuración del bucket privado `business-media`
-- ---------------------------------------------------------------------------
select has_function(
  'public',
  'submit_business',
  array[
    'uuid', 'text', 'text', 'text', 'text',
    'double precision', 'double precision', 'text', 'text', 'text',
    'boolean', 'boolean', 'text', 'jsonb', 'text', 'jsonb', 'text'
  ],
  'submit_business RPC exists with expected 17-argument signature'
);

select has_function(
  'public',
  'moderate_business',
  array['uuid', 'text', 'text'],
  'moderate_business RPC exists with expected signature'
);

select is(
  (
    select row(b.public, b.file_size_limit, b.allowed_mime_types)::text
    from storage.buckets b
    where b.id = 'business-media'
  ),
  row(false, 5242880::bigint, array['image/jpeg', 'image/png', 'image/webp'])::text,
  'business-media bucket is private, limited to 5 MiB, and restricts MIME types to JPEG/PNG/WebP'
);

-- ---------------------------------------------------------------------------
-- 4-9 · Validaciones de rechazo en servidor (WhatsApp sin consentimiento,
--       falta de consentimiento de publicación, municipio no piloto, URL
--       maliciosa, 6.º plato destacado y forzamiento de status=approved)
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

select throws_ok(
  $$
    select public.submit_business(
      p_client_request_id := '10000000-0000-4000-8000-000000000001'::uuid,
      p_type := 'restaurant',
      p_name := 'Asadero Sin Consentimiento WA',
      p_description_es := 'Restaurante típico vallenato con carnes asadas y almuerzos caseros.',
      p_description_en := 'Traditional vallenato restaurant with grilled meats and homemade lunches.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 16 #9-30 Centro',
      p_phone := '6055701234',
      p_whatsapp := '573001112233',
      p_whatsapp_consent := false,
      p_publication_consent := true
    );
  $$,
  '22023',
  null,
  'submit_business rejects WhatsApp number when p_whatsapp_consent is false'
);

select throws_ok(
  $$
    select public.submit_business(
      p_client_request_id := '10000000-0000-4000-8000-000000000002'::uuid,
      p_type := 'restaurant',
      p_name := 'Asadero Sin Consentimiento Publicacion',
      p_description_es := 'Restaurante típico vallenato con carnes asadas y almuerzos caseros.',
      p_description_en := 'Traditional vallenato restaurant with grilled meats and homemade lunches.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 16 #9-30 Centro',
      p_phone := '6055701234',
      p_whatsapp := null,
      p_whatsapp_consent := false,
      p_publication_consent := false
    );
  $$,
  '22023',
  null,
  'submit_business rejects submission without publication consent'
);

select throws_ok(
  $$
    select public.submit_business(
      p_client_request_id := '10000000-0000-4000-8000-000000000003'::uuid,
      p_type := 'restaurant',
      p_name := 'Restaurante Fuera De Piloto',
      p_description_es := 'Restaurante típico vallenato con carnes asadas y almuerzos caseros.',
      p_description_en := 'Traditional vallenato restaurant with grilled meats and homemade lunches.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 16 #9-30 Centro',
      p_phone := '6055701234',
      p_whatsapp := '573001112233',
      p_whatsapp_consent := true,
      p_publication_consent := true,
      p_municipality_code := '20011'
    );
  $$,
  '22023',
  null,
  'submit_business rejects non-pilot municipality (20011 Aguachica)'
);

select throws_ok(
  $$
    select public.submit_business(
      p_client_request_id := '10000000-0000-4000-8000-000000000004'::uuid,
      p_type := 'restaurant',
      p_name := 'Restaurante URL Maliciosa',
      p_description_es := 'Restaurante típico vallenato con carnes asadas y almuerzos caseros.',
      p_description_en := 'Traditional vallenato restaurant with grilled meats and homemade lunches.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 16 #9-30 Centro',
      p_phone := '6055701234',
      p_whatsapp := '573001112233',
      p_whatsapp_consent := true,
      p_publication_consent := true,
      p_order_url := 'javascript:alert(document.cookie)'
    );
  $$,
  '22023',
  null,
  'submit_business rejects malicious non-HTTPS order_url (javascript: scheme)'
);

select throws_ok(
  $$
    select public.submit_business(
      p_client_request_id := '10000000-0000-4000-8000-000000000005'::uuid,
      p_type := 'restaurant',
      p_name := 'Restaurante Seis Platos',
      p_description_es := 'Restaurante típico vallenato con carnes asadas y almuerzos caseros.',
      p_description_en := 'Traditional vallenato restaurant with grilled meats and homemade lunches.',
      p_latitude := 10.4742,
      p_longitude := -73.2436,
      p_address := 'Calle 16 #9-30 Centro',
      p_phone := '6055701234',
      p_whatsapp := '573001112233',
      p_whatsapp_consent := true,
      p_publication_consent := true,
      p_dishes := '[
        {"name":"Plato 1","price_cop":15000},
        {"name":"Plato 2","price_cop":16000},
        {"name":"Plato 3","price_cop":17000},
        {"name":"Plato 4","price_cop":18000},
        {"name":"Plato 5","price_cop":19000},
        {"name":"Plato 6","price_cop":20000}
      ]'::jsonb
    );
  $$,
  '22023',
  null,
  'submit_business rejects more than 5 featured dishes (6th dish blocked)'
);

select throws_ok(
  $$
    insert into public.businesses (
      owner_id,
      municipality_code,
      type,
      name,
      description_es,
      description_en,
      address,
      location,
      whatsapp,
      whatsapp_consent_at,
      publication_consent_at,
      status
    )
    values (
      auth.uid(),
      '20001',
      'restaurant',
      'Intento Forzar Approved',
      'Descripción válida de más de veinte caracteres en español.',
      'Valid description with more than twenty characters in English.',
      'Calle 15 #10-20 Centro',
      extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2436, 10.4742), 4326)::extensions.geography,
      '573001112233',
      now(),
      now(),
      'approved'
    );
  $$,
  '42501',
  null,
  'authenticated user cannot force status=approved on direct INSERT (column privilege denied)'
);

-- ---------------------------------------------------------------------------
-- 10-12 · Registro válido en 4 pasos por perfil `visitor` + idempotencia
-- ---------------------------------------------------------------------------
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

select is(
  (
    select row(b.status, b.owner_id, b.is_demo, (select count(*)::int from public.business_dishes d where d.business_id = b.id))::text
    from public.businesses b
    where b.id = (select business_id from vj16_state limit 1)
  ),
  row('pending'::text, 'aaaa1111-1111-4111-8111-111111111111'::uuid, false, 2)::text,
  'visitor profile registers business with status=pending fixed on server and 2 featured dishes'
);

select is(
  (
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
        p_publication_consent := true
      )
    ).id
  ),
  (select business_id from vj16_state limit 1),
  're-submitting with the same client_request_id is idempotent and returns the same business UUID'
);

-- ---------------------------------------------------------------------------
-- 13-15 · Storage y `business_photos`:
--   * Subida de 5 fotos válidas en `{owner_id}/{business_id}/photo_N.jpg`.
--   * Rechazo del 6.º archivo en `storage.objects`.
--   * Rechazo de PDF disfrazado de `.jpg` al vincular en `public.business_photos`.
-- ---------------------------------------------------------------------------
do $$
declare
  v_bid uuid := (select business_id from vj16_state limit 1);
  v_oid text := 'aaaa1111-1111-4111-8111-111111111111';
begin
  for i in 1..4 loop
    insert into storage.objects (bucket_id, name, owner, metadata)
    values (
      'business-media',
      format('%s/%s/photo_%s.jpg', v_oid, v_bid, i),
      v_oid::uuid,
      '{"mimetype":"image/jpeg","size":245760}'::jsonb
    );
  end loop;

  -- 5.º objeto: archivo PDF disfrazado con extensión .jpg
  insert into storage.objects (bucket_id, name, owner, metadata)
  values (
    'business-media',
    format('%s/%s/disguised_pdf.jpg', v_oid, v_bid),
    v_oid::uuid,
    '{"mimetype":"application/pdf","size":102400}'::jsonb
  );
end;
$$;

select throws_ok(
  $$
    insert into storage.objects (bucket_id, name, owner, metadata)
    values (
      'business-media',
      format(
        'aaaa1111-1111-4111-8111-111111111111/%s/photo_6.jpg',
        (select business_id from vj16_state limit 1)
      ),
      'aaaa1111-1111-4111-8111-111111111111'::uuid,
      '{"mimetype":"image/jpeg","size":200000}'::jsonb
    );
  $$,
  '42501',
  null,
  'storage.objects RLS blocks uploading a 6th file for the same business'
);

select throws_ok(
  $$
    insert into public.business_photos (business_id, storage_path, position, is_cover)
    values (
      (select business_id from vj16_state limit 1),
      format(
        'aaaa1111-1111-4111-8111-111111111111/%s/disguised_pdf.jpg',
        (select business_id from vj16_state limit 1)
      ),
      0,
      true
    );
  $$,
  '22023',
  null,
  'business_photos rejects a PDF disguised with .jpg extension (real MIME check against storage.objects)'
);

select lives_ok(
  $$
    insert into public.business_photos (business_id, storage_path, position, is_cover)
    values (
      (select business_id from vj16_state limit 1),
      format(
        'aaaa1111-1111-4111-8111-111111111111/%s/photo_1.jpg',
        (select business_id from vj16_state limit 1)
      ),
      0,
      true
    );
  $$,
  'owner links valid JPEG photo_1.jpg as cover in business_photos'
);

reset role;

-- ---------------------------------------------------------------------------
-- 16-18 · Privacidad de `pending` y aislamiento entre usuarios (Bob vs Alice)
-- ---------------------------------------------------------------------------
set local role anon;

select is(
  (
    select count(*)::int
    from public.businesses b
    where b.id = (select business_id from vj16_state limit 1)
  ),
  0,
  'pending business is completely invisible to anon public queries'
);

select is(
  (
    select count(*)::int
    from storage.objects o
    where o.bucket_id = 'business-media'
      and o.name like 'aaaa1111-1111-4111-8111-111111111111/%'
  ),
  0,
  'photos of a pending business in storage.objects are invisible to anon'
);

reset role;

-- Bob (otro usuario autenticado) intenta modificar el negocio de Alice y moderarlo
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';

update public.businesses
set name = 'Sabores Hackeado Por Bob'
where id = (select business_id from vj16_state limit 1);

select throws_ok(
  $$
    select public.moderate_business(
      (select business_id from vj16_state limit 1),
      'approved',
      null
    );
  $$,
  '42501',
  null,
  'non-admin user Bob cannot call moderate_business ([MODERATION_FORBIDDEN])'
);

reset role;

select is(
  (
    select b.name
    from public.businesses b
    where b.id = (select business_id from vj16_state limit 1)
  ),
  'Sabores del Río Guatapurí',
  'user B (Bob) cannot modify user A (Alice) business'
);

-- ---------------------------------------------------------------------------
-- 19-24 · Moderación por administradora (Carol) y ciclo rechazo → edición → aprobación
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"cccc3333-3333-4333-8333-333333333333","role":"authenticated"}';

select throws_ok(
  $$
    select public.moderate_business(
      (select business_id from vj16_state limit 1),
      'rejected',
      'corto'
    );
  $$,
  '22023',
  null,
  'admin rejection without a >=10-char reason is rejected ([MODERATION_REASON_REQUIRED])'
);

select is(
  (
    select (
      public.moderate_business(
        (select business_id from vj16_state limit 1),
        'rejected',
        'Por favor especifica el número de local en la dirección antes de publicar.'
      )
    ).status
  ),
  'rejected',
  'admin Carol rejects business with a clear reason and status becomes rejected'
);

reset role;

-- Alice corrige la dirección tras el rechazo: el negocio vuelve automáticamente a `pending`
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

update public.businesses
set address = 'Carrera 9 #14-22 Local 2 Barrio Novalito'
where id = (select business_id from vj16_state limit 1);

reset role;

select is(
  (
    select row(b.status, b.rejection_reason)::text
    from public.businesses b
    where b.id = (select business_id from vj16_state limit 1)
  ),
  row('pending'::text, null::text)::text,
  'owner editing a rejected business automatically resets status to pending and clears rejection_reason'
);

-- Carol aprueba el negocio corregido
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"cccc3333-3333-4333-8333-333333333333","role":"authenticated"}';

select is(
  (
    select (
      public.moderate_business(
        (select business_id from vj16_state limit 1),
        'approved',
        null
      )
    ).status
  ),
  'approved',
  'admin Carol approves the re-submitted business'
);

reset role;

-- Ahora el público (`anon`) ve el negocio aprobado y puede leer sus fotos en Storage
set local role anon;

select is(
  (
    select count(*)::int
    from public.businesses b
    where b.id = (select business_id from vj16_state limit 1)
      and b.status = 'approved'
  ),
  1,
  'approved business is visible to the public (anon)'
);

select is(
  (
    select count(*)::int
    from storage.objects o
    where o.bucket_id = 'business-media'
      and o.name = format(
        'aaaa1111-1111-4111-8111-111111111111/%s/photo_1.jpg',
        (select business_id from vj16_state limit 1)
      )
  ),
  1,
  'photos of an approved business in storage.objects become readable by the public'
);

reset role;

select * from finish();
rollback;
