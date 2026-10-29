-- ============================================================================
-- Vía Justa MVP · Migración 0002 · Perfiles, consentimientos y administración
-- ============================================================================
-- Crea:
--   * public.profiles: datos de identidad y preferencias del usuario.
--   * public.consents: registro inmutable de aceptación de términos/privacidad.
--   * public.admin_users: autorización administrativa separada de profiles.
--   * public.is_admin(): verificación segura de administrador.
--   * Trigger handle_new_user(): crea el perfil al registrarse en auth.users.
--
-- Referencias:
--   docs/contrato-datos-v1.md §2.1 y §2.2
--   docs/seguridad-privacidad.md §4
--
-- D11 (perfil `resident`) sigue PROPUESTA: el CHECK actual solo admite
-- 'visitor' y 'settler'. Cuando se ratifique, se agregará una migración
-- complementaria que amplíe la restricción.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Perfiles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  profile_type text
    check (profile_type in ('visitor', 'settler')),
  origin_country text,
  current_municipality_code text
    references public.municipalities(code)
    on update cascade
    on delete set null,
  language text not null default 'es'
    check (language in ('es', 'en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Perfil del usuario autenticado. Los privilegios administrativos viven en admin_users, nunca aquí.';

-- Trigger genérico para mantener updated_at.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

-- Creación automática del perfil al registrarse en Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), '')
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- RLS: cada usuario solo ve y edita su propia fila.
alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Defensa en profundidad: el cliente no puede insertar/borrar perfiles ni
-- modificar columnas de auditoría (created_at / updated_at / id).
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (
  display_name,
  origin_country,
  current_municipality_code,
  language,
  profile_type
) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Consentimientos (Habeas Data, Ley 1581 de 2012)
-- ---------------------------------------------------------------------------
create table if not exists public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  doc_type varchar(50) not null
    check (doc_type in ('terms_and_conditions', 'privacy_policy')),
  version varchar(20) not null,
  accepted_at timestamptz not null default now()
);

create index if not exists idx_consents_user on public.consents (user_id);

alter table public.consents enable row level security;

drop policy if exists consents_select_own on public.consents;
create policy consents_select_own
  on public.consents
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists consents_insert_own on public.consents;
create policy consents_insert_own
  on public.consents
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Registro inmutable: sin UPDATE ni DELETE para el cliente.
revoke all on public.consents from anon, authenticated;
grant select, insert on public.consents to authenticated;

-- ---------------------------------------------------------------------------
-- Autorización administrativa aislada
-- ---------------------------------------------------------------------------
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade
);

comment on table public.admin_users is
  'Lista de administradores. Sin políticas RLS para anon/authenticated: solo service_role.';

alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

grant execute on function public.is_admin() to anon, authenticated;
