-- ============================================================================
-- Vía Justa · Migración · Nombre real desde metadatos OAuth (Google) en registro
-- ============================================================================
-- Google OAuth guarda el nombre completo del usuario en `raw_user_meta_data`
-- bajo `full_name` o `name`, no en `display_name`. Este ajuste prioriza:
--   display_name -> full_name -> name -> prefijo del correo
-- evitando que las cuentas nuevas o recreadas con Google queden con el alias
-- del correo como nombre visible inicial.
-- ============================================================================

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
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), ''),
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'name', '')), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), '')
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;
