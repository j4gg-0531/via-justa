-- ============================================================================
-- Vía Justa MVP · VJ-16 · Registro de negocios, Storage privado y moderación
-- ============================================================================
-- Objetivo (PLAN_MAESTRO §VJ-16, puntos 1 a 7 de backend/seguridad):
--   1. Endurecer `public.businesses` con reglas de dominio validadas en el
--      servidor: municipio piloto, tipos permitidos al ciudadano, longitud y
--      caracteres de nombre/descripción, dirección responsable, ubicación
--      dentro del municipio, teléfono/WhatsApp E.164 con consentimiento
--      específico, URL de pedidos solo `https`, horario estructurado y
--      consentimiento de publicación.
--   2. `status = 'pending'` y `owner_id = auth.uid()` se FIJAN en el servidor;
--      el cliente nunca puede forzar `approved`, `is_demo` ni otro dueño.
--   3. Edición del dueño (incluido tras un rechazo) devuelve el negocio a
--      `pending` para re-moderación; fotos y platos también re-moderan.
--   4. Moderación MVP solo para administradores (`public.admin_users`) o la
--      consola de Supabase: `public.moderate_business(...)` con motivo de
--      rechazo obligatorio y bloqueo de auto-revisión.
--   5. Bucket privado `business-media` (JPEG/PNG/WebP, 5 MiB) con rutas
--      `{owner_id}/{business_id}/{archivo}`: sin URLs públicas directas; las
--      fotos de negocios `pending` solo las ve su dueño o un administrador.
--   6. Idempotencia de envío (`client_request_id`), cupos por dueño y
--      detección de duplicados para evitar reenvíos y clics múltiples.
--   7. Cierra el hueco de `public.register_business_on_map` (VJ-12): dentro de
--      una función SECURITY DEFINER `current_user` siempre es `postgres`, por
--      lo que un usuario autenticado podía autoaprobar su negocio. Ahora es de
--      uso exclusivo de consola/service_role y ya no inventa un WhatsApp.
--
-- Detección del llamador:
--   Se usa `current_setting('role')`, que conserva el rol de la petición
--   (`anon`/`authenticated` vía PostgREST o `SET ROLE`) incluso dentro de
--   funciones SECURITY DEFINER. Consola, seeds y migraciones reportan `none`
--   (privilegiado). `service_role` también es privilegiado.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Esquema privado para helpers no expuestos por PostgREST
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

create or replace function private.is_privileged_caller()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(nullif(current_setting('role', true), ''), 'none')
    not in ('anon', 'authenticated');
$$;

comment on function private.is_privileged_caller() is
  'true para consola/seeds/service_role; false para peticiones anon/authenticated (aun dentro de SECURITY DEFINER).';

revoke all on function private.is_privileged_caller() from public;
grant execute on function private.is_privileged_caller() to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1. Parámetros operativos ajustables sin publicar nueva versión de la app
-- ---------------------------------------------------------------------------
insert into public.app_config (key, value)
values (
  'business_registration_rules',
  jsonb_build_object(
    'max_active_per_owner', 5,
    'max_submissions_per_day', 3,
    'max_photos', 5,
    'max_dishes', 5,
    'max_photo_bytes', 5242880,
    'location_radius_m', 60000,
    'allowed_owner_types', jsonb_build_array('restaurant', 'hotel', 'service', 'handicraft', 'transport')
  )
)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Validador puro de horario estructurado
-- ---------------------------------------------------------------------------
-- Formato: {"mon":[{"open":"08:00","close":"18:00"}], "sun":[]}
--   * Claves permitidas: mon, tue, wed, thu, fri, sat, sun.
--   * Hasta 3 franjas por día; arreglo vacío = cerrado.
--   * `close` puede ser menor que `open` (horario nocturno) pero no igual.
create or replace function public.is_valid_business_hours(p_hours jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_day text;
  v_ranges jsonb;
  v_range jsonb;
  v_time_regex constant text := '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$';
begin
  if p_hours is null then
    return true;
  end if;

  if jsonb_typeof(p_hours) <> 'object' then
    return false;
  end if;

  for v_day, v_ranges in select key, value from jsonb_each(p_hours) loop
    if v_day not in ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun') then
      return false;
    end if;

    if jsonb_typeof(v_ranges) <> 'array' or jsonb_array_length(v_ranges) > 3 then
      return false;
    end if;

    for v_range in select value from jsonb_array_elements(v_ranges) loop
      if jsonb_typeof(v_range) <> 'object' then
        return false;
      end if;

      if exists (
        select 1 from jsonb_object_keys(v_range) k where k not in ('open', 'close')
      ) then
        return false;
      end if;

      if coalesce(v_range ->> 'open', '') !~ v_time_regex
         or coalesce(v_range ->> 'close', '') !~ v_time_regex
         or v_range ->> 'open' = v_range ->> 'close' then
        return false;
      end if;
    end loop;
  end loop;

  return true;
end;
$$;

comment on function public.is_valid_business_hours(jsonb) is
  'VJ-16: valida el horario estructurado de un negocio (mon..sun, hasta 3 franjas HH:MM por día).';

grant execute on function public.is_valid_business_hours(jsonb) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Columnas y restricciones de `public.businesses`
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references auth.users(id) on delete set null,
  add column if not exists client_request_id uuid,
  add column if not exists publication_consent_at timestamptz;

-- WhatsApp deja de ser obligatorio: se exige al menos un canal de contacto
-- autorizado y, si hay WhatsApp, su consentimiento específico.
alter table public.businesses
  alter column whatsapp drop not null,
  alter column whatsapp_consent_at drop not null;

alter table public.businesses
  drop constraint if exists businesses_order_url_check,
  drop constraint if exists businesses_contact_required_check,
  drop constraint if exists businesses_whatsapp_consent_check,
  drop constraint if exists businesses_whatsapp_format_check,
  drop constraint if exists businesses_phone_format_check,
  drop constraint if exists businesses_place_id_format_check,
  drop constraint if exists businesses_hours_format_check,
  drop constraint if exists businesses_rejection_reason_check;

alter table public.businesses
  add constraint businesses_order_url_check
    check (
      order_url is null
      or (
        char_length(order_url) <= 500
        and order_url ~ '^https://[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+(:[0-9]{2,5})?(/[^[:space:]<>"''`\\]*)?$'
      )
    ),
  add constraint businesses_contact_required_check
    check (phone is not null or whatsapp is not null),
  add constraint businesses_whatsapp_consent_check
    check ((whatsapp is null) = (whatsapp_consent_at is null)),
  add constraint businesses_whatsapp_format_check
    check (whatsapp is null or whatsapp ~ '^[1-9][0-9]{9,14}$'),
  add constraint businesses_phone_format_check
    check (phone is null or phone ~ '^\+?[0-9]{7,15}$'),
  add constraint businesses_place_id_format_check
    check (place_id is null or place_id ~ '^[A-Za-z0-9_-]{10,150}$'),
  add constraint businesses_hours_format_check
    check (public.is_valid_business_hours(hours)),
  add constraint businesses_rejection_reason_check
    check (status <> 'rejected' or char_length(btrim(coalesce(rejection_reason, ''))) >= 10);

create unique index if not exists businesses_owner_request_uidx
  on public.businesses (owner_id, client_request_id)
  where client_request_id is not null;

create index if not exists businesses_pending_queue_idx
  on public.businesses (created_at)
  where status = 'pending';

-- ---------------------------------------------------------------------------
-- 4. Trigger de reglas de negocio (INSERT / UPDATE)
-- ---------------------------------------------------------------------------
create or replace function private.enforce_business_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_rules jsonb;
  v_max_active integer;
  v_max_daily integer;
  v_radius_m integer;
  v_allowed_types text[];
  v_content_changed boolean := true;
  v_count integer;
begin
  if tg_op = 'UPDATE' then
    new.updated_at := now();
  end if;

  -- Consola, seeds, migraciones y service_role: solo aplican los CHECK.
  if private.is_privileged_caller() then
    return new;
  end if;

  if v_uid is null then
    raise exception '[BUSINESS_AUTH_REQUIRED] Debes iniciar sesión para registrar o editar un negocio.'
      using errcode = '42501';
  end if;

  select value into v_rules
  from public.app_config
  where key = 'business_registration_rules';

  v_rules := coalesce(v_rules, '{}'::jsonb);
  v_max_active := coalesce((v_rules ->> 'max_active_per_owner')::integer, 5);
  v_max_daily := coalesce((v_rules ->> 'max_submissions_per_day')::integer, 3);
  v_radius_m := coalesce((v_rules ->> 'location_radius_m')::integer, 60000);
  v_allowed_types := coalesce(
    array(select jsonb_array_elements_text(v_rules -> 'allowed_owner_types')),
    array['restaurant', 'hotel', 'service', 'handicraft', 'transport']
  );

  -- -------------------------------------------------------------------------
  -- UPDATE: dueño (o moderación administrativa desde moderate_business)
  -- -------------------------------------------------------------------------
  if tg_op = 'UPDATE' then
    if new.owner_id is distinct from old.owner_id
       or new.municipality_code is distinct from old.municipality_code
       or new.type is distinct from old.type
       or new.is_demo is distinct from old.is_demo
       or new.client_request_id is distinct from old.client_request_id
       or new.publication_consent_at is distinct from old.publication_consent_at
       or new.created_at is distinct from old.created_at then
      raise exception '[BUSINESS_PERMISSION_DENIED] No puedes modificar el dueño, municipio, tipo ni metadatos del negocio.'
        using errcode = '42501';
    end if;

    if new.status is distinct from old.status then
      if new.status = 'pending' then
        -- Reinicio a revisión (edición del dueño o re-moderación por fotos/platos).
        null;
      elsif public.is_admin() then
        if old.owner_id = v_uid then
          raise exception '[MODERATION_SELF_REVIEW] Un administrador no puede moderar su propio negocio.'
            using errcode = '42501';
        end if;
        return new;
      else
        raise exception '[BUSINESS_PERMISSION_DENIED] Solo un administrador puede aprobar o rechazar negocios.'
          using errcode = '42501';
      end if;
    elsif new.rejection_reason is distinct from old.rejection_reason
       or new.reviewed_at is distinct from old.reviewed_at
       or new.reviewed_by is distinct from old.reviewed_by then
      raise exception '[BUSINESS_PERMISSION_DENIED] Los campos de moderación solo los gestiona un administrador.'
        using errcode = '42501';
    end if;

    v_content_changed :=
      row(
        new.name, new.description_es, new.description_en, new.address,
        new.location::text, new.place_id, new.phone, new.whatsapp,
        new.whatsapp_consent_at, new.order_url, new.hours
      ) is distinct from row(
        old.name, old.description_es, old.description_en, old.address,
        old.location::text, old.place_id, old.phone, old.whatsapp,
        old.whatsapp_consent_at, old.order_url, old.hours
      );

    if not v_content_changed then
      -- Solo se permite el reinicio a `pending` (re-moderación por fotos/platos).
      if new.status = 'pending' and old.status <> 'pending' then
        new.rejection_reason := null;
        new.reviewed_at := null;
        new.reviewed_by := null;
      end if;
      return new;
    end if;

    -- Toda edición de contenido vuelve a revisión (incluida la que corrige un rechazo).
    new.status := 'pending';
    new.rejection_reason := null;
    new.reviewed_at := null;
    new.reviewed_by := null;

    -- Cambiar el número de WhatsApp exige un consentimiento renovado.
    if new.whatsapp is distinct from old.whatsapp
       and new.whatsapp is not null
       and new.whatsapp_consent_at is not distinct from old.whatsapp_consent_at then
      raise exception '[BUSINESS_WHATSAPP_CONSENT_REQUIRED] Cambiar el WhatsApp requiere un nuevo consentimiento explícito.'
        using errcode = '22023';
    end if;
  end if;

  -- -------------------------------------------------------------------------
  -- INSERT: valores fijados por el servidor, cupos y municipio piloto
  -- -------------------------------------------------------------------------
  if tg_op = 'INSERT' then
    if new.owner_id is not null and new.owner_id <> v_uid then
      raise exception '[BUSINESS_PERMISSION_DENIED] No puedes registrar negocios a nombre de otro usuario.'
        using errcode = '42501';
    end if;

    new.owner_id := v_uid;
    new.status := 'pending';
    new.is_demo := false;
    new.rejection_reason := null;
    new.reviewed_at := null;
    new.reviewed_by := null;
    new.created_at := now();
    new.updated_at := now();

    if new.publication_consent_at is null then
      raise exception '[BUSINESS_PUBLICATION_CONSENT_REQUIRED] Debes aceptar el consentimiento de publicación antes de enviar el negocio.'
        using errcode = '22023';
    end if;
    new.publication_consent_at := now();

    if not exists (
      select 1
      from public.municipalities m
      where m.code = new.municipality_code
        and m.is_pilot = true
    ) then
      raise exception '[BUSINESS_MUNICIPALITY_NOT_PILOT] El municipio "%" no está habilitado como piloto para registrar negocios.',
        new.municipality_code
        using errcode = '22023';
    end if;

    if not (new.type = any (v_allowed_types)) then
      raise exception '[BUSINESS_TYPE_NOT_ALLOWED] El tipo de negocio "%" no está permitido para registro ciudadano.',
        new.type
        using errcode = '22023';
    end if;

    -- Serializa envíos concurrentes del mismo dueño (doble clic / reintentos).
    perform pg_advisory_xact_lock(hashtextextended('vj16_business_owner:' || v_uid::text, 0));

    select count(*) into v_count
    from public.businesses b
    where b.owner_id = v_uid
      and b.status in ('pending', 'approved');

    if v_count >= v_max_active then
      raise exception '[BUSINESS_LIMIT_REACHED] Ya tienes % negocios activos o en revisión.', v_max_active
        using errcode = 'P0001';
    end if;

    select count(*) into v_count
    from public.businesses b
    where b.owner_id = v_uid
      and b.created_at >= now() - interval '24 hours';

    if v_count >= v_max_daily then
      raise exception '[BUSINESS_RATE_LIMITED] Alcanzaste el límite de % registros de negocio en 24 horas.', v_max_daily
        using errcode = 'P0001';
    end if;
  end if;

  -- -------------------------------------------------------------------------
  -- Validación de contenido (INSERT o UPDATE con cambios de contenido)
  -- -------------------------------------------------------------------------
  new.name := btrim(regexp_replace(coalesce(new.name, ''), '\s+', ' ', 'g'));
  if char_length(new.name) not between 3 and 120
     or new.name !~ '[[:alpha:]]'
     or new.name ~ '[[:cntrl:]<>]'
     or new.name ~* '^\[demo\]' then
    raise exception '[BUSINESS_INVALID_NAME] El nombre debe tener entre 3 y 120 caracteres, incluir letras y no contener etiquetas ni el prefijo [DEMO].'
      using errcode = '22023';
  end if;

  new.description_es := btrim(coalesce(new.description_es, ''));
  new.description_en := btrim(coalesce(new.description_en, ''));
  if new.description_en = '' then
    new.description_en := new.description_es;
  end if;

  if char_length(new.description_es) not between 20 and 1000
     or char_length(new.description_en) not between 20 and 1000
     or new.description_es ~ '<[^>]*>'
     or new.description_en ~ '<[^>]*>' then
    raise exception '[BUSINESS_INVALID_DESCRIPTION] La descripción (es/en) debe tener entre 20 y 1000 caracteres y no incluir etiquetas HTML.'
      using errcode = '22023';
  end if;

  new.address := nullif(btrim(regexp_replace(coalesce(new.address, ''), '\s+', ' ', 'g')), '');
  if new.address is null
     or char_length(new.address) not between 5 and 200
     or new.address ~ '[[:cntrl:]<>]' then
    raise exception '[BUSINESS_INVALID_ADDRESS] La dirección es obligatoria (5 a 200 caracteres) y debe ser responsable y verificable.'
      using errcode = '22023';
  end if;

  if new.location is null or not exists (
    select 1
    from public.municipality_zones z
    where z.municipality_code = new.municipality_code
      and z.is_active = true
      and extensions.ST_DWithin(
        new.location,
        extensions.ST_SetSRID(extensions.ST_MakePoint(z.center_lng, z.center_lat), 4326)::extensions.geography,
        v_radius_m
      )
  ) then
    raise exception '[BUSINESS_INVALID_LOCATION] La ubicación del negocio debe estar dentro del municipio piloto seleccionado.'
      using errcode = '22023';
  end if;

  new.phone := nullif(regexp_replace(coalesce(new.phone, ''), '[\s().-]', '', 'g'), '');
  new.whatsapp := nullif(regexp_replace(coalesce(new.whatsapp, ''), '[\s()+.-]', '', 'g'), '');

  if new.phone is null and new.whatsapp is null then
    raise exception '[BUSINESS_CONTACT_REQUIRED] Debes registrar al menos un teléfono o WhatsApp autorizado del negocio.'
      using errcode = '22023';
  end if;

  if new.phone is not null and new.phone !~ '^\+?[0-9]{7,15}$' then
    raise exception '[BUSINESS_INVALID_PHONE] El teléfono debe tener entre 7 y 15 dígitos.'
      using errcode = '22023';
  end if;

  if new.whatsapp is not null then
    if new.whatsapp !~ '^[1-9][0-9]{9,14}$' then
      raise exception '[BUSINESS_INVALID_WHATSAPP] El WhatsApp debe incluir el prefijo del país en formato internacional (ej. 573001234567).'
        using errcode = '22023';
    end if;

    if new.whatsapp_consent_at is null then
      raise exception '[BUSINESS_WHATSAPP_CONSENT_REQUIRED] Debes autorizar expresamente el uso del WhatsApp del negocio.'
        using errcode = '22023';
    end if;

    -- La marca de consentimiento la fija el servidor.
    new.whatsapp_consent_at := now();
  else
    new.whatsapp_consent_at := null;
  end if;

  new.order_url := nullif(btrim(coalesce(new.order_url, '')), '');
  if new.order_url is not null
     and (
       char_length(new.order_url) > 500
       or new.order_url !~ '^https://[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+(:[0-9]{2,5})?(/[^[:space:]<>"''`\\]*)?$'
     ) then
    raise exception '[BUSINESS_INVALID_ORDER_URL] El enlace de carta o pedidos debe ser una URL https válida y segura.'
      using errcode = '22023';
  end if;

  new.place_id := nullif(btrim(coalesce(new.place_id, '')), '');
  if new.place_id is not null and new.place_id !~ '^[A-Za-z0-9_-]{10,150}$' then
    raise exception '[BUSINESS_INVALID_PLACE_ID] El identificador de Google Places no tiene un formato válido.'
      using errcode = '22023';
  end if;

  if not public.is_valid_business_hours(new.hours) then
    raise exception '[BUSINESS_INVALID_HOURS] El horario debe usar días mon..sun con franjas HH:MM (máximo 3 por día).'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.businesses b
    where b.owner_id = v_uid
      and b.municipality_code = new.municipality_code
      and b.status <> 'rejected'
      and b.id <> new.id
      and lower(b.name) = lower(new.name)
  ) then
    raise exception '[BUSINESS_DUPLICATE] Ya registraste un negocio con el nombre "%" en este municipio.', new.name
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_business_rules() from public;

drop trigger if exists businesses_enforce_rules on public.businesses;
create trigger businesses_enforce_rules
  before insert or update on public.businesses
  for each row
  execute function private.enforce_business_rules();

-- ---------------------------------------------------------------------------
-- 5. Políticas RLS y privilegios de `public.businesses`
-- ---------------------------------------------------------------------------
drop policy if exists businesses_select_public_or_owner on public.businesses;
create policy businesses_select_public_or_owner
  on public.businesses
  for select
  to anon, authenticated
  using (
    (status = 'approved' and is_demo = false)
    or (
      coalesce(current_setting('role', true), '') <> 'anon'
      and (owner_id = auth.uid() or public.is_admin())
    )
  );

-- El dueño puede editar en cualquier estado (incluido `rejected`); el trigger
-- devuelve el negocio a `pending` y fija los campos de moderación.
drop policy if exists businesses_update_own on public.businesses;
create policy businesses_update_own
  on public.businesses
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists businesses_delete_own on public.businesses;
create policy businesses_delete_own
  on public.businesses
  for delete
  to authenticated
  using (owner_id = auth.uid());

revoke insert, update, delete on public.businesses from authenticated;

grant insert (
  owner_id,
  municipality_code,
  type,
  name,
  description_es,
  description_en,
  address,
  location,
  place_id,
  phone,
  whatsapp,
  whatsapp_consent_at,
  order_url,
  hours,
  client_request_id,
  publication_consent_at
) on public.businesses to authenticated;

grant update (
  name,
  description_es,
  description_en,
  address,
  location,
  place_id,
  phone,
  whatsapp,
  whatsapp_consent_at,
  order_url,
  hours
) on public.businesses to authenticated;

grant delete on public.businesses to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Platos destacados: límites de contenido
-- ---------------------------------------------------------------------------
alter table public.business_dishes
  drop constraint if exists business_dishes_name_check,
  drop constraint if exists business_dishes_price_range_check,
  drop constraint if exists business_dishes_description_check;

alter table public.business_dishes
  add constraint business_dishes_name_check
    check (char_length(btrim(name)) between 2 and 100 and name !~ '[[:cntrl:]<>]'),
  add constraint business_dishes_price_range_check
    check (price_cop between 500 and 20000000),
  add constraint business_dishes_description_check
    check (description is null or (char_length(description) <= 300 and description !~ '<[^>]*>'));

-- ---------------------------------------------------------------------------
-- 7. Fotos: metadatos verificados contra Storage y una sola portada
-- ---------------------------------------------------------------------------
alter table public.business_photos
  add column if not exists mime_type text,
  add column if not exists size_bytes bigint,
  add column if not exists created_at timestamptz not null default now();

alter table public.business_photos
  drop constraint if exists business_photos_storage_path_format_check,
  drop constraint if exists business_photos_mime_type_check;

alter table public.business_photos
  add constraint business_photos_storage_path_format_check
    check (
      storage_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp)$'
    ),
  add constraint business_photos_mime_type_check
    check (mime_type is null or mime_type in ('image/jpeg', 'image/png', 'image/webp'));

create unique index if not exists business_photos_single_cover_uidx
  on public.business_photos (business_id)
  where is_cover;

create unique index if not exists business_photos_storage_path_uidx
  on public.business_photos (storage_path);

create or replace function private.enforce_business_photo_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_object_mime text;
  v_object_size bigint;
  v_extension text;
  v_max_bytes bigint;
begin
  if private.is_privileged_caller() then
    return new;
  end if;

  select b.owner_id into v_owner
  from public.businesses b
  where b.id = new.business_id;

  if v_owner is null or v_owner <> auth.uid() then
    raise exception '[BUSINESS_PERMISSION_DENIED] Solo el dueño puede adjuntar fotos a este negocio.'
      using errcode = '42501';
  end if;

  if split_part(new.storage_path, '/', 1) <> v_owner::text
     or split_part(new.storage_path, '/', 2) <> new.business_id::text then
    raise exception '[BUSINESS_PHOTO_INVALID_PATH] La ruta de la foto debe ser {owner_id}/{business_id}/{archivo}.'
      using errcode = '22023';
  end if;

  select o.metadata ->> 'mimetype', (o.metadata ->> 'size')::bigint
    into v_object_mime, v_object_size
  from storage.objects o
  where o.bucket_id = 'business-media'
    and o.name = new.storage_path;

  if not found then
    raise exception '[BUSINESS_PHOTO_NOT_UPLOADED] El archivo "%" no existe en el almacenamiento del negocio.', new.storage_path
      using errcode = '22023';
  end if;

  v_extension := lower(substring(new.storage_path from '\.([A-Za-z0-9]+)$'));

  if v_object_mime is null
     or v_object_mime not in ('image/jpeg', 'image/png', 'image/webp')
     or (v_extension in ('jpg', 'jpeg') and v_object_mime <> 'image/jpeg')
     or (v_extension = 'png' and v_object_mime <> 'image/png')
     or (v_extension = 'webp' and v_object_mime <> 'image/webp') then
    raise exception '[BUSINESS_PHOTO_INVALID_MIME] El archivo no es una imagen JPEG, PNG o WebP coherente con su extensión.'
      using errcode = '22023';
  end if;

  select coalesce((value ->> 'max_photo_bytes')::bigint, 5242880) into v_max_bytes
  from public.app_config
  where key = 'business_registration_rules';

  if v_object_size is null or v_object_size > coalesce(v_max_bytes, 5242880) then
    raise exception '[BUSINESS_PHOTO_TOO_LARGE] La foto supera el tamaño máximo permitido.'
      using errcode = '22023';
  end if;

  new.mime_type := v_object_mime;
  new.size_bytes := v_object_size;
  return new;
end;
$$;

revoke all on function private.enforce_business_photo_rules() from public;

drop trigger if exists business_photos_enforce_rules on public.business_photos;
create trigger business_photos_enforce_rules
  before insert or update on public.business_photos
  for each row
  execute function private.enforce_business_photo_rules();

-- ---------------------------------------------------------------------------
-- 8. Re-moderación: cambios de fotos o platos devuelven el negocio a pending
-- ---------------------------------------------------------------------------
create or replace function private.requeue_business_after_media_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid := case when tg_op = 'DELETE' then old.business_id else new.business_id end;
begin
  if private.is_privileged_caller() then
    return null;
  end if;

  -- Borrados en cascada por eliminación del negocio: nada que re-moderar.
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 then
    return null;
  end if;

  update public.businesses
  set status = 'pending'
  where id = v_business_id
    and status <> 'pending';

  return null;
end;
$$;

revoke all on function private.requeue_business_after_media_change() from public;

drop trigger if exists business_photos_requeue on public.business_photos;
create trigger business_photos_requeue
  after insert or update or delete on public.business_photos
  for each row
  execute function private.requeue_business_after_media_change();

drop trigger if exists business_dishes_requeue on public.business_dishes;
create trigger business_dishes_requeue
  after insert or update or delete on public.business_dishes
  for each row
  execute function private.requeue_business_after_media_change();

-- ---------------------------------------------------------------------------
-- 9. Bucket privado `business-media` y políticas de Storage
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-media',
  'business-media',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.business_media_business_id(p_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp)$'
      then split_part(p_name, '/', 2)::uuid
    else null
  end;
$$;

create or replace function private.can_write_business_media(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_business_id uuid := private.business_media_business_id(p_name);
  v_max_photos integer;
  v_count integer;
begin
  if v_uid is null or v_business_id is null then
    return false;
  end if;

  if split_part(p_name, '/', 1) <> v_uid::text then
    return false;
  end if;

  if not exists (
    select 1
    from public.businesses b
    where b.id = v_business_id
      and b.owner_id = v_uid
      and b.is_demo = false
  ) then
    return false;
  end if;

  select coalesce((value ->> 'max_photos')::integer, 5) into v_max_photos
  from public.app_config
  where key = 'business_registration_rules';

  select count(*) into v_count
  from storage.objects o
  where o.bucket_id = 'business-media'
    and o.name like v_uid::text || '/' || v_business_id::text || '/%'
    and o.name <> p_name;

  return v_count < coalesce(v_max_photos, 5);
end;
$$;

create or replace function private.can_manage_business_media(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and split_part(p_name, '/', 1) = auth.uid()::text
    and exists (
      select 1
      from public.businesses b
      where b.id = private.business_media_business_id(p_name)
        and b.owner_id = auth.uid()
    );
$$;

create or replace function private.can_read_business_media(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.businesses b
    where b.id = private.business_media_business_id(p_name)
      and (
        (b.status = 'approved' and b.is_demo = false)
        or (
          coalesce(current_setting('role', true), '') <> 'anon'
          and (b.owner_id = auth.uid() or public.is_admin())
        )
      )
  );
$$;

revoke all on function private.business_media_business_id(text) from public;
revoke all on function private.can_write_business_media(text) from public;
revoke all on function private.can_manage_business_media(text) from public;
revoke all on function private.can_read_business_media(text) from public;
grant execute on function private.business_media_business_id(text) to anon, authenticated, service_role;
grant execute on function private.can_write_business_media(text) to authenticated, service_role;
grant execute on function private.can_manage_business_media(text) to authenticated, service_role;
grant execute on function private.can_read_business_media(text) to anon, authenticated, service_role;

drop policy if exists business_media_select on storage.objects;
create policy business_media_select
  on storage.objects
  for select
  to anon, authenticated
  using (
    bucket_id = 'business-media'
    and private.can_read_business_media(name)
  );

drop policy if exists business_media_insert_owner on storage.objects;
create policy business_media_insert_owner
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'business-media'
    and private.can_write_business_media(name)
  );

drop policy if exists business_media_update_owner on storage.objects;
create policy business_media_update_owner
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'business-media'
    and private.can_manage_business_media(name)
  )
  with check (
    bucket_id = 'business-media'
    and private.can_manage_business_media(name)
  );

drop policy if exists business_media_delete_owner on storage.objects;
create policy business_media_delete_owner
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'business-media'
    and (private.can_manage_business_media(name) or public.is_admin())
  );

-- ---------------------------------------------------------------------------
-- 10. RPC de registro en un solo paso (paso 4 «Revisión → Confirmar»)
-- ---------------------------------------------------------------------------
-- SECURITY INVOKER: se ejecuta con los privilegios y RLS del usuario, y el
-- trigger fija owner/status. Idempotente por `p_client_request_id`.
create or replace function public.submit_business(
  p_client_request_id uuid,
  p_type text,
  p_name text,
  p_description_es text,
  p_description_en text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone text default null,
  p_whatsapp text default null,
  p_whatsapp_consent boolean default false,
  p_publication_consent boolean default false,
  p_order_url text default null,
  p_hours jsonb default null,
  p_place_id text default null,
  p_dishes jsonb default '[]'::jsonb,
  p_municipality_code text default '20001'
)
returns public.businesses
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.businesses;
  v_inserted public.businesses;
  v_dish jsonb;
  v_index integer := 0;
  v_max_dishes integer;
begin
  if v_uid is null then
    raise exception '[BUSINESS_AUTH_REQUIRED] Debes iniciar sesión para registrar un negocio.'
      using errcode = '42501';
  end if;

  if p_client_request_id is null then
    raise exception '[BUSINESS_REQUEST_ID_REQUIRED] Falta el identificador de envío (client_request_id).'
      using errcode = '22023';
  end if;

  -- Reenvío del mismo formulario: devuelve el registro ya creado.
  select * into v_existing
  from public.businesses b
  where b.owner_id = v_uid
    and b.client_request_id = p_client_request_id;

  if found then
    return v_existing;
  end if;

  if not coalesce(p_publication_consent, false) then
    raise exception '[BUSINESS_PUBLICATION_CONSENT_REQUIRED] Debes aceptar el consentimiento de publicación antes de enviar el negocio.'
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(p_whatsapp, '')), '') is not null
     and not coalesce(p_whatsapp_consent, false) then
    raise exception '[BUSINESS_WHATSAPP_CONSENT_REQUIRED] Debes autorizar expresamente el uso del WhatsApp del negocio.'
      using errcode = '22023';
  end if;

  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception '[BUSINESS_INVALID_LOCATION] Debes seleccionar la ubicación del negocio en el mapa.'
      using errcode = '22023';
  end if;

  p_dishes := coalesce(p_dishes, '[]'::jsonb);
  if jsonb_typeof(p_dishes) <> 'array' then
    raise exception '[BUSINESS_INVALID_DISH] Los platos destacados deben enviarse como una lista.'
      using errcode = '22023';
  end if;

  select coalesce((value ->> 'max_dishes')::integer, 5) into v_max_dishes
  from public.app_config
  where key = 'business_registration_rules';

  if jsonb_array_length(p_dishes) > coalesce(v_max_dishes, 5) then
    raise exception '[BUSINESS_DISHES_LIMIT] Solo puedes destacar hasta % platos o servicios.', coalesce(v_max_dishes, 5)
      using errcode = '22023';
  end if;

  begin
    insert into public.businesses (
      owner_id,
      municipality_code,
      type,
      name,
      description_es,
      description_en,
      address,
      location,
      place_id,
      phone,
      whatsapp,
      whatsapp_consent_at,
      order_url,
      hours,
      client_request_id,
      publication_consent_at
    )
    values (
      v_uid,
      coalesce(nullif(btrim(p_municipality_code), ''), '20001'),
      btrim(coalesce(p_type, '')),
      p_name,
      p_description_es,
      p_description_en,
      p_address,
      extensions.ST_SetSRID(extensions.ST_MakePoint(p_longitude, p_latitude), 4326)::extensions.geography,
      p_place_id,
      p_phone,
      p_whatsapp,
      case when coalesce(p_whatsapp_consent, false) then now() end,
      p_order_url,
      p_hours,
      p_client_request_id,
      now()
    )
    returning * into v_inserted;
  exception
    when unique_violation then
      -- Clic múltiple concurrente con el mismo client_request_id.
      select * into v_existing
      from public.businesses b
      where b.owner_id = v_uid
        and b.client_request_id = p_client_request_id;

      if found then
        return v_existing;
      end if;
      raise;
  end;

  for v_dish in select value from jsonb_array_elements(p_dishes) loop
    if jsonb_typeof(v_dish) <> 'object'
       or nullif(btrim(coalesce(v_dish ->> 'name', '')), '') is null
       or coalesce(v_dish ->> 'price_cop', '') !~ '^[0-9]{1,9}$' then
      raise exception '[BUSINESS_INVALID_DISH] Cada plato requiere nombre y precio entero en COP.'
        using errcode = '22023';
    end if;

    insert into public.business_dishes (business_id, name, price_cop, description, sort_order)
    values (
      v_inserted.id,
      btrim(v_dish ->> 'name'),
      (v_dish ->> 'price_cop')::integer,
      nullif(btrim(coalesce(v_dish ->> 'description', '')), ''),
      v_index
    );

    v_index := v_index + 1;
  end loop;

  return v_inserted;
end;
$$;

comment on function public.submit_business(
  uuid, text, text, text, text, double precision, double precision, text, text, text,
  boolean, boolean, text, jsonb, text, jsonb, text
) is
  'VJ-16: registra un negocio en pending (fijado por el servidor) con platos destacados; idempotente por client_request_id.';

revoke all on function public.submit_business(
  uuid, text, text, text, text, double precision, double precision, text, text, text,
  boolean, boolean, text, jsonb, text, jsonb, text
) from public, anon;

grant execute on function public.submit_business(
  uuid, text, text, text, text, double precision, double precision, text, text, text,
  boolean, boolean, text, jsonb, text, jsonb, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Moderación administrativa (consola Supabase o admin autenticado)
-- ---------------------------------------------------------------------------
create or replace function public.moderate_business(
  p_business_id uuid,
  p_decision text,
  p_reason text default null
)
returns public.businesses
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_privileged boolean := private.is_privileged_caller();
  v_business public.businesses;
  v_decision text := lower(btrim(coalesce(p_decision, '')));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_updated public.businesses;
begin
  if not v_privileged and not public.is_admin() then
    raise exception '[MODERATION_FORBIDDEN] Solo un administrador autorizado puede moderar negocios.'
      using errcode = '42501';
  end if;

  if v_decision not in ('approved', 'rejected') then
    raise exception '[MODERATION_INVALID_DECISION] La decisión debe ser approved o rejected.'
      using errcode = '22023';
  end if;

  select * into v_business
  from public.businesses b
  where b.id = p_business_id
  for update;

  if not found then
    raise exception '[MODERATION_NOT_FOUND] El negocio % no existe.', p_business_id
      using errcode = 'P0002';
  end if;

  if not v_privileged and v_business.owner_id = auth.uid() then
    raise exception '[MODERATION_SELF_REVIEW] Un administrador no puede moderar su propio negocio.'
      using errcode = '42501';
  end if;

  -- Transiciones válidas: pending→approved, pending→rejected, approved→rejected (retiro).
  if not (
    (v_business.status = 'pending' and v_decision in ('approved', 'rejected'))
    or (v_business.status = 'approved' and v_decision = 'rejected')
  ) then
    raise exception '[MODERATION_INVALID_TRANSITION] No se puede pasar de % a %.', v_business.status, v_decision
      using errcode = '22023';
  end if;

  if v_decision = 'rejected' and char_length(coalesce(v_reason, '')) < 10 then
    raise exception '[MODERATION_REASON_REQUIRED] El rechazo requiere un motivo claro de al menos 10 caracteres.'
      using errcode = '22023';
  end if;

  update public.businesses
  set status = v_decision,
      rejection_reason = case when v_decision = 'rejected' then left(v_reason, 500) end,
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_business_id
  returning * into v_updated;

  return v_updated;
end;
$$;

comment on function public.moderate_business(uuid, text, text) is
  'VJ-16: moderación de negocios (approved/rejected con motivo) solo para admin_users o consola/service_role.';

revoke all on function public.moderate_business(uuid, text, text) from public, anon;
grant execute on function public.moderate_business(uuid, text, text) to authenticated, service_role;

create or replace function public.get_business_moderation_queue(p_limit integer default 50)
returns table (
  id uuid,
  name varchar,
  type varchar,
  municipality_code varchar,
  owner_id uuid,
  address varchar,
  has_whatsapp boolean,
  photos_count bigint,
  dishes_count bigint,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_privileged_caller() and not public.is_admin() then
    raise exception '[MODERATION_FORBIDDEN] Solo un administrador autorizado puede ver la cola de moderación.'
      using errcode = '42501';
  end if;

  return query
  select
    b.id,
    b.name,
    b.type,
    b.municipality_code,
    b.owner_id,
    b.address,
    b.whatsapp is not null,
    (select count(*) from public.business_photos p where p.business_id = b.id),
    (select count(*) from public.business_dishes d where d.business_id = b.id),
    b.created_at,
    b.updated_at
  from public.businesses b
  where b.status = 'pending'
    and b.is_demo = false
  order by b.updated_at asc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

revoke all on function public.get_business_moderation_queue(integer) from public, anon;
grant execute on function public.get_business_moderation_queue(integer) to authenticated, service_role;

-- Objetos de Storage huérfanos (subidas sin fila en business_photos o de
-- negocios eliminados). Se borran por la API de Storage: el trigger
-- `storage.protect_objects_delete` impide el borrado SQL directo.
create or replace function public.list_orphan_business_media(p_min_age interval default interval '24 hours')
returns table (
  object_name text,
  created_at timestamptz,
  reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_privileged_caller() and not public.is_admin() then
    raise exception '[MODERATION_FORBIDDEN] Solo un administrador autorizado puede auditar archivos huérfanos.'
      using errcode = '42501';
  end if;

  return query
  select
    o.name,
    o.created_at,
    case
      when not exists (
        select 1 from public.businesses b
        where b.id = private.business_media_business_id(o.name)
      ) then 'business_deleted'
      else 'not_linked_to_business_photos'
    end
  from storage.objects o
  where o.bucket_id = 'business-media'
    and o.created_at < now() - coalesce(p_min_age, interval '24 hours')
    and not exists (
      select 1 from public.business_photos p where p.storage_path = o.name
    )
  order by o.created_at asc;
end;
$$;

revoke all on function public.list_orphan_business_media(interval) from public, anon;
grant execute on function public.list_orphan_business_media(interval) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 12. Cierre del hueco de `register_business_on_map` (VJ-12)
-- ---------------------------------------------------------------------------
-- Uso exclusivo de consola/service_role para cargar puntos institucionales.
-- El ciudadano registra con `public.submit_business(...)`.
create or replace function public.register_business_on_map(
  p_name varchar(150),
  p_type varchar(50),
  p_description_es text,
  p_description_en text default null,
  p_latitude double precision default 10.4742,
  p_longitude double precision default -73.2436,
  p_address varchar(200) default null,
  p_phone varchar(20) default null,
  p_whatsapp varchar(20) default null,
  p_municipality_code varchar(5) default '20001',
  p_approve_immediately boolean default false
)
returns public.businesses
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_inserted public.businesses;
  v_whatsapp text := nullif(regexp_replace(coalesce(p_whatsapp, ''), '[\s()+.-]', '', 'g'), '');
begin
  if not private.is_privileged_caller() then
    raise exception '[BUSINESS_PERMISSION_DENIED] register_business_on_map es solo para consola/service_role. Usa submit_business.'
      using errcode = '42501';
  end if;

  if p_latitude < -4.5 or p_latitude > 13.5 or p_longitude < -82.0 or p_longitude > -66.0 then
    raise exception '[BUSINESS_INVALID_LOCATION] Las coordenadas (%, %) están fuera del territorio colombiano.',
      p_latitude, p_longitude
      using errcode = '22023';
  end if;

  insert into public.businesses (
    owner_id,
    municipality_code,
    type,
    name,
    description_es,
    description_en,
    address,
    location,
    phone,
    whatsapp,
    whatsapp_consent_at,
    publication_consent_at,
    status,
    reviewed_at,
    is_demo
  )
  values (
    null,
    coalesce(nullif(btrim(p_municipality_code), ''), '20001'),
    btrim(p_type),
    btrim(p_name),
    btrim(p_description_es),
    coalesce(nullif(btrim(p_description_en), ''), btrim(p_description_es)),
    nullif(btrim(coalesce(p_address, '')), ''),
    extensions.ST_SetSRID(extensions.ST_MakePoint(p_longitude, p_latitude), 4326)::extensions.geography,
    nullif(regexp_replace(coalesce(p_phone, ''), '[\s().-]', '', 'g'), ''),
    v_whatsapp,
    case when v_whatsapp is not null then now() end,
    now(),
    case when p_approve_immediately then 'approved' else 'pending' end,
    case when p_approve_immediately then now() end,
    false
  )
  returning * into v_inserted;

  return v_inserted;
end;
$$;

revoke all on function public.register_business_on_map(
  varchar, varchar, text, text, double precision, double precision, varchar, varchar, varchar, varchar, boolean
) from public, anon, authenticated;

grant execute on function public.register_business_on_map(
  varchar, varchar, text, text, double precision, double precision, varchar, varchar, varchar, varchar, boolean
) to service_role;
