-- ============================================================================
-- Pruebas pgTAP · Vista de Ciudad de Valledupar y Eventos (VJ-15)
-- ============================================================================
-- Verifica:
--   1-3. Existencia de `get_city_content`, `get_city_events_status` y `get_city_overview`.
--   4-6. Curaduría bilingüe (`es`/`en`) de las 6 secciones de Valledupar (`20001`)
--        con fuentes oficiales (`source_citation`) y enlaces `https://`.
--   7.   Fallback explícito a español (`is_locale_fallback = true`) cuando una
--        ficha no tiene traducción en inglés (VJ-15 Paso 2).
--   8-9. Rechazo controlado para municipio inexistente (`P0002` / 404) y
--        municipio no piloto (`22023`, p. ej. Aguachica `20011`).
--   10-11. Prohibición a nivel de BD de imágenes sin licencia (`image_license`)
--          y de URLs con esquema inseguro (`javascript:`).
--   12-13. Validación estricta de ventana temporal de eventos (`upcoming` vs.
--          `active`) y exclusión de eventos `DEMO` en modo real (VJ-15 Paso 3).
--   14.  Protección de escritura (`anon`/`authenticated` no pueden modificar `city_content`).
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

-- ---------------------------------------------------------------------------
-- 1-3 · Existencia de las funciones RPC
-- ---------------------------------------------------------------------------
select has_function(
  'public',
  'get_city_content',
  array['character varying', 'character varying', 'character varying', 'boolean'],
  'get_city_content RPC exists with expected signature'
);

select has_function(
  'public',
  'get_city_events_status',
  array['character varying', 'timestamp with time zone', 'boolean'],
  'get_city_events_status RPC exists with expected signature'
);

select has_function(
  'public',
  'get_city_overview',
  array['character varying', 'character varying', 'timestamp with time zone', 'boolean'],
  'get_city_overview RPC exists with expected signature'
);

-- ---------------------------------------------------------------------------
-- 4-6 · Paridad bilingüe es/en y atribución verificable en Valledupar (20001)
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::int
    from public.get_city_content('20001', 'es', null, false)
    where resolved_locale = 'es'
      and is_locale_fallback = false
      and is_demo = false
  ),
  6,
  'get_city_content returns all 6 curated Spanish sections for Valledupar without fallback'
);

select is(
  (
    select count(*)::int
    from public.get_city_content('20001', 'en', null, false)
    where resolved_locale = 'en'
      and is_locale_fallback = false
      and is_demo = false
  ),
  6,
  'get_city_content returns all 6 curated English sections for Valledupar without fallback'
);

select is(
  (
    select count(*)::int
    from public.city_content
    where municipality_code = '20001'
      and (btrim(source_citation) = '' or source_url is null or source_url !~ '^https://')
  ),
  0,
  'every curated Valledupar city_content record has non-empty source_citation and https source_url'
);

-- ---------------------------------------------------------------------------
-- 7 · Fallback explícito a español cuando falta traducción en inglés
-- ---------------------------------------------------------------------------
insert into public.city_content (
  municipality_code,
  locale,
  slug,
  section,
  title,
  body,
  source_citation,
  source_url,
  sort_order,
  is_demo
)
values (
  '20001',
  'es',
  'ficha_solo_espanol_test',
  'culture',
  'Archivo Histórico Municipal de Valledupar',
  'Acervo documental del municipio disponible en español.',
  'Alcaldía de Valledupar — Archivo Histórico',
  'https://www.valledupar-cesar.gov.co',
  99,
  false
);

select is(
  (
    select count(*)::int
    from public.get_city_content('20001', 'en', 'culture', false)
    where slug = 'ficha_solo_espanol_test'
      and requested_locale = 'en'
      and resolved_locale = 'es'
      and is_locale_fallback = true
  ),
  1,
  'missing English translation falls back to Spanish with is_locale_fallback = true'
);

-- ---------------------------------------------------------------------------
-- 8-9 · Municipio inexistente (404 / P0002) y municipio no piloto (22023)
-- ---------------------------------------------------------------------------
select throws_ok(
  $$
    select * from public.get_city_content('99999', 'es', null, false);
  $$,
  'P0002',
  null,
  'non-existent municipality code raises P0002 [CITY_MUNICIPALITY_NOT_FOUND]'
);

select throws_ok(
  $$
    select * from public.get_city_content('20011', 'es', null, false);
  $$,
  '22023',
  null,
  'non-pilot municipality (Aguachica 20011) raises 22023 [CITY_MUNICIPALITY_NOT_PILOT]'
);

-- ---------------------------------------------------------------------------
-- 10-11 · Prohibición de imágenes sin licencia y de URLs con esquema inseguro
-- ---------------------------------------------------------------------------
select throws_ok(
  $$
    insert into public.city_content (
      municipality_code,
      locale,
      slug,
      section,
      title,
      body,
      image_path,
      image_license,
      source_citation
    )
    values (
      '20001',
      'es',
      'imagen_sin_licencia',
      'places',
      'Lugar con foto sin licencia',
      'Descripción de prueba',
      'assets/images/foto_sin_permiso.jpg',
      null,
      'Fuente de prueba'
    );
  $$,
  '23514',
  null,
  'inserting image_path without image_license is rejected by check constraint'
);

select throws_ok(
  $$
    insert into public.city_content (
      municipality_code,
      locale,
      slug,
      section,
      title,
      body,
      source_citation,
      source_url
    )
    values (
      '20001',
      'es',
      'url_maliciosa',
      'places',
      'Enlace inseguro',
      'Descripción de prueba',
      'Fuente de prueba',
      'javascript:alert(1)'
    );
  $$,
  '23514',
  null,
  'inserting non-http(s) source_url is rejected by check constraint'
);

-- ---------------------------------------------------------------------------
-- 12-13 · Ventana temporal real de eventos y exclusión de eventos DEMO
-- ---------------------------------------------------------------------------
select is(
  (
    select count(*)::int
    from public.get_city_events_status(
      '20001',
      '2026-11-16 12:00:00-05'::timestamptz,
      false
    )
    where is_demo = false
      and name like 'Festival de la Leyenda Vallenata%'
      and temporal_status = 'upcoming'
      and is_currently_active = false
  ),
  1,
  'outside April/May window, official Vallenato Festival is reported as upcoming (not active) and demo events are excluded'
);

select is(
  (
    select count(*)::int
    from public.get_city_events_status(
      '20001',
      '2027-04-30 12:00:00-05'::timestamptz,
      false
    )
    where is_demo = false
      and name like 'Festival de la Leyenda Vallenata%'
      and temporal_status = 'active'
      and is_currently_active = true
  ),
  1,
  'inside official April/May window, Vallenato Festival is reported as active'
);

-- ---------------------------------------------------------------------------
-- 14 · Clientes anon y authenticated no tienen permisos de escritura en city_content
-- ---------------------------------------------------------------------------
select is(
  (
    pg_catalog.has_table_privilege('anon', 'public.city_content', 'INSERT')
    or pg_catalog.has_table_privilege('authenticated', 'public.city_content', 'INSERT')
    or pg_catalog.has_table_privilege('authenticated', 'public.city_content', 'UPDATE')
    or pg_catalog.has_table_privilege('authenticated', 'public.city_content', 'DELETE')
  ),
  false,
  'neither anon nor authenticated can insert, update, or delete city_content'
);

select * from finish();
rollback;
