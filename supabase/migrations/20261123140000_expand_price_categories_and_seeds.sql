-- ============================================================================
-- Vía Justa · Migración · Categorías ampliadas (Turismo + Migrante) y tasa USD
-- ============================================================================
-- Agrega 5 categorías comparables clave:
--   * transport_airport_transfer (Traslado Aeropuerto / Terminal)
--   * food_breakfast (Desayuno típico)
--   * housing_room_monthly (Arriendo habitación mensual)
--   * housing_studio_monthly (Apartaestudio mensual)
--   * groceries_basic_weekly (Mercado básico semanal)
-- Además inserta semilla base (N >= 3 por categoría) en Valledupar (`20001`) y
-- registra `usd_exchange_rate_cop` en `public.app_config`.
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
  )
on conflict (id) do update
  set group_key = excluded.group_key,
      name_es = excluded.name_es,
      name_en = excluded.name_en,
      unit_description_es = excluded.unit_description_es,
      unit_description_en = excluded.unit_description_en,
      sort_order = excluded.sort_order,
      is_active = excluded.is_active;

update public.price_categories set sort_order = 3 where id = 'food_corrientazo';
update public.price_categories set sort_order = 5 where id = 'lodging_standard_night';
update public.price_categories set sort_order = 9 where id = 'services_laundry_load';

-- Tasa orientativa COP por 1 USD configurable sin recompilar la app.
update public.app_config
set value = jsonb_set(value, '{usd_exchange_rate_cop}', '4100'::jsonb, true),
    updated_at = now()
where key = 'price_verdict_rules';

-- Semilla base en Valledupar (`20001`, Zona Centro) para habilitar el semáforo (N >= 3).
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
  source_note,
  created_at
) values
  -- Traslado Aeropuerto / Terminal (mediana 22.000 COP)
  ('00000000-0000-0000-0000-000000001201', null, 'transport_airport_transfer', '20001', 'vup_centro', 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    'Aeropuerto Alfonso López → Centro', true, false, false, 'Semilla base traslado aeropuerto Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001202', null, 'transport_airport_transfer', '20001', 'vup_centro', 22000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography,
    'Centro → Aeropuerto Alfonso López', true, false, false, 'Semilla base traslado aeropuerto Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001203', null, 'transport_airport_transfer', '20001', 'vup_centro', 24000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    'Aeropuerto → Sector Norte / Novalito', true, false, false, 'Semilla base traslado aeropuerto Valledupar', now() - interval '4 days'),

  -- Desayuno típico (mediana 12.000 COP)
  ('00000000-0000-0000-0000-000000001211', null, 'food_breakfast', '20001', 'vup_centro', 11000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    'Cafeterías Centro Histórico', true, false, false, 'Semilla base desayuno Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001212', null, 'food_breakfast', '20001', 'vup_centro', 12000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography,
    'Plaza Alfonso López', true, false, false, 'Semilla base desayuno Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001213', null, 'food_breakfast', '20001', 'vup_centro', 13500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    'Sector Novalito', true, false, false, 'Semilla base desayuno Valledupar', now() - interval '4 days'),

  -- Arriendo habitación mensual (mediana 420.000 COP)
  ('00000000-0000-0000-0000-000000001221', null, 'housing_room_monthly', '20001', 'vup_centro', 390000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    'Sector Centro / Loperena', true, false, false, 'Semilla base arriendo habitación Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001222', null, 'housing_room_monthly', '20001', 'vup_centro', 420000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.478), 4326)::extensions.geography,
    'Sector San Joaquín', true, false, false, 'Semilla base arriendo habitación Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001223', null, 'housing_room_monthly', '20001', 'vup_centro', 450000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    'Sector Norte / Cortijos', true, false, false, 'Semilla base arriendo habitación Valledupar', now() - interval '4 days'),

  -- Apartaestudio mensual (mediana 780.000 COP)
  ('00000000-0000-0000-0000-000000001231', null, 'housing_studio_monthly', '20001', 'vup_centro', 720000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.474), 4326)::extensions.geography,
    'Sector Centro / Cañaguate', true, false, false, 'Semilla base apartaestudio Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001232', null, 'housing_studio_monthly', '20001', 'vup_centro', 780000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.478), 4326)::extensions.geography,
    'Sector San Joaquín', true, false, false, 'Semilla base apartaestudio Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001233', null, 'housing_studio_monthly', '20001', 'vup_centro', 850000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    'Sector Novalito', true, false, false, 'Semilla base apartaestudio Valledupar', now() - interval '4 days'),

  -- Mercado básico semanal (mediana 135.000 COP)
  ('00000000-0000-0000-0000-000000001241', null, 'groceries_basic_weekly', '20001', 'vup_centro', 125000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.473), 4326)::extensions.geography,
    'Galería Popular', true, false, false, 'Semilla base mercado Valledupar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001242', null, 'groceries_basic_weekly', '20001', 'vup_centro', 135000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.476), 4326)::extensions.geography,
    'Supermercados Centro', true, false, false, 'Semilla base mercado Valledupar', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001243', null, 'groceries_basic_weekly', '20001', 'vup_centro', 145000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    'Supermercados Norte', true, false, false, 'Semilla base mercado Valledupar', now() - interval '4 days')
on conflict (id) do update
  set amount_cop = excluded.amount_cop,
      place_name = excluded.place_name,
      source_note = excluded.source_note;
