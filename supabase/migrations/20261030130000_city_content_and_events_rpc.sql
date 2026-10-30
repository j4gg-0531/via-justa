-- ============================================================================
-- Vía Justa MVP · Migración 0010 (VJ-15) · Contenido cultural verificable y eventos
-- ============================================================================
-- Implementa el soporte de backend para la Vista de Ciudad de Valledupar (VJ-15):
--
--   1. Endurece `public.city_content` con:
--      * `slug` estable por tema para emparejar traducciones `es`/`en`.
--      * `sort_order`, `is_demo`, `image_license` y `source_url` validado (`https?://`).
--      * Constraint que prohíbe adjuntar `image_path` sin `image_license` auditable.
--      * Constraint de secciones válidas (`welcome`, `context`, `culture`,
--        `places`, `gastronomy`, `emergency`) y campos no vacíos.
--   2. Extiende `public.events` con metadatos descriptivos bilingües y fuente
--      verificable (`description_es`, `description_en`, `venue`, `source_citation`).
--   3. Crea las funciones RPC:
--      * `public.get_city_content(...)`: consulta por municipio y locale con
--        fallback automático a español (`is_locale_fallback = true`) cuando no
--        exista traducción al inglés, rechazando municipios no piloto o inexistentes.
--      * `public.get_city_events_status(...)`: evalúa la ventana temporal real
--        (`active`, `upcoming`, `past`) sin mezclar eventos DEMO con eventos reales.
--      * `public.get_city_overview(...)`: resumen JSONB consolidado de la ciudad.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Evolución y restricciones de integridad en `public.city_content`
-- ---------------------------------------------------------------------------
alter table public.city_content
  add column if not exists slug varchar(80),
  add column if not exists sort_order integer not null default 0,
  add column if not exists is_demo boolean not null default false,
  add column if not exists image_license varchar(120),
  add column if not exists source_url text;

-- Rellena `slug` determinístico para cualquier fila previa que no lo tenga.
update public.city_content
set slug = lower(regexp_replace(section || '_' || left(title, 40), '[^a-zA-Z0-9]+', '_', 'g'))
where slug is null;

alter table public.city_content
  drop constraint if exists city_content_section_check,
  drop constraint if exists city_content_non_empty_text_check,
  drop constraint if exists city_content_image_license_required_check,
  drop constraint if exists city_content_source_url_scheme_check;

alter table public.city_content
  add constraint city_content_section_check
    check (section in ('welcome', 'context', 'culture', 'places', 'gastronomy', 'emergency')),
  add constraint city_content_non_empty_text_check
    check (
      btrim(title) <> ''
      and btrim(body) <> ''
      and btrim(source_citation) <> ''
    ),
  add constraint city_content_image_license_required_check
    check (
      image_path is null
      or btrim(image_path) = ''
      or (image_license is not null and btrim(image_license) <> '')
    ),
  add constraint city_content_source_url_scheme_check
    check (
      source_url is null
      or source_url ~ '^https?://'
    );

create unique index if not exists city_content_municipality_locale_slug_uq
  on public.city_content (municipality_code, locale, slug)
  where slug is not null;

create index if not exists city_content_lookup_idx
  on public.city_content (municipality_code, section, sort_order, locale);

-- ---------------------------------------------------------------------------
-- 2. Metadatos verificables en `public.events`
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists description_es text,
  add column if not exists description_en text,
  add column if not exists venue varchar(150),
  add column if not exists source_citation varchar(255);

-- ---------------------------------------------------------------------------
-- 3. RPC `public.get_city_content` con fallback explícito a español (VJ-15 Paso 2)
-- ---------------------------------------------------------------------------
create or replace function public.get_city_content(
  p_municipality_code varchar default '20001',
  p_locale varchar default 'es',
  p_section varchar default null,
  p_include_demo boolean default false
)
returns table (
  id uuid,
  municipality_code varchar(5),
  slug varchar(80),
  section varchar(50),
  requested_locale varchar(2),
  resolved_locale varchar(2),
  is_locale_fallback boolean,
  title varchar(150),
  body text,
  image_path text,
  image_license varchar(120),
  source_citation varchar(255),
  source_url text,
  sort_order integer,
  is_demo boolean
)
language plpgsql
stable
security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_code text := btrim(coalesce(p_municipality_code, ''));
  v_req_locale varchar(2) := case
    when lower(btrim(coalesce(p_locale, 'es'))) like 'en%' then 'en'
    else 'es'
  end;
  v_is_pilot boolean;
begin
  if v_code = '' then
    raise exception '[CITY_MUNICIPALITY_NOT_FOUND] El código de municipio es obligatorio.'
      using errcode = 'P0002';
  end if;

  select m.is_pilot
  into v_is_pilot
  from public.municipalities m
  where m.code = v_code;

  if not found then
    raise exception '[CITY_MUNICIPALITY_NOT_FOUND] El municipio % no existe en el catálogo DIVIPOLA.',
      v_code
      using errcode = 'P0002';
  end if;

  if not v_is_pilot then
    raise exception '[CITY_MUNICIPALITY_NOT_PILOT] El municipio % aún no tiene ficha cultural verificada en el piloto.',
      v_code
      using errcode = '22023';
  end if;

  return query
  with candidates as (
    select
      cc.id,
      cc.municipality_code,
      coalesce(cc.slug, lower(cc.section || '_' || cc.title))::varchar(80) as topic_key,
      cc.section,
      v_req_locale as requested_locale,
      cc.locale as resolved_locale,
      (cc.locale <> v_req_locale) as is_locale_fallback,
      cc.title,
      cc.body,
      cc.image_path,
      cc.image_license,
      cc.source_citation,
      cc.source_url,
      cc.sort_order,
      cc.is_demo,
      row_number() over (
        partition by cc.municipality_code, coalesce(cc.slug, lower(cc.section || '_' || cc.title))
        order by
          case
            when cc.locale = v_req_locale then 0
            when cc.locale = 'es' then 1
            else 2
          end asc,
          cc.is_demo asc
      ) as rn
    from public.city_content cc
    where cc.municipality_code = v_code
      and (p_section is null or btrim(p_section) = '' or cc.section = btrim(p_section))
      and (cc.is_demo = false or p_include_demo = true)
      and cc.locale in (v_req_locale, 'es')
  )
  select
    c.id,
    c.municipality_code,
    c.topic_key as slug,
    c.section,
    c.requested_locale,
    c.resolved_locale,
    c.is_locale_fallback,
    c.title,
    c.body,
    c.image_path,
    c.image_license,
    c.source_citation,
    c.source_url,
    c.sort_order,
    c.is_demo
  from candidates c
  where c.rn = 1
  order by c.sort_order asc, c.section asc, c.title asc;
end;
$$;

comment on function public.get_city_content(varchar, varchar, varchar, boolean) is
  'Devuelve el contenido cultural verificado del municipio piloto con fallback explícito a español si falta traducción.';

revoke all on function public.get_city_content(varchar, varchar, varchar, boolean) from public;
grant execute on function public.get_city_content(varchar, varchar, varchar, boolean)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. RPC `public.get_city_events_status` con validación temporal (VJ-15 Paso 3)
-- ---------------------------------------------------------------------------
create or replace function public.get_city_events_status(
  p_municipality_code varchar default '20001',
  p_reference_time timestamptz default now(),
  p_include_demo boolean default false
)
returns table (
  id uuid,
  municipality_code varchar(5),
  name varchar(150),
  description_es text,
  description_en text,
  venue varchar(150),
  starts_at timestamptz,
  ends_at timestamptz,
  temporal_status text,
  is_currently_active boolean,
  is_demo boolean,
  source_citation varchar(255)
)
language plpgsql
stable
security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_code text := btrim(coalesce(p_municipality_code, ''));
  v_eval_time timestamptz := coalesce(p_reference_time, now());
  v_is_pilot boolean;
begin
  select m.is_pilot
  into v_is_pilot
  from public.municipalities m
  where m.code = v_code;

  if not found then
    raise exception '[CITY_MUNICIPALITY_NOT_FOUND] El municipio % no existe en el catálogo DIVIPOLA.',
      v_code
      using errcode = 'P0002';
  end if;

  if not v_is_pilot then
    raise exception '[CITY_MUNICIPALITY_NOT_PILOT] El municipio % aún no está habilitado como piloto.',
      v_code
      using errcode = '22023';
  end if;

  return query
  select
    e.id,
    e.municipality_code,
    e.name,
    e.description_es,
    e.description_en,
    e.venue,
    e.starts_at,
    e.ends_at,
    case
      when v_eval_time between e.starts_at and e.ends_at then 'active'::text
      when e.starts_at > v_eval_time then 'upcoming'::text
      else 'past'::text
    end as temporal_status,
    (v_eval_time between e.starts_at and e.ends_at) as is_currently_active,
    e.is_demo,
    e.source_citation
  from public.events e
  where e.municipality_code = v_code
    and (e.is_demo = false or p_include_demo = true)
  order by
    (v_eval_time between e.starts_at and e.ends_at) desc,
    e.is_demo asc,
    e.starts_at asc;
end;
$$;

comment on function public.get_city_events_status(varchar, timestamptz, boolean) is
  'Evalúa la ventana temporal real de los eventos del municipio piloto (active, upcoming, past), separando DEMO de eventos reales.';

revoke all on function public.get_city_events_status(varchar, timestamptz, boolean) from public;
grant execute on function public.get_city_events_status(varchar, timestamptz, boolean)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. RPC `public.get_city_overview` (payload consolidado para la ficha de ciudad)
-- ---------------------------------------------------------------------------
create or replace function public.get_city_overview(
  p_municipality_code varchar default '20001',
  p_locale varchar default 'es',
  p_reference_time timestamptz default now(),
  p_include_demo boolean default false
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_muni record;
  v_content jsonb;
  v_events jsonb;
  v_has_fallback boolean := false;
begin
  select m.code, m.name, m.department_code, m.is_pilot
  into v_muni
  from public.municipalities m
  where m.code = btrim(coalesce(p_municipality_code, ''));

  if not found then
    raise exception '[CITY_MUNICIPALITY_NOT_FOUND] El municipio % no existe en el catálogo DIVIPOLA.',
      p_municipality_code
      using errcode = 'P0002';
  end if;

  if not v_muni.is_pilot then
    raise exception '[CITY_MUNICIPALITY_NOT_PILOT] El municipio % aún no está habilitado como piloto.',
      p_municipality_code
      using errcode = '22023';
  end if;

  select
    coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order, c.section), '[]'::jsonb),
    coalesce(bool_or(c.is_locale_fallback), false)
  into v_content, v_has_fallback
  from public.get_city_content(
    v_muni.code,
    p_locale,
    null,
    p_include_demo
  ) c;

  select
    coalesce(jsonb_agg(to_jsonb(ev)), '[]'::jsonb)
  into v_events
  from public.get_city_events_status(
    v_muni.code,
    p_reference_time,
    p_include_demo
  ) ev;

  return jsonb_build_object(
    'municipality_code', v_muni.code,
    'municipality_name', v_muni.name,
    'department_code', v_muni.department_code,
    'is_pilot', v_muni.is_pilot,
    'requested_locale', case when lower(btrim(coalesce(p_locale, 'es'))) like 'en%' then 'en' else 'es' end,
    'has_locale_fallback', v_has_fallback,
    'content', v_content,
    'events', v_events
  );
end;
$$;

comment on function public.get_city_overview(varchar, varchar, timestamptz, boolean) is
  'Retorna la ficha cultural bilingüe completa y el estado temporal de eventos para el municipio piloto.';

revoke all on function public.get_city_overview(varchar, varchar, timestamptz, boolean) from public;
grant execute on function public.get_city_overview(varchar, varchar, timestamptz, boolean)
  to anon, authenticated, service_role;
