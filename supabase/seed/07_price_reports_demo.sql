-- ============================================================================
-- Seed 07 · Muestra de reportes DEMO segregados (Valledupar 20001)
-- ============================================================================
-- Regla de integridad (VJ-07 / VJ-11 / VJ-12):
--   * Nunca inventar precios ni presentarlos como observaciones reales.
--   * Todos los registros de esta semilla llevan `is_demo = true` e
--     `is_seed = false`, por lo que `calculate_price_verdict` los EXCLUYE
--     estrictamente del cálculo real del semáforo.
--   * Proveen coordenadas reales dentro de Valledupar (redondeadas a 3 decimales)
--     para poblar el modo demostrativo del mapa (fair, moderate y alert).
-- ============================================================================

insert into public.price_reports (
  id,
  user_id,
  category_id,
  municipality_code,
  zone_id,
  amount_cop,
  location,
  place_name,
  is_seed,
  is_demo,
  is_hidden,
  source_note
)
values
  (
    '00000000-0000-0000-0000-000000000701',
    null,
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    10000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    'Plaza Alfonso López',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — excluida del semáforo real'
  ),
  (
    '00000000-0000-0000-0000-000000000702',
    null,
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    13000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.472), 4326)::extensions.geography,
    'Carrera 9 · Centro',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — variación moderada (+30%)'
  ),
  (
    '00000000-0000-0000-0000-000000000703',
    null,
    'transport_taxi_minimal',
    '20001',
    'vup_centro',
    25000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography,
    'Terminal – Centro',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — alerta de sobrecobro (>40%)'
  ),
  (
    '00000000-0000-0000-0000-000000000704',
    null,
    'food_corrientazo',
    '20001',
    'vup_centro',
    12000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.476), 4326)::extensions.geography,
    'Galería Popular',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — almuerzo corriente dentro de mediana'
  ),
  (
    '00000000-0000-0000-0000-000000000705',
    null,
    'lodging_standard_night',
    '20001',
    'vup_norte',
    85000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    'Sector Novalito',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — hospedaje estándar Zona Norte'
  )
on conflict (id) do update
  set category_id = excluded.category_id,
      municipality_code = excluded.municipality_code,
      zone_id = excluded.zone_id,
      amount_cop = excluded.amount_cop,
      location = excluded.location,
      place_name = excluded.place_name,
      is_seed = false,
      is_demo = true,
      is_hidden = false,
      source_note = excluded.source_note;
