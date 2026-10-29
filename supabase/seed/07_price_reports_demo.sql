-- ============================================================================
-- Seed 07 · Muestra de reportes DEMO segregados (Valledupar 20001)
-- ============================================================================
-- Regla de integridad (VJ-07 / VJ-11):
--   * Nunca inventar precios ni presentarlos como observaciones reales.
--   * Todos los registros de esta semilla llevan `is_demo = true` e
--     `is_seed = false`, por lo que `calculate_price_verdict` los EXCLUYE
--     estrictamente del cálculo real del semáforo.
--   * Los reportes reales de levantamiento de campo (`is_seed = true`,
--     `is_demo = false`) solo se insertan cuando cuenten con acta de campo
--     verificable (fecha/hora, categoría/unidad, monto, sector y metodología).
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
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.474), 4326)::extensions.geography,
    'Plaza Alfonso López (DEMO)',
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
    11000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.473), 4326)::extensions.geography,
    'Calle 17 Centro (DEMO)',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — excluida del semáforo real'
  ),
  (
    '00000000-0000-0000-0000-000000000703',
    null,
    'food_corrientazo',
    '20001',
    'vup_centro',
    14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.250, 10.475), 4326)::extensions.geography,
    'Galería Popular (DEMO)',
    false,
    true,
    false,
    '[DEMO] Muestra ilustrativa local — excluida del semáforo real'
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
