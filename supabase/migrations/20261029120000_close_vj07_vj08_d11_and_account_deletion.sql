-- ============================================================================
-- Vía Justa MVP · Migración 0006 · Cierre de VJ-07 / VJ-08 (D11, GRANTs, RF-06)
-- ============================================================================
-- Cierra los pendientes del bloque de Backend de Cuenta y Esquema Base:
--   1. D11 ratificada: `public.profiles.profile_type` admite 'visitor',
--      'settler' y 'resident'.
--   2. Defensa en profundidad en `public.price_reports`: restringe los
--      privilegios `GRANT INSERT, UPDATE` exclusivamente a las columnas de
--      negocio permitidas al ciudadano, impidiendo que un cliente malicioso
--      fije `is_seed = true`, `is_hidden = true` o manipule `created_at` / `id`.
--   3. Protocolo transaccional de supresión de cuenta y minimización de datos
--      (Ley 1581 de 2012 / RF-06): función RPC `public.delete_my_account()`
--      que sanea `price_reports` (`source_note`, `place_name`, `location` a NULL),
--      suprime `consents` e `interest_registrations`, y elimina el registro del
--      propio usuario en `auth.users` (disparando ON DELETE CASCADE en `profiles`
--      y ON DELETE SET NULL en `price_reports.user_id`).
--
-- Referencias:
--   docs/decisiones.md D11, D13, D14
--   docs/contrato-datos-v1.md §2.1 y §2.6
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1 · Ratificación de D11: incluir 'resident' en public.profiles.profile_type
-- ---------------------------------------------------------------------------
alter table public.profiles
  drop constraint if exists profiles_profile_type_check;

alter table public.profiles
  add constraint profiles_profile_type_check
  check (profile_type in ('visitor', 'settler', 'resident'));

comment on column public.profiles.profile_type is
  'Perfil de usuario (D11 acordada): visitor | settler | resident. Nunca confiere rol administrativo.';

-- ---------------------------------------------------------------------------
-- 2 · Defensa en profundidad por columnas en public.price_reports
-- ---------------------------------------------------------------------------
-- Revoca el INSERT/UPDATE de tabla completa para impedir que `authenticated`
-- escriba en `is_seed`, `is_hidden`, `created_at` o `id`.
revoke insert, update on public.price_reports from authenticated;

grant insert (
  user_id,
  category_id,
  municipality_code,
  zone_id,
  amount_cop,
  location,
  place_name,
  is_demo,
  source_note
) on public.price_reports to authenticated;

grant update (
  category_id,
  zone_id,
  amount_cop,
  location,
  place_name,
  source_note
) on public.price_reports to authenticated;

-- ---------------------------------------------------------------------------
-- 3 · Supresión transaccional de cuenta y saneamiento Habeas Data (RF-06)
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED: must be authenticated to delete account'
      using errcode = '42501';
  end if;

  -- Fase 1: Depuración contextual y saneamiento espacial en reportes antes de
  -- desvincular la llave foránea (Ley 1581 de 2012, §2.6 del contrato).
  update public.price_reports
  set source_note = null,
      place_name = null,
      location = null
  where user_id = v_user_id;

  -- Eliminación de registros personales directos (también cubiertos por CASCADE,
  -- pero ejecutados explícitamente en la fase de pre-supresión).
  delete from public.consents
  where user_id = v_user_id;

  delete from public.interest_registrations
  where user_id = v_user_id;

  -- Fase 2: Supresión del usuario en auth.users.
  -- Esto elimina en cascada public.profiles (ON DELETE CASCADE) y desvincula
  -- public.price_reports.user_id = NULL (ON DELETE SET NULL).
  delete from auth.users
  where id = v_user_id;
end;
$$;

comment on function public.delete_my_account() is
  'Elimina la cuenta del usuario autenticado (auth.uid()) tras sanear PII y coordenadas en price_reports (RF-06 / Ley 1581).';

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
