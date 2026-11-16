-- VJ-16: publicación directa por el dueño, sin aprobación previa.
-- submit_business prepara un registro privado para poder adjuntar las fotos.
-- publish_business finaliza el mismo envío. pending es preparación técnica;
-- approved representa publicado por compatibilidad con las RPC existentes.
-- Las filas previas conservan su estado hasta una acción explícita del dueño.

begin;
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
      if new.status = 'approved' and old.status = 'pending'
         and old.owner_id = v_uid
         and new.rejection_reason is null
         and new.reviewed_at is null and new.reviewed_by is null then
        -- El cliente carece de permiso de columna; publica mediante publish_business.
        -- approved conserva compatibilidad con catálogo, mapa y Storage.
        return new;
      elsif new.status = 'pending' then
        -- Preparación de registros históricos mediante operaciones administrativas.
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
      -- Conserva la compatibilidad con el reinicio administrativo de un registro.
      if new.status = 'pending' and old.status <> 'pending' then
        new.rejection_reason := null;
        new.reviewed_at := null;
        new.reviewed_by := null;
      end if;
      return new;
    end if;

    -- Una edición conserva la publicación. Un rechazo previo se prepara de nuevo.
    new.status := case when old.status = 'approved' then 'approved' else 'pending' end;
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
      raise exception '[BUSINESS_LIMIT_REACHED] Ya tienes % negocios activos o en preparación.', v_max_active
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

-- Editar fotos o platos conserva el estado de publicación.
drop trigger if exists business_photos_requeue on public.business_photos;
drop trigger if exists business_dishes_requeue on public.business_dishes;

create or replace function public.publish_business(
  p_business_id uuid,
  p_expected_photo_count integer
)
returns public.businesses
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business public.businesses;
  v_photo_count integer;
begin
  if auth.uid() is null then
    raise exception '[BUSINESS_AUTH_REQUIRED] Debes iniciar sesión para publicar.'
      using errcode = '42501';
  end if;

  if p_expected_photo_count is null or p_expected_photo_count not between 0 and 5 then
    raise exception '[BUSINESS_PHOTOS_INVALID_COUNT] La cantidad de fotos debe estar entre 0 y 5.'
      using errcode = '22023';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id and owner_id = auth.uid() and is_demo = false
  for update;

  if not found then
    raise exception '[BUSINESS_NOT_FOUND] No se encontró un negocio propio para publicar.'
      using errcode = 'P0002';
  end if;

  -- Reintentos después de una respuesta perdida devuelven la misma publicación.
  if v_business.status = 'approved' then
    return v_business;
  end if;

  if v_business.status <> 'pending' then
    raise exception '[BUSINESS_INVALID_STATE] Corrige los datos antes de publicar nuevamente.'
      using errcode = '22023';
  end if;

  if v_business.publication_consent_at is null then
    raise exception '[BUSINESS_PUBLICATION_CONSENT_REQUIRED] Debes aceptar la publicación.'
      using errcode = '22023';
  end if;

  -- Mantiene estables las fotos vinculadas y sus objetos durante la publicación.
  -- La fila padre bloqueada también serializa nuevas asociaciones por su FK.
  perform p.id
  from public.business_photos p
  join storage.objects o
    on o.bucket_id = 'business-media' and o.name = p.storage_path
  where p.business_id = p_business_id
  order by p.id
  for share of p, o;

  select count(*) into v_photo_count
  from public.business_photos p
  join storage.objects o
    on o.bucket_id = 'business-media' and o.name = p.storage_path
  where p.business_id = p_business_id;

  if v_photo_count <> p_expected_photo_count
     or v_photo_count <> (select count(*) from public.business_photos where business_id = p_business_id) then
    raise exception '[BUSINESS_PHOTOS_INCOMPLETE] Completa la subida de las fotos antes de publicar.'
      using errcode = '22023';
  end if;

  update public.businesses
  set status = 'approved', rejection_reason = null, reviewed_at = null, reviewed_by = null
  where id = p_business_id
  returning * into v_business;

  return v_business;
end;
$$;

revoke all on function public.publish_business(uuid, integer) from public, anon;
grant execute on function public.publish_business(uuid, integer) to authenticated;

comment on function public.publish_business(uuid, integer) is
  'Publica directamente un registro propio tras completar sus fotos. Idempotente; sin aprobación administrativa.';
comment on column public.businesses.status is
  'pending: preparación privada; approved: publicado; rejected: retirado. Valores conservados para compatibilidad.';
comment on table public.businesses is
  'Negocios de usuarios con publicación directa mediante submit_business y publish_business.';

commit;
