-- ============================================================================
-- Seed 11 · Semilla base de precios de referencia (Valledupar 20001)
-- ============================================================================
-- Provee el mínimo de N >= 3 observaciones semilla (`is_seed = true`,
-- `is_demo = false`, `is_hidden = false`) por categoría, zona y rango de
-- distancia de taxi en Valledupar (`20001`) para habilitar el semáforo
-- (Verde / Amarillo / Rojo) en `public.calculate_price_verdict`.
-- ============================================================================

insert into public.price_reports (
  id,
  user_id,
  category_id,
  municipality_code,
  zone_id,
  destination_zone_id,
  amount_cop,
  location,
  destination_location,
  distance_km,
  distance_range,
  place_name,
  is_seed,
  is_demo,
  is_hidden,
  source_note,
  created_at
)
values
  -- ==========================================================================
  -- 1. TAXI (transport_taxi_minimal) · Rangos 0_2_km, 2_5_km y gt_5_km
  -- ==========================================================================
  -- Rango corto (0_2_km) -> mediana 8.000 COP
  ('00000000-0000-0000-0000-000000001101', null, 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_centro', 8000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.472), 4326)::extensions.geography,
    0.50, '0_2_km', 'Plaza Alfonso López → Carrera 9', true, false, false, 'Semilla base taxi corto Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001102', null, 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_norte', 8000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    1.84, '0_2_km', 'Centro → Novalito', true, false, false, 'Semilla base taxi corto Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001103', null, 'transport_taxi_minimal', '20001', 'vup_norte', 'vup_centro', 8500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    1.84, '0_2_km', 'Novalito → Centro', true, false, false, 'Semilla base taxi corto Valledupar', now() - interval '4 days'),

  -- Rango medio (2_5_km) -> mediana 12.000 COP
  ('00000000-0000-0000-0000-000000001104', null, 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_sur', 12000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography,
    3.22, '2_5_km', 'Centro → Terminal de Transportes', true, false, false, 'Semilla base taxi medio Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001105', null, 'transport_taxi_minimal', '20001', 'vup_sur', 'vup_centro', 12000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    3.22, '2_5_km', 'Terminal → Centro', true, false, false, 'Semilla base taxi medio Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001106', null, 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_occidente', 12500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.279, 10.468), 4326)::extensions.geography,
    3.89, '2_5_km', 'Centro → La Nevada', true, false, false, 'Semilla base taxi medio Valledupar', now() - interval '4 days'),

  -- Rango largo (gt_5_km) -> mediana 16.000 COP
  ('00000000-0000-0000-0000-000000001107', null, 'transport_taxi_minimal', '20001', 'vup_sur', 'vup_oriente', 16000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.498), 4326)::extensions.geography,
    6.04, 'gt_5_km', 'Aeropuerto / Sur → Balneario Hurtado', true, false, false, 'Semilla base taxi largo Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001108', null, 'transport_taxi_minimal', '20001', 'vup_oriente', 'vup_sur', 16000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.498), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography,
    6.04, 'gt_5_km', 'Hurtado → Terminal / Sur', true, false, false, 'Semilla base taxi largo Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001109', null, 'transport_taxi_minimal', '20001', 'vup_occidente', 'vup_oriente', 17000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.285, 10.455), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.502), 4326)::extensions.geography,
    6.80, 'gt_5_km', 'Occidente → Río Guatapurí', true, false, false, 'Semilla base taxi largo Valledupar', now() - interval '4 days'),

  -- ==========================================================================
  -- 2. ALMUERZO CORRIENTE (food_corrientazo) · Todas las zonas de Valledupar
  -- ==========================================================================
  ('00000000-0000-0000-0000-000000001121', null, 'food_corrientazo', '20001', 'vup_centro', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography, null, null, null,
    'Restaurantes Centro Histórico', true, false, false, 'Semilla base almuerzo Centro', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001122', null, 'food_corrientazo', '20001', 'vup_centro', null, 15000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography, null, null, null,
    'Comedores Plaza Alfonso López', true, false, false, 'Semilla base almuerzo Centro', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001123', null, 'food_corrientazo', '20001', 'vup_centro', null, 16000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.473), 4326)::extensions.geography, null, null, null,
    'Galería Popular', true, false, false, 'Semilla base almuerzo Centro', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001124', null, 'food_corrientazo', '20001', 'vup_norte', null, 17000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography, null, null, null,
    'Sector Novalito', true, false, false, 'Semilla base almuerzo Norte', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001125', null, 'food_corrientazo', '20001', 'vup_norte', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.254, 10.489), 4326)::extensions.geography, null, null, null,
    'Alrededores Guatapurí Plaza', true, false, false, 'Semilla base almuerzo Norte', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001126', null, 'food_corrientazo', '20001', 'vup_norte', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.487), 4326)::extensions.geography, null, null, null,
    'Los Cortijos', true, false, false, 'Semilla base almuerzo Norte', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001127', null, 'food_corrientazo', '20001', 'vup_sur', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography, null, null, null,
    'Sector Terminal de Transportes', true, false, false, 'Semilla base almuerzo Sur', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001128', null, 'food_corrientazo', '20001', 'vup_sur', null, 15000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.446), 4326)::extensions.geography, null, null, null,
    'Avenida Fundación', true, false, false, 'Semilla base almuerzo Sur', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001129', null, 'food_corrientazo', '20001', 'vup_sur', null, 15000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.444), 4326)::extensions.geography, null, null, null,
    'Comedores Terminal', true, false, false, 'Semilla base almuerzo Sur', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001151', null, 'food_corrientazo', '20001', 'vup_oriente', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.498), 4326)::extensions.geography, null, null, null,
    'Balneario Hurtado', true, false, false, 'Semilla base almuerzo Oriente', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001152', null, 'food_corrientazo', '20001', 'vup_oriente', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.260, 10.497), 4326)::extensions.geography, null, null, null,
    'Parque de la Leyenda', true, false, false, 'Semilla base almuerzo Oriente', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001153', null, 'food_corrientazo', '20001', 'vup_oriente', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.499), 4326)::extensions.geography, null, null, null,
    'Ribera Río Guatapurí', true, false, false, 'Semilla base almuerzo Oriente', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001154', null, 'food_corrientazo', '20001', 'vup_occidente', null, 13000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.279, 10.468), 4326)::extensions.geography, null, null, null,
    'La Nevada', true, false, false, 'Semilla base almuerzo Occidente', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001155', null, 'food_corrientazo', '20001', 'vup_occidente', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.278, 10.467), 4326)::extensions.geography, null, null, null,
    'Los Fundadores', true, false, false, 'Semilla base almuerzo Occidente', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001156', null, 'food_corrientazo', '20001', 'vup_occidente', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.280, 10.469), 4326)::extensions.geography, null, null, null,
    'Sabanas del Valle', true, false, false, 'Semilla base almuerzo Occidente', now() - interval '4 days'),

  -- ==========================================================================
  -- 3. HABITACIÓN ESTÁNDAR (lodging_standard_night) · Todas las zonas
  -- ==========================================================================
  ('00000000-0000-0000-0000-000000001131', null, 'lodging_standard_night', '20001', 'vup_centro', null, 80000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography, null, null, null,
    'Hotel Centro Valledupar', true, false, false, 'Semilla base hospedaje Centro', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001132', null, 'lodging_standard_night', '20001', 'vup_centro', null, 85000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography, null, null, null,
    'Hospedaje Carrera 9', true, false, false, 'Semilla base hospedaje Centro', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001133', null, 'lodging_standard_night', '20001', 'vup_centro', null, 90000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.473), 4326)::extensions.geography, null, null, null,
    'Hotel Plaza Centro', true, false, false, 'Semilla base hospedaje Centro', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001134', null, 'lodging_standard_night', '20001', 'vup_norte', null, 95000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography, null, null, null,
    'Hotel Sector Novalito', true, false, false, 'Semilla base hospedaje Norte', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001135', null, 'lodging_standard_night', '20001', 'vup_norte', null, 100000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.254, 10.489), 4326)::extensions.geography, null, null, null,
    'Hospedaje Los Cortijos', true, false, false, 'Semilla base hospedaje Norte', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001136', null, 'lodging_standard_night', '20001', 'vup_norte', null, 100000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.487), 4326)::extensions.geography, null, null, null,
    'Hotel Zona Norte', true, false, false, 'Semilla base hospedaje Norte', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001161', null, 'lodging_standard_night', '20001', 'vup_sur', null, 70000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography, null, null, null,
    'Hotel Sector Terminal', true, false, false, 'Semilla base hospedaje Sur', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001162', null, 'lodging_standard_night', '20001', 'vup_sur', null, 75000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.446), 4326)::extensions.geography, null, null, null,
    'Hospedaje Avenida Fundación', true, false, false, 'Semilla base hospedaje Sur', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001163', null, 'lodging_standard_night', '20001', 'vup_sur', null, 75000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.444), 4326)::extensions.geography, null, null, null,
    'Hotel Sur Valledupar', true, false, false, 'Semilla base hospedaje Sur', now() - interval '4 days'),

  -- ==========================================================================
  -- 4. LAVANDERÍA (services_laundry_load) · Mediana 18.000 COP
  -- ==========================================================================
  ('00000000-0000-0000-0000-000000001141', null, 'services_laundry_load', '20001', 'vup_centro', null, 17000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography, null, null, null,
    'Lavandería Centro', true, false, false, 'Semilla base lavandería Centro', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001142', null, 'services_laundry_load', '20001', 'vup_centro', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography, null, null, null,
    'Lavaseco Calle 16', true, false, false, 'Semilla base lavandería Centro', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001143', null, 'services_laundry_load', '20001', 'vup_centro', null, 19000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.473), 4326)::extensions.geography, null, null, null,
    'Lavandería Loperena', true, false, false, 'Semilla base lavandería Centro', now() - interval '4 days'),

  ('00000000-0000-0000-0000-000000001144', null, 'services_laundry_load', '20001', 'vup_norte', null, 19000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography, null, null, null,
    'Lavandería Novalito', true, false, false, 'Semilla base lavandería Norte', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001145', null, 'services_laundry_load', '20001', 'vup_norte', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.254, 10.489), 4326)::extensions.geography, null, null, null,
    'Lavaseco Los Cortijos', true, false, false, 'Semilla base lavandería Norte', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001146', null, 'services_laundry_load', '20001', 'vup_norte', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.487), 4326)::extensions.geography, null, null, null,
    'Lavandería Zona Norte', true, false, false, 'Semilla base lavandería Norte', now() - interval '4 days')
on conflict (id) do update
  set category_id = excluded.category_id,
      municipality_code = excluded.municipality_code,
      zone_id = excluded.zone_id,
      destination_zone_id = excluded.destination_zone_id,
      amount_cop = excluded.amount_cop,
      location = excluded.location,
      destination_location = excluded.destination_location,
      distance_km = excluded.distance_km,
      distance_range = excluded.distance_range,
      place_name = excluded.place_name,
      is_seed = true,
      is_demo = false,
      is_hidden = false,
      source_note = excluded.source_note,
      created_at = excluded.created_at;
