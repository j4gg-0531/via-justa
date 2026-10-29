-- ============================================================================
-- Seed 03 · Zonas internas de Valledupar (municipio piloto 20001)
-- ============================================================================
-- Alineadas con `DemoPriceVerdictRepository.demoZonesValledupar` para que la
-- selección de zona (GPS / mapa) siga funcionando al conectar Supabase.
-- normalized_x / normalized_y ubican la zona en el lienzo del mapa local.
-- ============================================================================

insert into public.municipality_zones (
  id,
  municipality_code,
  name_es,
  name_en,
  sector_hint_es,
  sector_hint_en,
  normalized_x,
  normalized_y,
  sort_order,
  is_active
) values
  (
    'vup_norte',
    '20001',
    'Zona Norte',
    'North Zone',
    'Novalito, San Joaquín, CC Guatapurí',
    'Novalito, San Joaquín, Guatapurí Mall',
    0.5000,
    0.2000,
    1,
    true
  ),
  (
    'vup_centro',
    '20001',
    'Zona Centro',
    'Downtown Zone',
    'Centro Histórico, Plaza Alfonso López, Galería',
    'Historic Center, Alfonso López Square, Market',
    0.5000,
    0.5000,
    2,
    true
  ),
  (
    'vup_sur',
    '20001',
    'Zona Sur',
    'South Zone',
    'Terminal de Transporte, Fundadores, Mayales',
    'Bus Terminal, Fundadores, Mayales',
    0.5200,
    0.8200,
    3,
    true
  ),
  (
    'vup_oriente',
    '20001',
    'Zona Oriente',
    'East Zone',
    'Balneario Hurtado, Ribera del Río, San Fernando',
    'Hurtado Riverfront, San Fernando',
    0.8000,
    0.3600,
    4,
    true
  ),
  (
    'vup_occidente',
    '20001',
    'Zona Occidente',
    'West Zone',
    'La Nevada, Ciudadela 450 Años, Los Cortijos',
    'La Nevada, Ciudadela 450 Años, Los Cortijos',
    0.2000,
    0.5200,
    5,
    true
  )
on conflict (id) do update
  set municipality_code = excluded.municipality_code,
      name_es = excluded.name_es,
      name_en = excluded.name_en,
      sector_hint_es = excluded.sector_hint_es,
      sector_hint_en = excluded.sector_hint_en,
      normalized_x = excluded.normalized_x,
      normalized_y = excluded.normalized_y,
      sort_order = excluded.sort_order,
      is_active = excluded.is_active;
