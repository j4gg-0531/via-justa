-- ============================================================================
-- Seed 04 · Categorías de precio comparables (piloto Valledupar)
-- ============================================================================
-- Los IDs coinciden con `DemoPriceVerdictRepository.demoCategories` del
-- frontend. Los nombres van sin el prefijo "[DEMO]" porque esta es la fuente
-- real; el rótulo de demostración es responsabilidad de la capa de datos demo.
-- ============================================================================

insert into public.price_categories (
  id,
  group_key,
  name_es,
  name_en,
  unit_description_es,
  unit_description_en,
  sort_order,
  is_active
) values
  (
    'transport_taxi_minimal',
    'transport',
    'Taxi — Carrera mínima urbana',
    'Taxi — Minimum urban ride',
    'Trayecto diurno dentro de la zona seleccionada',
    'Daytime trip within the selected zone',
    1,
    true
  ),
  (
    'food_corrientazo',
    'food',
    'Almuerzo ejecutivo / corriente',
    'Standard daily lunch',
    'Plato del día con sopa, seco y bebida en la zona',
    'Daily lunch menu with soup, main dish, and drink in the zone',
    2,
    true
  ),
  (
    'lodging_standard_night',
    'lodging',
    'Habitación estándar (1 noche)',
    'Standard room (1 night)',
    'Habitación sencilla o doble con ventilador/A.C. en la zona',
    'Single or double room with fan/A.C. in the zone',
    3,
    true
  ),
  (
    'services_laundry_load',
    'services',
    'Lavandería por tanda',
    'Laundry per load',
    'Lavado y secado básico hasta 5 kg',
    'Basic wash and dry up to 5 kg',
    4,
    true
  )
on conflict (id) do update
  set group_key = excluded.group_key,
      name_es = excluded.name_es,
      name_en = excluded.name_en,
      unit_description_es = excluded.unit_description_es,
      unit_description_en = excluded.unit_description_en,
      sort_order = excluded.sort_order,
      is_active = excluded.is_active;
