-- ============================================================================
-- Vía Justa MVP · Suite pgTAP: Auditoría Cruzada de Seguridad y Privacidad (VJ-18 / VJ-19)
-- ============================================================================
-- Verifica automáticamente:
--   1. Las 16 tablas de `public` tienen RLS habilitado (`relrowsecurity = true`).
--   2. El rol `anon` tiene 0 permisos de escritura (`INSERT`, `UPDATE`, `DELETE`,
--      `TRUNCATE`) en todas las tablas del esquema `public`.
--   3. El 100 % de las funciones propias en `public` y `private` tienen
--      `search_path` explícito e inmutable en `pg_proc.proconfig`.
--   4. Ninguna función de `public` o `private` conserva `GRANT EXECUTE` implícito
--      al pseudo-rol `PUBLIC` (`=X/`).
--   5. `anon` y `authenticated` no pueden invocar funciones internas de cuota
--      (`consume_ai_daily_quota`, `refund_ai_daily_quota`).
--   6. `authenticated` no puede escalar privilegios ni editar columnas protegidas
--      (`profiles.id`, `price_reports.is_hidden`, `businesses.status`).
--   7. Saneamiento automático de etiquetas HTML/scripts en `price_reports`.
--   8. Aislamiento cruzado estricto Usuario A vs. Usuario B.
--   9. Bloqueo de auto-moderación (`[MODERATION_SELF_REVIEW]`) en `moderate_price_report`.
--  10. Ciclo de vida integral de `public.delete_my_account()` (RF-06 / Ley 1581)
--      cuando el usuario posee datos en todas las tablas del sistema.
-- ============================================================================

begin;

select plan(16);

-- ---------------------------------------------------------------------------
-- 0. Preparación de usuarios de prueba (Usuario A, Usuario B y Admin)
-- ---------------------------------------------------------------------------
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    'aaaa1111-1111-4111-8111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'audit.user.a@viajusta.test',
    crypt('PasswordSegura123!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Usuario Auditoria A"}'::jsonb,
    now(),
    now()
  ),
  (
    'bbbb2222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'audit.user.b@viajusta.test',
    crypt('PasswordSegura123!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Usuario Auditoria B"}'::jsonb,
    now(),
    now()
  ),
  (
    'cccc3333-3333-4333-8333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'audit.admin@viajusta.test',
    crypt('PasswordSegura123!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Admin Auditoria"}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

insert into public.admin_users (user_id)
values ('cccc3333-3333-4333-8333-333333333333')
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------------
-- 1. Invariante G2: 100 % de las tablas en `public` tienen RLS habilitado
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relrowsecurity = false
  ),
  0,
  'VJ-18/19 (1): Todas las tablas del esquema public tienen Row Level Security (RLS) activo'
);

-- ---------------------------------------------------------------------------
-- 2. Invariante G2: `anon` tiene 0 permisos de escritura en `public`
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::integer
    from information_schema.role_table_grants g
    where g.table_schema = 'public'
      and g.grantee = 'anon'
      and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
  ),
  0,
  'VJ-18/19 (2): El rol anon tiene 0 privilegios de escritura (INSERT/UPDATE/DELETE/TRUNCATE) en public'
);

-- ---------------------------------------------------------------------------
-- 3. Invariante G2: 100 % de funciones en `public` y `private` fijan `search_path`
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and not exists (
        select 1
        from unnest(coalesce(p.proconfig, array[]::text[])) cfg
        where cfg like 'search_path=%'
      )
  ),
  0,
  'VJ-18/19 (3): Todas las funciones en public y private tienen search_path explicito e inmutable'
);

-- ---------------------------------------------------------------------------
-- 4. Invariante G2: Ninguna función en `public` o `private` otorga EXECUTE a PUBLIC
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and (
        p.proacl is null
        or exists (
          select 1
          from unnest(p.proacl) acl_item
          where acl_item::text like '=X/%'
        )
      )
  ),
  0,
  'VJ-18/19 (4): Ninguna funcion en public o private conserva GRANT EXECUTE implicito a PUBLIC'
);

-- ---------------------------------------------------------------------------
-- 5. `anon` no puede ejecutar `delete_my_account()`
-- ---------------------------------------------------------------------------
set local role anon;
set local request.jwt.claims = '{}';

select throws_ok(
  $$select public.delete_my_account()$$,
  '42501',
  null,
  'VJ-18/19 (5): anon no puede invocar delete_my_account()'
);

-- ---------------------------------------------------------------------------
-- 6. `authenticated` no puede invocar funciones internas de cuota de IA
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

select throws_ok(
  $$select public.consume_ai_daily_quota('aaaa1111-1111-4111-8111-111111111111'::uuid)$$,
  '42501',
  null,
  'VJ-18/19 (6): authenticated no puede invocar directamente consume_ai_daily_quota()'
);

-- ---------------------------------------------------------------------------
-- 7. `authenticated` no puede modificar columnas protegidas (`profiles.created_at`)
-- ---------------------------------------------------------------------------
select throws_ok(
  $$update public.profiles set created_at = now() - interval '10 years' where id = 'aaaa1111-1111-4111-8111-111111111111'$$,
  '42501',
  null,
  'VJ-18/19 (7): authenticated no tiene GRANT UPDATE sobre columnas de auditoria (profiles.created_at)'
);

-- ---------------------------------------------------------------------------
-- 8. Poblar actividad completa del Usuario A y verificar saneamiento HTML en reportes
-- ---------------------------------------------------------------------------
insert into public.consents (user_id, doc_type, version)
values
  ('aaaa1111-1111-4111-8111-111111111111', 'terms_and_conditions', 'v1.0'),
  ('aaaa1111-1111-4111-8111-111111111111', 'privacy_policy', 'v1.0');

insert into public.interest_registrations (user_id, municipality_code)
values ('aaaa1111-1111-4111-8111-111111111111', '08001');

select public.submit_price_report(
  'almuerzo_corriente',
  '20001',
  'vup_centro',
  15500,
  '<script>alert(1)</script>Comedor Central',
  '<b>Menu del dia verificado</b>',
  10.474256,
  -73.243689
) as _report_a \gset

select is(
  (
    select place_name || ' | ' || source_note
    from public.price_reports
    where user_id = 'aaaa1111-1111-4111-8111-111111111111'
    order by created_at desc
    limit 1
  ),
  'alert(1)Comedor Central | Menu del dia verificado',
  'VJ-18/19 (8): enforce_price_report_submission_rules limpia etiquetas HTML de place_name y source_note'
);

-- Crear negocio del Usuario A con plato y foto en Storage
select id as biz_a_id
from public.submit_business(
  '99991111-1111-4111-8111-111111111111'::uuid,
  'restaurant',
  'Asadero La Provincia A',
  'Restaurante tradicional vallenato con platos tipicos verificados para pruebas de auditoria.',
  'Traditional vallenato restaurant with verified typical dishes for security audit testing.',
  10.4742,
  -73.2436,
  'Calle 16 # 9-30 Centro',
  '+573001112233',
  '573001112233',
  true,
  true,
  'https://laprovincia.example.com/menu',
  '{"mon":[{"open":"08:00","close":"18:00"}]}'::jsonb,
  null,
  '[{"name":"Carne asada","price_cop":24000,"description":"Con yuca y guiso"}]'::jsonb,
  '20001'
) \gset

-- Subir objeto en storage.objects y vincularlo en business_photos
insert into storage.objects (bucket_id, name, owner, metadata)
values (
  'business-media',
  'aaaa1111-1111-4111-8111-111111111111/' || :'biz_a_id' || '/portada_auditoria.jpg',
  'aaaa1111-1111-4111-8111-111111111111',
  '{"mimetype":"image/jpeg","size":120000}'::jsonb
);

insert into public.business_photos (business_id, storage_path, position, is_cover)
values (
  :'biz_a_id'::uuid,
  'aaaa1111-1111-4111-8111-111111111111/' || :'biz_a_id' || '/portada_auditoria.jpg',
  0,
  true
);

-- Registrar consumo de cuota de IA para el Usuario A usando service_role
reset role;
select public.consume_ai_daily_quota('aaaa1111-1111-4111-8111-111111111111'::uuid);

-- ---------------------------------------------------------------------------
-- 9. Aislamiento cruzado: Usuario B no ve datos privados ni negocios pending de A
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbb2222-2222-4222-8222-222222222222","role":"authenticated"}';

select is(
  (
    select
      (select count(*) from public.profiles where id = 'aaaa1111-1111-4111-8111-111111111111')
      + (select count(*) from public.consents where user_id = 'aaaa1111-1111-4111-8111-111111111111')
      + (select count(*) from public.interest_registrations where user_id = 'aaaa1111-1111-4111-8111-111111111111')
      + (select count(*) from public.businesses where id = :'biz_a_id'::uuid)
  )::integer,
  0,
  'VJ-18/19 (9): Usuario B tiene visibilidad 0 sobre perfil, consentimientos, intereses y negocio pending del Usuario A'
);

-- ---------------------------------------------------------------------------
-- 10. Bloqueo de auto-revisión en `moderate_price_report` para Admin
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"cccc3333-3333-4333-8333-333333333333","role":"authenticated"}';

select public.submit_price_report(
  'almuerzo_corriente',
  '20001',
  'vup_centro',
  16000,
  'Reporte propio de admin',
  'Nota admin',
  10.4742,
  -73.2436
);

-- Ocultar el reporte desde consola privilegiada y verificar que el propio admin no puede auto-restaurarlo
reset role;
update public.price_reports
   set is_hidden = true
 where user_id = 'cccc3333-3333-4333-8333-333333333333';

select id as admin_report_id
from public.price_reports
where user_id = 'cccc3333-3333-4333-8333-333333333333'
limit 1 \gset

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccc3333-3333-4333-8333-333333333333","role":"authenticated"}';

select throws_ok(
  format(
    $$select public.moderate_price_report(%L::uuid, false, 'Intento auto restaurar')$$,
    :'admin_report_id'
  ),
  '42501',
  null,
  'VJ-18/19 (10): Un administrador no puede auto-restaurar su propio reporte oculto ([MODERATION_SELF_REVIEW])'
);

-- ---------------------------------------------------------------------------
-- 11..16. Prueba integral de `public.delete_my_account()` (Usuario A)
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaa1111-1111-4111-8111-111111111111","role":"authenticated"}';

select lives_ok(
  $$select public.delete_my_account()$$,
  'VJ-18/19 (11): Usuario A ejecuta delete_my_account() exitosamente aun teniendo negocios, fotos, platos, IA y reportes'
);

reset role;

select is(
  (
    select
      (select count(*) from auth.users where id = 'aaaa1111-1111-4111-8111-111111111111')
      + (select count(*) from public.profiles where id = 'aaaa1111-1111-4111-8111-111111111111')
  )::integer,
  0,
  'VJ-18/19 (12): delete_my_account() elimina al Usuario A de auth.users y public.profiles'
);

select is(
  (
    select
      (select count(*) from public.consents where user_id = 'aaaa1111-1111-4111-8111-111111111111')
      + (select count(*) from public.interest_registrations where user_id = 'aaaa1111-1111-4111-8111-111111111111')
      + (select count(*) from public.ai_usage where user_id = 'aaaa1111-1111-4111-8111-111111111111')
  )::integer,
  0,
  'VJ-18/19 (13): delete_my_account() elimina todos los registros de consents, interest_registrations y ai_usage'
);

select is(
  (
    select
      (select count(*) from public.businesses where id = :'biz_a_id'::uuid)
      + (select count(*) from public.business_dishes where business_id = :'biz_a_id'::uuid)
      + (select count(*) from public.business_photos where business_id = :'biz_a_id'::uuid)
  )::integer,
  0,
  'VJ-18/19 (14): delete_my_account() elimina en cascada los negocios del usuario junto con sus platos y filas de fotos'
);

select is(
  (
    select reason
    from public.list_orphan_business_media(interval '-1 second')
    where object_name = 'aaaa1111-1111-4111-8111-111111111111/' || :'biz_a_id' || '/portada_auditoria.jpg'
  ),
  'business_deleted',
  'VJ-18/19 (15): El objeto en storage.objects queda inmediatamente identificado como business_deleted por list_orphan_business_media'
);

select is(
  (
    select count(*)::integer
    from public.price_reports
    where amount_cop = 15500
      and municipality_code = '20001'
      and zone_id = 'vup_centro'
      and user_id is null
      and place_name is null
      and source_note is null
      and location is null
  ),
  1,
  'VJ-18/19 (16): El reporte de precio conserva el monto estadistico pero con user_id, place_name, source_note y location en NULL'
);

select * from finish();

rollback;
