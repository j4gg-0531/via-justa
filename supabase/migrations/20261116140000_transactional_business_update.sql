-- ============================================================================
-- Vía Justa MVP · VJ-17 · Edición transaccional atómica de negocios propios
-- ============================================================================
-- Permite actualizar datos, platos destacados y referencias de fotos en una
-- única transacción SQL (`public.update_own_business`). Las fotos nuevas se
-- suben previamente a rutas nuevas; si la transacción falla, toda la ficha
-- publicada (datos, platos y fotos anteriores) permanece intacta. Tras el éxito,
-- devuelve las rutas antiguas desplazadas para limpiarlas de Storage.
-- ============================================================================

begin;

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
  v_status text;
  v_max_photos integer;
  v_count integer;
  v_cap integer;
begin
  if v_uid is null or v_business_id is null then
    return false;
  end if;

  if split_part(p_name, '/', 1) <> v_uid::text then
    return false;
  end if;

  select b.status into v_status
  from public.businesses b
  where b.id = v_business_id
    and b.owner_id = v_uid
    and b.is_demo = false;

  if not found then
    return false;
  end if;

  select coalesce((value ->> 'max_photos')::integer, 5) into v_max_photos
  from public.app_config
  where key = 'business_registration_rules';

  v_max_photos := coalesce(v_max_photos, 5);
  -- Durante la edición de un negocio ya publicado, permite preparar rutas
  -- nuevas antes de reemplazar referencias y limpiar las fotos anteriores.
  v_cap := case when v_status = 'approved' then v_max_photos * 2 else v_max_photos end;

  select count(*) into v_count
  from storage.objects o
  where o.bucket_id = 'business-media'
    and o.name like v_uid::text || '/' || v_business_id::text || '/%'
    and o.name <> p_name;

  return v_count < v_cap;
end;
$$;

revoke all on function private.can_write_business_media(text) from public;
grant execute on function private.can_write_business_media(text) to authenticated, service_role;

create or replace function public.update_own_business(
  p_business_id uuid,
  p_name text,
  p_description_es text,
  p_description_en text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone text default null,
  p_whatsapp text default null,
  p_whatsapp_consent boolean default false,
  p_order_url text default null,
  p_hours jsonb default null,
  p_place_id text default null,
  p_dishes jsonb default '[]'::jsonb,
  p_photos jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.businesses;
  v_updated public.businesses;
  v_max_dishes integer;
  v_max_photos integer;
  v_clean_whatsapp text := nullif(regexp_replace(coalesce(p_whatsapp, ''), '[\s()+.-]', '', 'g'), '');
  v_wa_consent_at timestamptz;
  v_dish jsonb;
  v_photo jsonb;
  v_index integer := 0;
  v_old_paths text[] := array[]::text[];
  v_new_paths text[] := array[]::text[];
  v_removed_paths text[] := array[]::text[];
  v_photo_path text;
  v_photo_pos integer;
  v_photo_cover boolean;
begin
  if v_uid is null then
    raise exception '[BUSINESS_AUTH_REQUIRED] Debes iniciar sesión para editar un negocio.'
      using errcode = '42501';
  end if;

  if p_business_id is null then
    raise exception '[BUSINESS_NOT_FOUND] Falta el identificador del negocio a editar.'
      using errcode = 'P0002';
  end if;

  select * into v_existing
  from public.businesses b
  where b.id = p_business_id
    and b.owner_id = v_uid
    and b.is_demo = false
  for update;

  if not found then
    raise exception '[BUSINESS_NOT_FOUND] No se encontró un negocio propio editable.'
      using errcode = 'P0002';
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

  p_photos := coalesce(p_photos, '[]'::jsonb);
  if jsonb_typeof(p_photos) <> 'array' then
    raise exception '[BUSINESS_PHOTOS_INVALID_COUNT] Las fotos deben enviarse como una lista.'
      using errcode = '22023';
  end if;

  select
    coalesce((value ->> 'max_dishes')::integer, 5),
    coalesce((value ->> 'max_photos')::integer, 5)
  into v_max_dishes, v_max_photos
  from public.app_config
  where key = 'business_registration_rules';

  if jsonb_array_length(p_dishes) > coalesce(v_max_dishes, 5) then
    raise exception '[BUSINESS_DISHES_LIMIT] Solo puedes destacar hasta % platos o servicios.', coalesce(v_max_dishes, 5)
      using errcode = '22023';
  end if;

  if jsonb_array_length(p_photos) > coalesce(v_max_photos, 5) then
    raise exception '[BUSINESS_PHOTOS_INVALID_COUNT] Solo puedes publicar hasta % fotos.', coalesce(v_max_photos, 5)
      using errcode = '22023';
  end if;

  if v_clean_whatsapp is not null and not coalesce(p_whatsapp_consent, false) then
    raise exception '[BUSINESS_WHATSAPP_CONSENT_REQUIRED] Debes autorizar expresamente el uso del WhatsApp del negocio.'
      using errcode = '22023';
  end if;

  v_wa_consent_at := case
    when v_clean_whatsapp is null then null
    when v_clean_whatsapp is distinct from v_existing.whatsapp then now()
    else coalesce(v_existing.whatsapp_consent_at, now())
  end;

  update public.businesses
  set
    name = p_name,
    description_es = p_description_es,
    description_en = p_description_en,
    address = p_address,
    location = extensions.ST_SetSRID(extensions.ST_MakePoint(p_longitude, p_latitude), 4326)::extensions.geography,
    place_id = p_place_id,
    phone = nullif(regexp_replace(coalesce(p_phone, ''), '[\s().-]', '', 'g'), ''),
    whatsapp = v_clean_whatsapp,
    whatsapp_consent_at = v_wa_consent_at,
    order_url = nullif(btrim(coalesce(p_order_url, '')), ''),
    hours = p_hours
  where id = p_business_id
    and owner_id = v_uid
  returning * into v_updated;

  delete from public.business_dishes
  where business_id = p_business_id;

  v_index := 0;
  for v_dish in select value from jsonb_array_elements(p_dishes) loop
    if jsonb_typeof(v_dish) <> 'object'
       or nullif(btrim(coalesce(v_dish ->> 'name', '')), '') is null
       or coalesce(v_dish ->> 'price_cop', '') !~ '^[0-9]+$' then
      raise exception '[BUSINESS_INVALID_DISH] Cada plato destacado requiere nombre y precio entero en COP.'
        using errcode = '22023';
    end if;

    insert into public.business_dishes (
      business_id,
      name,
      price_cop,
      description,
      sort_order
    )
    values (
      p_business_id,
      btrim(v_dish ->> 'name'),
      (v_dish ->> 'price_cop')::integer,
      nullif(btrim(coalesce(v_dish ->> 'description', '')), ''),
      v_index
    );

    v_index := v_index + 1;
  end loop;

  select coalesce(array_agg(p.storage_path), array[]::text[])
  into v_old_paths
  from public.business_photos p
  where p.business_id = p_business_id;

  delete from public.business_photos
  where business_id = p_business_id;

  v_index := 0;
  for v_photo in select value from jsonb_array_elements(p_photos) loop
    if jsonb_typeof(v_photo) <> 'object' then
      raise exception '[BUSINESS_PHOTO_INVALID_PATH] Cada foto debe incluir una ruta válida.'
        using errcode = '22023';
    end if;

    v_photo_path := btrim(coalesce(v_photo ->> 'storage_path', ''));
    if v_photo_path = '' then
      raise exception '[BUSINESS_PHOTO_INVALID_PATH] Falta la ruta de almacenamiento de la foto.'
        using errcode = '22023';
    end if;

    v_photo_pos := coalesce((v_photo ->> 'position')::integer, v_index);
    v_photo_cover := coalesce((v_photo ->> 'is_cover')::boolean, v_index = 0);

    insert into public.business_photos (
      business_id,
      storage_path,
      position,
      is_cover
    )
    values (
      p_business_id,
      v_photo_path,
      v_photo_pos,
      v_photo_cover
    );

    v_new_paths := array_append(v_new_paths, v_photo_path);
    v_index := v_index + 1;
  end loop;

  select coalesce(array_agg(old_path), array[]::text[])
  into v_removed_paths
  from unnest(v_old_paths) as old_path
  where not (old_path = any(v_new_paths));

  return jsonb_build_object(
    'id', v_updated.id,
    'status', v_updated.status,
    'removed_photo_paths', to_jsonb(v_removed_paths)
  );
end;
$$;

revoke all on function public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb
) from public, anon;

grant execute on function public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb
) to authenticated, service_role;

comment on function public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb
) is
  'VJ-17: actualiza en una única transacción datos, platos y referencias de fotos de un negocio propio conservando su estado de publicación y devolviendo rutas anteriores removidas.';

commit;
