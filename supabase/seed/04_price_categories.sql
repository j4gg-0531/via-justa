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
    'transport_airport_transfer',
    'transport',
    'Traslado Aeropuerto / Terminal',
    'Airport / Bus Terminal transfer',
    'Trayecto directo entre aeropuerto o terminal y la zona',
    'Direct ride between airport or bus terminal and the zone',
    2,
    true
  ),
  (
    'food_corrientazo',
    'food',
    'Almuerzo ejecutivo / corriente',
    'Standard daily lunch',
    'Plato del día con sopa, seco y bebida en la zona',
    'Daily lunch menu with soup, main dish, and drink in the zone',
    3,
    true
  ),
  (
    'food_breakfast',
    'food',
    'Desayuno típico',
    'Local breakfast',
    'Arepa o bollo con proteína y bebida caliente',
    'Local breakfast plate with hot drink',
    4,
    true
  ),
  (
    'lodging_standard_night',
    'lodging',
    'Habitación estándar (1 noche)',
    'Standard room (1 night)',
    'Habitación sencilla o doble con ventilador/A.C. en la zona',
    'Single or double room with fan/A.C. in the zone',
    5,
    true
  ),
  (
    'housing_room_monthly',
    'housing',
    'Arriendo habitación (mes)',
    'Monthly room rent',
    'Habitación amoblada con servicios básicos incluidos',
    'Furnished monthly room with basic utilities included',
    6,
    true
  ),
  (
    'housing_studio_monthly',
    'housing',
    'Apartaestudio (mes)',
    'Monthly studio apartment',
    'Canon mensual de apartaestudio sin amoblar en la zona',
    'Monthly unfurnished studio rent in the zone',
    7,
    true
  ),
  (
    'groceries_basic_weekly',
    'groceries',
    'Mercado básico semanal',
    'Basic weekly groceries',
    'Canasta esencial de 1 semana para una persona',
    'Essential 1-week grocery basket for one person',
    8,
    true
  ),
  (
    'services_laundry_load',
    'services',
    'Lavandería por tanda',
    'Laundry per load',
    'Lavado y secado básico hasta 5 kg',
    'Basic wash and dry up to 5 kg',
    9,
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
