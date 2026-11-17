-- ============================================================================
-- Vía Justa MVP · Idempotencia y reconciliación segura de ediciones (VJ-17)
-- ============================================================================
-- Registra cada intento de edición (`p_edit_request_id`) en la misma
-- transacción de `update_own_business` y serializa mediante bloqueo de fila
-- (`FOR UPDATE` sobre `public.businesses`) la verificación/aborto en
-- `reconcile_business_edit_attempt`.
-- Así, tras un corte de conexión:
--   1. Si la edición previa seguía en curso en Postgres, la reconciliación
--      espera a que termine y lee su estado real (`committed` o no).
--   2. Si nunca confirmó, la marca como `aborted` bajo bloqueo exclusivo; un
--      retraso de red de esa misma solicitud no podrá confirmar después ni
--      referenciar fotos que el cliente pase a limpiar.
--   3. Solo devuelve `deletable_photo_paths` una vez garantizado el `aborted`.
-- ============================================================================

begin;

create table if not exists public.business_edit_attempts (
  edit_request_id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('committed', 'aborted')),
  removed_photo_paths text[] not null default array[]::text[],
  created_at timestamptz not null default now()
);

create index if not exists business_edit_attempts_business_idx
  on public.business_edit_attempts (business_id, created_at desc);

alter table public.business_edit_attempts enable row level security;

drop policy if exists business_edit_attempts_select_own on public.business_edit_attempts;
create policy business_edit_attempts_select_own
  on public.business_edit_attempts
  for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists business_edit_attempts_insert_own on public.business_edit_attempts;
create policy business_edit_attempts_insert_own
  on public.business_edit_attempts
  for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.businesses b
      where b.id = business_edit_attempts.business_id
        and b.owner_id = auth.uid()
        and b.is_demo = false
    )
  );

revoke all on public.business_edit_attempts from public, anon, authenticated;
grant select, insert on public.business_edit_attempts to authenticated;
grant all on public.business_edit_attempts to service_role;

drop function if exists public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb
);

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
  p_photos jsonb default '[]'::jsonb,
  p_edit_request_id uuid default null
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
  v_attempt public.business_edit_attempts;
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

  if p_edit_request_id is not null then
    select * into v_attempt
    from public.business_edit_attempts a
    where a.edit_request_id = p_edit_request_id
      and a.business_id = p_business_id
      and a.owner_id = v_uid;

    if found then
      if v_attempt.status = 'committed' then
        return jsonb_build_object(
          'id', v_existing.id,
          'status', v_existing.status,
          'edit_request_id', p_edit_request_id,
          'edit_status', 'committed',
          'removed_photo_paths', to_jsonb(v_attempt.removed_photo_paths)
        );
      end if;

      raise exception '[BUSINESS_EDIT_ABORTED] Esta edición fue abortada tras una reconexión previa; inicia un nuevo intento.'
        using errcode = '40001';
    end if;
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

  if p_edit_request_id is not null then
    insert into public.business_edit_attempts (
      edit_request_id,
      business_id,
      owner_id,
      status,
      removed_photo_paths
    )
    values (
      p_edit_request_id,
      p_business_id,
      v_uid,
      'committed',
      v_removed_paths
    )
    on conflict (edit_request_id) do nothing;
  end if;

  return jsonb_build_object(
    'id', v_updated.id,
    'status', v_updated.status,
    'edit_request_id', p_edit_request_id,
    'edit_status', 'committed',
    'removed_photo_paths', to_jsonb(v_removed_paths)
  );
end;
$$;

revoke all on function public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb, uuid
) from public, anon;

grant execute on function public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb, uuid
) to authenticated, service_role;

comment on function public.update_own_business(
  uuid, text, text, text, double precision, double precision, text, text, text, boolean, text, jsonb, text, jsonb, jsonb, uuid
) is
  'VJ-17: actualiza en una única transacción datos, platos y referencias de fotos de un negocio propio con idempotencia opcional por p_edit_request_id.';

create or replace function public.reconcile_business_edit_attempt(
  p_business_id uuid,
  p_edit_request_id uuid,
  p_candidate_photo_paths text[] default array[]::text[]
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_business public.businesses;
  v_attempt public.business_edit_attempts;
  v_referenced_paths text[] := array[]::text[];
  v_deletable_paths text[] := array[]::text[];
begin
  if v_uid is null then
    raise exception '[BUSINESS_AUTH_REQUIRED] Debes iniciar sesión para reconciliar una edición.'
      using errcode = '42501';
  end if;

  if p_business_id is null or p_edit_request_id is null then
    raise exception '[BUSINESS_NOT_FOUND] Faltan identificadores para reconciliar la edición.'
      using errcode = 'P0002';
  end if;

  -- Serializa contra cualquier ejecución en curso de `update_own_business` sobre el mismo negocio.
  select * into v_business
  from public.businesses b
  where b.id = p_business_id
    and b.owner_id = v_uid
    and b.is_demo = false
  for update;

  if not found then
    raise exception '[BUSINESS_NOT_FOUND] No se encontró el negocio a reconciliar.'
      using errcode = 'P0002';
  end if;

  select * into v_attempt
  from public.business_edit_attempts a
  where a.edit_request_id = p_edit_request_id
    and a.business_id = p_business_id
    and a.owner_id = v_uid;

  if found and v_attempt.status = 'committed' then
    return jsonb_build_object(
      'business_id', p_business_id,
      'edit_request_id', p_edit_request_id,
      'edit_status', 'committed',
      'removed_photo_paths', to_jsonb(v_attempt.removed_photo_paths),
      'deletable_photo_paths', '[]'::jsonb
    );
  end if;

  insert into public.business_edit_attempts (
    edit_request_id,
    business_id,
    owner_id,
    status
  )
  values (
    p_edit_request_id,
    p_business_id,
    v_uid,
    'aborted'
  )
  on conflict (edit_request_id) do nothing;

  select coalesce(array_agg(p.storage_path), array[]::text[])
  into v_referenced_paths
  from public.business_photos p
  where p.business_id = p_business_id;

  select coalesce(array_agg(candidate), array[]::text[])
  into v_deletable_paths
  from unnest(coalesce(p_candidate_photo_paths, array[]::text[])) as candidate
  where nullif(btrim(candidate), '') is not null
    and not (candidate = any(v_referenced_paths));

  return jsonb_build_object(
    'business_id', p_business_id,
    'edit_request_id', p_edit_request_id,
    'edit_status', 'aborted',
    'removed_photo_paths', '[]'::jsonb,
    'deletable_photo_paths', to_jsonb(v_deletable_paths)
  );
end;
$$;

revoke all on function public.reconcile_business_edit_attempt(uuid, uuid, text[]) from public, anon;
grant execute on function public.reconcile_business_edit_attempt(uuid, uuid, text[]) to authenticated, service_role;

comment on function public.reconcile_business_edit_attempt(uuid, uuid, text[]) is
  'VJ-17: confirma en servidor bajo bloqueo exclusivo si p_edit_request_id quedó committed o lo marca aborted antes de autorizar el borrado de fotos huérfanas.';

commit;
