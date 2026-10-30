-- ============================================================================
-- Seed 08 · Servicios y negocios de referencia DEMO en el mapa (Valledupar 20001)
-- ============================================================================
-- Regla de integridad (VJ-12 / VJ-16 / VJ-17):
--   * Todos estos puntos llevan `is_demo = true` y prefijo `[DEMO]`, por lo que
--     no se confunden con negocios reales registrados por comerciantes.
--   * Cualquier negocio real que se inserte en `public.businesses` con
--     `status = 'approved'` e `is_demo = false` aparecerá automáticamente en
--     `public.get_municipality_map_items` con prioridad sobre los DEMO.
-- ============================================================================

insert into public.businesses (
  id,
  owner_id,
  municipality_code,
  type,
  name,
  description_es,
  description_en,
  address,
  location,
  phone,
  whatsapp,
  whatsapp_consent_at,
  status,
  is_demo
)
values
  (
    '00000000-0000-0000-0000-000000000801',
    null,
    '20001',
    'hospital',
    '[DEMO] Hospital Rosario Pumarejo de López',
    'Muestra DEMO — Atención de urgencias 24h y servicios hospitalarios · Calle 16B #19-75',
    'DEMO sample — 24h emergency care and hospital services · Calle 16B #19-75',
    'Calle 16B #19-75, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2562, 10.4718), 4326)::extensions.geography,
    '6055748400',
    '576055748400',
    now(),
    'approved',
    true
  ),
  (
    '00000000-0000-0000-0000-000000000802',
    null,
    '20001',
    'service',
    '[DEMO] Cruz Roja - Atención a Migrantes y Primeros Auxilios',
    'Muestra DEMO — Punto de orientación humanitaria y primeros auxilios en Valledupar',
    'DEMO sample — Humanitarian guidance and first aid point in Valledupar',
    'Carrera 19 #14-50, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2545, 10.4758), 4326)::extensions.geography,
    '6055712255',
    '576055712255',
    now(),
    'approved',
    true
  ),
  (
    '00000000-0000-0000-0000-000000000803',
    null,
    '20001',
    'consulate',
    '[DEMO] Enlace de Orientación Migratoria y Consular',
    'Muestra DEMO — Información de trámites, regularización, consulados y defensoría',
    'DEMO sample — Paperwork, regularization, consular guidance and ombudsman routes',
    'Calle 15 #11-45 · Sector Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2452, 10.4752), 4326)::extensions.geography,
    '6055801122',
    '576055801122',
    now(),
    'approved',
    true
  ),
  (
    '00000000-0000-0000-0000-000000000804',
    null,
    '20001',
    'restaurant',
    '[DEMO] Restaurante El Pilón Vallenato',
    'Muestra DEMO — Gastronomía típica cesarense con precios visibles en carta',
    'DEMO sample — Traditional Cesar cuisine with visible menu prices',
    'Carrera 6 #15-22 · Plaza Alfonso López',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2432, 10.4768), 4326)::extensions.geography,
    '3000000001',
    '573000000001',
    now(),
    'approved',
    true
  ),
  (
    '00000000-0000-0000-0000-000000000805',
    null,
    '20001',
    'hotel',
    '[DEMO] Hotel Boutique Los Ángeles',
    'Muestra DEMO — Hospedaje de referencia cerca del Centro Histórico de Valledupar',
    'DEMO sample — Reference lodging near the Historic Center of Valledupar',
    'Calle 16 #7-18 · Centro Histórico',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2448, 10.4739), 4326)::extensions.geography,
    '3000000002',
    '573000000002',
    now(),
    'approved',
    true
  )
on conflict (id) do update
  set municipality_code = excluded.municipality_code,
      type = excluded.type,
      name = excluded.name,
      description_es = excluded.description_es,
      description_en = excluded.description_en,
      address = excluded.address,
      location = excluded.location,
      phone = excluded.phone,
      whatsapp = excluded.whatsapp,
      status = 'approved',
      is_demo = true;
