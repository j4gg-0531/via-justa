-- ============================================================================
-- Vía Justa MVP · Valoraciones con estrellas para negocios publicados
-- ============================================================================
-- Reglas de dominio:
--   1. Cada cuenta autenticada puede dar una valoración entera de 1 a 5
--      estrellas por negocio publicado (`status = 'approved'`, `is_demo = false`)
--      y modificar su propio voto sin duplicar registros.
--   2. El dueño no puede valorar su propio comercio (`[BUSINESS_RATING_SELF_FORBIDDEN]`).
--   3. Supabase calcula el promedio redondeado a 1 decimal (`rating_average`)
--      y la cantidad de votos (`rating_count`). Un negocio sin votos devuelve
--      `rating_count = 0` y `rating_average = null` («Sin valoraciones»).
--   4. Primera versión solo con estrellas (sin comentarios escritos).
-- ============================================================================

begin;

create table if not exists public.business_ratings (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  stars smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_ratings_pkey primary key (business_id, user_id),
  constraint business_ratings_stars_check check (stars between 1 and 5)
);

create index if not exists business_ratings_business_idx
  on public.business_ratings (business_id);

alter table public.business_ratings enable row level security;

create or replace function private.enforce_business_rating_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_business public.businesses;
  v_actor uuid;
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := now();
  else
    new.updated_at := now();
  end if;

  if not private.is_privileged_caller() then
    if v_uid is null then
      raise exception '[BUSINESS_RATING_AUTH_REQUIRED] Debes iniciar sesión para valorar un negocio.'
        using errcode = '42501';
    end if;

    if tg_op = 'INSERT' then
      if new.user_id is not null and new.user_id <> v_uid then
        raise exception '[BUSINESS_RATING_PERMISSION_DENIED] No puedes registrar valoraciones a nombre de otra cuenta.'
          using errcode = '42501';
      end if;
      new.user_id := v_uid;
    elsif tg_op = 'UPDATE' then
      if new.user_id is distinct from old.user_id
         or new.business_id is distinct from old.business_id
         or new.created_at is distinct from old.created_at then
        raise exception '[BUSINESS_RATING_PERMISSION_DENIED] Solo puedes modificar la puntuación de tu propia valoración.'
          using errcode = '42501';
      end if;
    end if;
  end if;

  if new.stars is null or new.stars not between 1 and 5 then
    raise exception '[BUSINESS_RATING_INVALID_STARS] La valoración debe ser un número entero entre 1 y 5 estrellas.'
      using errcode = '22023';
  end if;

  select * into v_business
  from public.businesses b
  where b.id = new.business_id;

  if not found or v_business.status <> 'approved' or v_business.is_demo then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no admite valoraciones.'
      using errcode = 'P0002';
  end if;

  v_actor := coalesce(v_uid, new.user_id);
  if v_business.owner_id is not null and v_business.owner_id = v_actor then
    raise exception '[BUSINESS_RATING_SELF_FORBIDDEN] El dueño no puede valorar su propio negocio.'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_business_rating_rules() from public, anon, authenticated;

drop trigger if exists enforce_business_rating_rules_trigger on public.business_ratings;
create trigger enforce_business_rating_rules_trigger
  before insert or update on public.business_ratings
  for each row
  execute function private.enforce_business_rating_rules();

drop policy if exists business_ratings_select_public on public.business_ratings;
create policy business_ratings_select_public
  on public.business_ratings
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.businesses b
      where b.id = business_ratings.business_id
        and b.status = 'approved'
        and b.is_demo = false
    )
  );

drop policy if exists business_ratings_insert_own on public.business_ratings;
create policy business_ratings_insert_own
  on public.business_ratings
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists business_ratings_update_own on public.business_ratings;
create policy business_ratings_update_own
  on public.business_ratings
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists business_ratings_delete_own on public.business_ratings;
create policy business_ratings_delete_own
  on public.business_ratings
  for delete
  to authenticated
  using (user_id = auth.uid());

revoke all on public.business_ratings from public, anon, authenticated;
grant select on public.business_ratings to anon, authenticated, service_role;
grant insert (business_id, user_id, stars), update (stars), delete on public.business_ratings to authenticated;
grant all on public.business_ratings to service_role;

create or replace function public.rate_business(
  p_business_id uuid,
  p_stars integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_avg double precision;
  v_count integer;
begin
  if v_uid is null then
    raise exception '[BUSINESS_RATING_AUTH_REQUIRED] Debes iniciar sesión para valorar un negocio.'
      using errcode = '42501';
  end if;

  if p_stars is null or p_stars not between 1 and 5 then
    raise exception '[BUSINESS_RATING_INVALID_STARS] La valoración debe ser un número entero entre 1 y 5 estrellas.'
      using errcode = '22023';
  end if;

  insert into public.business_ratings (business_id, user_id, stars)
  values (p_business_id, v_uid, p_stars::smallint)
  on conflict (business_id, user_id)
  do update set
    stars = excluded.stars,
    updated_at = now();

  select
    case
      when count(*) > 0 then round(avg(r.stars)::numeric, 1)::double precision
      else null
    end,
    count(*)::integer
  into v_avg, v_count
  from public.business_ratings r
  where r.business_id = p_business_id;

  return jsonb_build_object(
    'business_id', p_business_id,
    'my_rating', p_stars,
    'rating_average', v_avg,
    'rating_count', coalesce(v_count, 0)
  );
end;
$$;

revoke all on function public.rate_business(uuid, integer) from public, anon;
grant execute on function public.rate_business(uuid, integer) to authenticated, service_role;

comment on table public.business_ratings is
  'Valoraciones de 1 a 5 estrellas por cuenta autenticada sobre negocios publicados (sin comentarios escritos).';
comment on function public.rate_business(uuid, integer) is
  'Registra o actualiza la valoración (1..5 estrellas) del usuario autenticado sobre un negocio ajeno y devuelve el nuevo promedio y conteo.';

-- Actualiza get_business_detail para incluir rating_average, rating_count, my_rating e is_owner.
create or replace function public.get_business_detail(
  p_business_id uuid,
  p_locale text default 'es',
  p_include_demo boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_b public.businesses;
  v_uid uuid := auth.uid();
  v_is_anon boolean := coalesce(current_setting('role', true), '') = 'anon';
  v_can_view_unapproved boolean := false;
  v_req_locale text := case
    when lower(btrim(coalesce(p_locale, 'es'))) like 'en%' then 'en'
    else 'es'
  end;
  v_resolved_locale text;
  v_lat double precision;
  v_lng double precision;
  v_has_wa boolean;
  v_wa_url text;
  v_tel_url text;
  v_maps_url text;
  v_photos jsonb;
  v_dishes jsonb;
  v_rating_avg double precision;
  v_rating_count integer := 0;
  v_my_rating integer;
begin
  select * into v_b
  from public.businesses b
  where b.id = p_business_id;

  if not found then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no está disponible.'
      using errcode = 'P0002';
  end if;

  if not v_is_anon then
    v_can_view_unapproved := (
      private.is_privileged_caller()
      or v_b.owner_id = v_uid
      or public.is_admin()
    );
  end if;

  if v_b.status <> 'approved' and not v_can_view_unapproved then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no está disponible.'
      using errcode = 'P0002';
  end if;

  if v_b.is_demo and not p_include_demo and not v_can_view_unapproved then
    raise exception '[BUSINESS_NOT_FOUND] El negocio solicitado no existe o no está disponible.'
      using errcode = 'P0002';
  end if;

  v_resolved_locale := case
    when v_req_locale = 'en' and length(btrim(coalesce(v_b.description_en, ''))) > 0 then 'en'
    else 'es'
  end;

  v_lat := round(extensions.ST_Y(v_b.location::extensions.geometry)::numeric, 6)::double precision;
  v_lng := round(extensions.ST_X(v_b.location::extensions.geometry)::numeric, 6)::double precision;

  v_has_wa := (v_b.whatsapp is not null and v_b.whatsapp_consent_at is not null);
  v_wa_url := case
    when v_has_wa then public.build_business_whatsapp_url(v_b.whatsapp, v_b.name, v_req_locale)
    else null
  end;
  v_tel_url := case
    when v_b.phone is not null and v_b.phone ~ '^\+?[0-9]{7,15}$' then 'tel:' || v_b.phone
    else null
  end;
  v_maps_url := public.build_business_maps_url(v_lat, v_lng, v_b.place_id);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'storage_path', p.storage_path,
        'position', p.position,
        'is_cover', p.is_cover,
        'mime_type', p.mime_type,
        'size_bytes', p.size_bytes
      )
      order by p.is_cover desc, p.position asc
    ),
    '[]'::jsonb
  )
  into v_photos
  from public.business_photos p
  where p.business_id = v_b.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'name', d.name,
        'price_cop', d.price_cop,
        'description', d.description,
        'sort_order', d.sort_order
      )
      order by d.sort_order asc
    ),
    '[]'::jsonb
  )
  into v_dishes
  from public.business_dishes d
  where d.business_id = v_b.id;

  select
    case
      when count(*) > 0 then round(avg(r.stars)::numeric, 1)::double precision
      else null
    end,
    count(*)::integer
  into v_rating_avg, v_rating_count
  from public.business_ratings r
  where r.business_id = v_b.id;

  if not v_is_anon and v_uid is not null then
    select r.stars::integer
    into v_my_rating
    from public.business_ratings r
    where r.business_id = v_b.id
      and r.user_id = v_uid;
  end if;

  return jsonb_build_object(
    'id', v_b.id,
    'owner_id', v_b.owner_id,
    'is_owner', (not v_is_anon and v_uid is not null and v_b.owner_id = v_uid),
    'municipality_code', v_b.municipality_code,
    'type', v_b.type,
    'category_group', case
      when v_b.type = 'restaurant' then 'food'
      when v_b.type = 'hotel' then 'lodging'
      when v_b.type = 'transport' then 'transport'
      else 'services'
    end,
    'name', v_b.name,
    'description', case when v_resolved_locale = 'en' then v_b.description_en else v_b.description_es end,
    'description_es', v_b.description_es,
    'description_en', v_b.description_en,
    'requested_locale', v_req_locale,
    'resolved_locale', v_resolved_locale,
    'address', coalesce(v_b.address, 'Valledupar, Cesar'),
    'latitude', v_lat,
    'longitude', v_lng,
    'place_id', v_b.place_id,
    'phone', v_b.phone,
    'whatsapp', case when v_has_wa then v_b.whatsapp else null end,
    'order_url', v_b.order_url,
    'hours', v_b.hours,
    'status', v_b.status,
    'rejection_reason', case when v_can_view_unapproved then v_b.rejection_reason else null end,
    'is_demo', v_b.is_demo,
    'created_at', v_b.created_at,
    'updated_at', v_b.updated_at,
    'rating_average', v_rating_avg,
    'rating_count', coalesce(v_rating_count, 0),
    'my_rating', v_my_rating,
    'actions', jsonb_build_object(
      'can_call', v_tel_url is not null,
      'tel_url', v_tel_url,
      'can_whatsapp', v_wa_url is not null,
      'whatsapp_url', v_wa_url,
      'can_directions', v_maps_url is not null,
      'maps_url', v_maps_url,
      'can_order_external', v_b.order_url is not null,
      'order_url', v_b.order_url,
      'external_order_disclaimer', case
        when v_req_locale = 'en'
          then 'Orders and payments take place directly with the merchant outside Vía Justa.'
        else 'Los pedidos y pagos se realizan directamente con el comercio fuera de Vía Justa.'
      end
    ),
    'photos', v_photos,
    'dishes', v_dishes
  );
end;
$$;

revoke all on function public.get_business_detail(uuid, text, boolean) from public;
grant execute on function public.get_business_detail(uuid, text, boolean)
  to anon, authenticated, service_role;

commit;
