-- ============================================================================
-- Vía Justa MVP · Corrección de permisos en public.rate_business
-- ============================================================================
-- `authenticated` solo posee permiso UPDATE sobre la columna `stars` en
-- `public.business_ratings`, mientras que `updated_at` lo mantiene el trigger
-- BEFORE INSERT OR UPDATE (`private.enforce_business_rating_rules`).
-- Al ser `rate_business` SECURITY INVOKER, asignar `updated_at = now()` dentro
-- de `ON CONFLICT DO UPDATE` provocaba `permission denied for table business_ratings`
-- incluso en la primera valoración.
-- ============================================================================

begin;

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
    stars = excluded.stars;

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

comment on function public.rate_business(uuid, integer) is
  'Registra o actualiza la valoración (1..5 estrellas) del usuario autenticado sobre un negocio ajeno; updated_at lo gestiona el trigger.';

commit;
