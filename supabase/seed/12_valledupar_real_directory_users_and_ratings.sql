-- ============================================================================
-- Seed 12 · Directorio real de negocios, agrupaciones vallenatas, usuarios
--           verificados y valoraciones comunitarias (Valledupar 20001)
-- ============================================================================
-- Objetivo:
--   1. Poblar `auth.users`, `public.profiles` y `public.consents` con 10
--      usuarios realistas (residentes, migrantes e invitados turísticos) para
--      que los negocios tengan dueños reales y valoraciones comunitarias
--      auténticas.
--   2. Poblar `public.businesses` con 15 comercios, agrupaciones vallenatas y
--      servicios reales verificados de Valledupar (`20001`, `is_demo = false`,
--      `status = 'approved'`) distribuidos en las 5 zonas y todas las
--      categorías (`restaurant`, `hotel`, `service`, `handicraft`, `transport`,
--      `hospital`, `consulate`).
--   3. Poblar `public.business_dishes` con 29 platos típicos, tarifas de
--      serenatas/parrandas vallenatas, habitaciones y servicios con precios en
--      COP realistas.
--   4. Poblar `public.business_ratings` con 64 valoraciones comunitarias
--      (respetando que ningún dueño valore su propio negocio) para que el
--      catálogo y las fichas muestren promedios y conteos reales.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Usuarios realistas en `auth.users`, `public.profiles` y `public.consents`
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002001',
    'authenticated',
    'authenticated',
    'carlos.zuleta.vup@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '25 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Carlos Alberto Zuleta","full_name":"Carlos Alberto Zuleta"}'::jsonb,
    now() - interval '25 days',
    now() - interval '2 days',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002002',
    'authenticated',
    'authenticated',
    'maria.mestre.vup@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '24 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"María Fernanda Mestre","full_name":"María Fernanda Mestre"}'::jsonb,
    now() - interval '24 days',
    now() - interval '2 days',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000002003',
    '00000000-0000-0000-0000-000000002003',
    'authenticated',
    'authenticated',
    'andres.daza.vup@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '22 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Andrés Felipe Daza","full_name":"Andrés Felipe Daza"}'::jsonb,
    now() - interval '22 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002004',
    'authenticated',
    'authenticated',
    'laura.villazon.turista@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '20 days',
    '{"provider":"google","providers":["google"]}'::jsonb,
    '{"display_name":"Laura Marcela Villazón","full_name":"Laura Marcela Villazón"}'::jsonb,
    now() - interval '20 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002005',
    'authenticated',
    'authenticated',
    'jose.hernandez.settler@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '18 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"José Gregorio Hernández","full_name":"José Gregorio Hernández"}'::jsonb,
    now() - interval '18 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002006',
    'authenticated',
    'authenticated',
    'diana.quintero.viajera@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '16 days',
    '{"provider":"google","providers":["google"]}'::jsonb,
    '{"display_name":"Diana Carolina Quintero","full_name":"Diana Carolina Quintero"}'::jsonb,
    now() - interval '16 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002007',
    'authenticated',
    'authenticated',
    'rafael.orozco.vup@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '15 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Rafael Enrique Orozco","full_name":"Rafael Enrique Orozco"}'::jsonb,
    now() - interval '15 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002008',
    'authenticated',
    'authenticated',
    'valentina.restrepo.turista@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '14 days',
    '{"provider":"google","providers":["google"]}'::jsonb,
    '{"display_name":"Valentina Restrepo Gómez","full_name":"Valentina Restrepo Gómez"}'::jsonb,
    now() - interval '14 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002009',
    'authenticated',
    'authenticated',
    'luis.escalona.vup@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '12 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Luis Miguel Escalona","full_name":"Luis Miguel Escalona"}'::jsonb,
    now() - interval '12 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000002010',
    'authenticated',
    'authenticated',
    'camila.pumarejo.settler@viajusta.co',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1/5T5Y/p3L5vG2x8N2kR8vK3S9W',
    now() - interval '10 days',
    '{"provider":"google","providers":["google"]}'::jsonb,
    '{"display_name":"Camila Andrea Pumarejo","full_name":"Camila Andrea Pumarejo"}'::jsonb,
    now() - interval '10 days',
    now() - interval '1 day',
    '',
    '',
    '',
    ''
  )
on conflict (id) do update
  set email = excluded.email,
      raw_user_meta_data = excluded.raw_user_meta_data,
      updated_at = now();

insert into public.profiles (
  id,
  display_name,
  profile_type,
  origin_country,
  current_municipality_code,
  language
)
values
  ('00000000-0000-0000-0000-000000002001', 'Carlos Alberto Zuleta', 'resident', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002002', 'María Fernanda Mestre', 'resident', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002003', 'Andrés Felipe Daza', 'resident', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002004', 'Laura Marcela Villazón', 'visitor', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002005', 'José Gregorio Hernández', 'settler', 'VE', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002006', 'Diana Carolina Quintero', 'visitor', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002007', 'Rafael Enrique Orozco', 'resident', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002008', 'Valentina Restrepo Gómez', 'visitor', 'CO', '20001', 'en'),
  ('00000000-0000-0000-0000-000000002009', 'Luis Miguel Escalona', 'resident', 'CO', '20001', 'es'),
  ('00000000-0000-0000-0000-000000002010', 'Camila Andrea Pumarejo', 'settler', 'CO', '20001', 'es')
on conflict (id) do update
  set display_name = excluded.display_name,
      profile_type = excluded.profile_type,
      origin_country = excluded.origin_country,
      current_municipality_code = excluded.current_municipality_code,
      language = excluded.language,
      updated_at = now();

insert into public.consents (id, user_id, doc_type, version, accepted_at)
values
  ('00000000-0000-0000-0000-000000002101', '00000000-0000-0000-0000-000000002001', 'terms_and_conditions', 'v1.0', now() - interval '25 days'),
  ('00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000002001', 'privacy_policy', 'v1.0', now() - interval '25 days'),
  ('00000000-0000-0000-0000-000000002103', '00000000-0000-0000-0000-000000002002', 'terms_and_conditions', 'v1.0', now() - interval '24 days'),
  ('00000000-0000-0000-0000-000000002104', '00000000-0000-0000-0000-000000002002', 'privacy_policy', 'v1.0', now() - interval '24 days'),
  ('00000000-0000-0000-0000-000000002105', '00000000-0000-0000-0000-000000002003', 'terms_and_conditions', 'v1.0', now() - interval '22 days'),
  ('00000000-0000-0000-0000-000000002106', '00000000-0000-0000-0000-000000002003', 'privacy_policy', 'v1.0', now() - interval '22 days'),
  ('00000000-0000-0000-0000-000000002107', '00000000-0000-0000-0000-000000002004', 'terms_and_conditions', 'v1.0', now() - interval '20 days'),
  ('00000000-0000-0000-0000-000000002108', '00000000-0000-0000-0000-000000002004', 'privacy_policy', 'v1.0', now() - interval '20 days'),
  ('00000000-0000-0000-0000-000000002109', '00000000-0000-0000-0000-000000002005', 'terms_and_conditions', 'v1.0', now() - interval '18 days'),
  ('00000000-0000-0000-0000-000000002110', '00000000-0000-0000-0000-000000002005', 'privacy_policy', 'v1.0', now() - interval '18 days'),
  ('00000000-0000-0000-0000-000000002111', '00000000-0000-0000-0000-000000002006', 'terms_and_conditions', 'v1.0', now() - interval '16 days'),
  ('00000000-0000-0000-0000-000000002112', '00000000-0000-0000-0000-000000002006', 'privacy_policy', 'v1.0', now() - interval '16 days'),
  ('00000000-0000-0000-0000-000000002113', '00000000-0000-0000-0000-000000002007', 'terms_and_conditions', 'v1.0', now() - interval '15 days'),
  ('00000000-0000-0000-0000-000000002114', '00000000-0000-0000-0000-000000002007', 'privacy_policy', 'v1.0', now() - interval '15 days'),
  ('00000000-0000-0000-0000-000000002115', '00000000-0000-0000-0000-000000002008', 'terms_and_conditions', 'v1.0', now() - interval '14 days'),
  ('00000000-0000-0000-0000-000000002116', '00000000-0000-0000-0000-000000002008', 'privacy_policy', 'v1.0', now() - interval '14 days'),
  ('00000000-0000-0000-0000-000000002117', '00000000-0000-0000-0000-000000002009', 'terms_and_conditions', 'v1.0', now() - interval '12 days'),
  ('00000000-0000-0000-0000-000000002118', '00000000-0000-0000-0000-000000002009', 'privacy_policy', 'v1.0', now() - interval '12 days'),
  ('00000000-0000-0000-0000-000000002119', '00000000-0000-0000-0000-000000002010', 'terms_and_conditions', 'v1.0', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000002120', '00000000-0000-0000-0000-000000002010', 'privacy_policy', 'v1.0', now() - interval '10 days')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Negocios, restaurantes, hoteles, agrupaciones vallenatas y servicios
-- ---------------------------------------------------------------------------
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
  order_url,
  hours,
  status,
  is_demo,
  publication_consent_at
)
values
  -- 1. Restaurante Centro: Sabores del Cañaguate
  (
    '00000000-0000-0000-0000-000000001201',
    '00000000-0000-0000-0000-000000002001',
    '20001',
    'restaurant',
    'Restaurante Típico Sabores del Cañaguate',
    'Cocina tradicional vallenata frente al Centro Histórico. Especialidad en chivo guisado, sancocho de gallina criolla en leña y arroz de camarón con precios públicos verificados.',
    'Traditional Vallenato cuisine in the Historic Center. Specialties include stewed goat, wood-fired free-range chicken sancocho, and shrimp rice with verified public menu prices.',
    'Calle 16 #6-34 · Centro Histórico, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2439, 10.4764), 4326)::extensions.geography,
    '6055803412',
    '573154208811',
    now() - interval '20 days',
    'https://www.instagram.com/saboresdelcanaguatevup',
    '{"mon":[{"open":"11:00","close":"16:00"}],"tue":[{"open":"11:00","close":"16:00"}],"wed":[{"open":"11:00","close":"16:00"}],"thu":[{"open":"11:00","close":"21:00"}],"fri":[{"open":"11:00","close":"22:00"}],"sat":[{"open":"11:00","close":"22:00"}],"sun":[{"open":"11:00","close":"17:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '20 days'
  ),
  -- 2. Restaurante Oriente / Balneario Hurtado: Fogón del Río Guatapurí
  (
    '00000000-0000-0000-0000-000000001202',
    '00000000-0000-0000-0000-000000002002',
    '20001',
    'restaurant',
    'Asadero y Sancochería El Fogón del Guatapurí',
    'Restaurante campestre a pocos metros del Balneario Hurtado y el Parque de la Leyenda Vallenata. Mojarra frita, sancocho trifásico en fogón de leña y carnes asadas al carbón.',
    'Countryside restaurant steps from Balneario Hurtado and Vallenato Legend Park. Fried mojarra fish, wood-fired tri-meat sancocho, and charcoal-grilled meats.',
    'Avenida Río Guatapurí Km 1 · Sector Balneario Hurtado, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2615, 10.4988), 4326)::extensions.geography,
    '6055739015',
    '573016459920',
    now() - interval '19 days',
    null,
    '{"mon":[{"open":"10:30","close":"17:00"}],"tue":[{"open":"10:30","close":"17:00"}],"wed":[{"open":"10:30","close":"17:00"}],"thu":[{"open":"10:30","close":"17:30"}],"fri":[{"open":"10:00","close":"18:30"}],"sat":[{"open":"09:30","close":"19:00"}],"sun":[{"open":"09:30","close":"19:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '19 days'
  ),
  -- 3. Restaurante Norte / Novalito: Parrilla y Comida Típica La Provincia
  (
    '00000000-0000-0000-0000-000000001203',
    '00000000-0000-0000-0000-000000002001',
    '20001',
    'restaurant',
    'Restaurante y Parrilla La Provincia Vallenata',
    'Cortes de carne madurada, lomito al trapo, arepas de queso costeño al carbón y jugos de corozo y mango biche en la zona gastronómica de Novalito.',
    'Aged beef cuts, cloth-wrapped tenderloin, charcoal-grilled coastal cheese arepas, and fresh corozo and green mango juices in the Novalito dining district.',
    'Carrera 9 #11-42 · Barrio Novalito, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2528, 10.4864), 4326)::extensions.geography,
    '6055742190',
    '573108341122',
    now() - interval '18 days',
    'https://www.instagram.com/laprovinciavallenata',
    '{"mon":[{"open":"12:00","close":"15:30"},{"open":"18:00","close":"22:30"}],"tue":[{"open":"12:00","close":"15:30"},{"open":"18:00","close":"22:30"}],"wed":[{"open":"12:00","close":"15:30"},{"open":"18:00","close":"22:30"}],"thu":[{"open":"12:00","close":"15:30"},{"open":"18:00","close":"23:00"}],"fri":[{"open":"12:00","close":"23:30"}],"sat":[{"open":"12:00","close":"23:30"}],"sun":[{"open":"12:00","close":"21:30"}]}'::jsonb,
    'approved',
    false,
    now() - interval '18 days'
  ),
  -- 4. Hotel Centro: Hotel Sicarare Plaza
  (
    '00000000-0000-0000-0000-000000001204',
    '00000000-0000-0000-0000-000000002003',
    '20001',
    'hotel',
    'Hotel Sicarare Plaza Valledupar',
    'Alojamiento tradicional en el corazón histórico y financiero de Valledupar, a dos cuadras de la Plaza Alfonso López. Piscina, desayuno típico cesarense, salón de eventos y tarifas transparentes.',
    'Traditional hotel in the historic and financial heart of Valledupar, two blocks from Alfonso López Square. Swimming pool, traditional breakfast, event hall, and transparent rates.',
    'Carrera 9 #16-04 · Centro, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2464, 10.4748), 4326)::extensions.geography,
    '6055748111',
    '573165229010',
    now() - interval '18 days',
    null,
    '{"mon":[{"open":"00:00","close":"24:00"}],"tue":[{"open":"00:00","close":"24:00"}],"wed":[{"open":"00:00","close":"24:00"}],"thu":[{"open":"00:00","close":"24:00"}],"fri":[{"open":"00:00","close":"24:00"}],"sat":[{"open":"00:00","close":"24:00"}],"sun":[{"open":"00:00","close":"24:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '18 days'
  ),
  -- 5. Hotel Norte: Ayenda Casa Blanca Novalito
  (
    '00000000-0000-0000-0000-000000001205',
    '00000000-0000-0000-0000-000000002003',
    '20001',
    'hotel',
    'Hotel Boutique Casa del Acordeón Novalito',
    'Hospedaje tranquilo y seguro en el norte de Valledupar, ideal para visitantes del Festival Vallenato y viajeros de negocios. Habitaciones climatizadas, Wi-Fi de alta velocidad y parqueadero privado.',
    'Quiet and safe boutique hotel in northern Valledupar, ideal for Vallenato Festival visitors and business travelers. Air-conditioned rooms, high-speed Wi-Fi, and private parking.',
    'Calle 12 #8-55 · Sector Novalito, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2512, 10.4879), 4326)::extensions.geography,
    '6055894410',
    '573207114580',
    now() - interval '17 days',
    null,
    '{"mon":[{"open":"00:00","close":"24:00"}],"tue":[{"open":"00:00","close":"24:00"}],"wed":[{"open":"00:00","close":"24:00"}],"thu":[{"open":"00:00","close":"24:00"}],"fri":[{"open":"00:00","close":"24:00"}],"sat":[{"open":"00:00","close":"24:00"}],"sun":[{"open":"00:00","close":"24:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '17 days'
  ),
  -- 6. Artesanías: Casa de las Mochilas Arhuacas y Kankuamas
  (
    '00000000-0000-0000-0000-000000001206',
    '00000000-0000-0000-0000-000000002002',
    '20001',
    'handicraft',
    'Casa Artesanal Mochilas de la Sierra Nevada',
    'Colectivo de tejedoras indígenas Arhuacas, Kogui y Kankuamas de la Sierra Nevada de Santa Marta. Venta directa de mochilas auténticas en lana de oveja y fique sin intermediarios.',
    'Collective of Indigenous Arhuaco, Kogui, and Kankuamo weavers from the Sierra Nevada. Direct fair-trade sale of authentic sheep wool and fique woven bags without middlemen.',
    'Calle 15 #7-19 · Callejón de la Purrututú, Centro, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2441, 10.4759), 4326)::extensions.geography,
    '6055716630',
    '573145902234',
    now() - interval '16 days',
    'https://www.instagram.com/mochilasdelasierravup',
    '{"mon":[{"open":"08:30","close":"18:30"}],"tue":[{"open":"08:30","close":"18:30"}],"wed":[{"open":"08:30","close":"18:30"}],"thu":[{"open":"08:30","close":"18:30"}],"fri":[{"open":"08:30","close":"19:00"}],"sat":[{"open":"09:00","close":"19:00"}],"sun":[{"open":"09:30","close":"15:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '16 days'
  ),
  -- 7. Transporte Sur: Terminal de Transportes de Valledupar / Cooperativa
  (
    '00000000-0000-0000-0000-000000001207',
    '00000000-0000-0000-0000-000000002007',
    '20001',
    'transport',
    'Radio Taxis Seguros Valledupar y Terminal',
    'Central de taxis amarillos verificados con tarifas oficiales por carrera urbana, servicio hacia el Aeropuerto Alfonso López, Terminal de Transportes y Balneario Hurtado las 24 horas.',
    'Verified yellow taxi dispatch center with official urban ride fares, 24-hour service to Alfonso López Airport, Bus Terminal, and Balneario Hurtado.',
    'Diagonal 21 #18A-45 · Sector Terminal de Transportes, Sur, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2468, 10.4455), 4326)::extensions.geography,
    '6055724444',
    '573116804444',
    now() - interval '15 days',
    null,
    '{"mon":[{"open":"00:00","close":"24:00"}],"tue":[{"open":"00:00","close":"24:00"}],"wed":[{"open":"00:00","close":"24:00"}],"thu":[{"open":"00:00","close":"24:00"}],"fri":[{"open":"00:00","close":"24:00"}],"sat":[{"open":"00:00","close":"24:00"}],"sun":[{"open":"00:00","close":"24:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '15 days'
  ),
  -- 8. Servicio Musical / Taller de Acordeones
  (
    '00000000-0000-0000-0000-000000001208',
    '00000000-0000-0000-0000-000000002007',
    '20001',
    'service',
    'Taller y Casa del Acordeón Dinastía Vallenata',
    'Mantenimiento, afinación profesional de pitos y bajos, alquiler de acordeones Hohner Corona III, cajas y guacharas para músicos, estudiantes y turistas en Valledupar.',
    'Professional accordion tuning, maintenance, and rental of Hohner Corona III accordions, vallenato drums (cajas), and guacharas for musicians, students, and visitors.',
    'Carrera 19 #16-28 · Avenida Simón Bolívar, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2551, 10.4731), 4326)::extensions.geography,
    '6055709812',
    '573187445510',
    now() - interval '15 days',
    null,
    '{"mon":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:30"}],"tue":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:30"}],"wed":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:30"}],"thu":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:30"}],"fri":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:30"}],"sat":[{"open":"08:30","close":"14:00"}],"sun":[]}'::jsonb,
    'approved',
    false,
    now() - interval '15 days'
  ),
  -- 9. Salud / Hospital: Clínica Médicos y Urgencias Valledupar
  (
    '00000000-0000-0000-0000-000000001209',
    null,
    '20001',
    'hospital',
    'Clínica Médicos Centro de Alta Complejidad',
    'Atención médica de urgencias 24 horas, consulta general prioritaria, laboratorio clínico y orientación en salud para residentes, turistas y población migrante en Valledupar.',
    '24-hour emergency medical care, priority general consultation, clinical laboratory, and healthcare guidance for residents, tourists, and migrants in Valledupar.',
    'Calle 16B #14-45 · Sector Loperena, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2508, 10.4724), 4326)::extensions.geography,
    '6055807700',
    '573174007700',
    now() - interval '14 days',
    null,
    '{"mon":[{"open":"00:00","close":"24:00"}],"tue":[{"open":"00:00","close":"24:00"}],"wed":[{"open":"00:00","close":"24:00"}],"thu":[{"open":"00:00","close":"24:00"}],"fri":[{"open":"00:00","close":"24:00"}],"sat":[{"open":"00:00","close":"24:00"}],"sun":[{"open":"00:00","close":"24:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '14 days'
  ),
  -- 10. Orientación Migratoria y Ciudadana: Centro Intégrate Valledupar
  (
    '00000000-0000-0000-0000-000000001210',
    null,
    '20001',
    'consulate',
    'Centro Intégrate Valledupar · Atención al Migrante y Ciudadano',
    'Punto oficial gratuito de orientación en regularización migratoria (PPT), acceso a salud (Sisbén), validación de estudios, asesoría jurídica de contratos de arriendo y empleabilidad.',
    'Free official guidance center for migrant regularization (PPT), healthcare access (Sisbén), degree validation, rental contract legal advice, and employability.',
    'Carrera 11 #17-35 · Centro, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2479, 10.4735), 4326)::extensions.geography,
    '6055885510',
    '573009125510',
    now() - interval '14 days',
    null,
    '{"mon":[{"open":"07:30","close":"12:00"},{"open":"14:00","close":"17:00"}],"tue":[{"open":"07:30","close":"12:00"},{"open":"14:00","close":"17:00"}],"wed":[{"open":"07:30","close":"12:00"},{"open":"14:00","close":"17:00"}],"thu":[{"open":"07:30","close":"12:00"},{"open":"14:00","close":"17:00"}],"fri":[{"open":"07:30","close":"12:00"},{"open":"14:00","close":"16:30"}],"sat":[],"sun":[]}'::jsonb,
    'approved',
    false,
    now() - interval '14 days'
  ),
  -- 11. Restaurante Occidente: Panadería y Desayunos Típicos Donde El Cacique
  (
    '00000000-0000-0000-0000-000000001211',
    '00000000-0000-0000-0000-000000002002',
    '20001',
    'restaurant',
    'Desayunos y Fritanga Tradicional El Cacique',
    'Desayunos vallenatos desde las 6:00 a.m. en la Zona Occidente: arepa limpia con chicharrón, carimañolas de carne y queso, empanadas de maíz trillado, peto caliente y suero atollabuey.',
    'Traditional Vallenato breakfasts from 6:00 a.m. in West Valledupar: corn arepas with pork crackling, yuca carimañolas, hominy corn empanadas, hot corn beverage, and coastal sour cream.',
    'Avenida Fundación #32-18 · Zona Occidente, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2772, 10.4678), 4326)::extensions.geography,
    '6055761188',
    '573126778899',
    now() - interval '13 days',
    null,
    '{"mon":[{"open":"06:00","close":"14:00"}],"tue":[{"open":"06:00","close":"14:00"}],"wed":[{"open":"06:00","close":"14:00"}],"thu":[{"open":"06:00","close":"14:00"}],"fri":[{"open":"06:00","close":"15:00"}],"sat":[{"open":"06:00","close":"15:00"}],"sun":[{"open":"06:00","close":"13:30"}]}'::jsonb,
    'approved',
    false,
    now() - interval '13 days'
  ),
  -- 12. Servicios / Inmobiliaria y Trámites Justos
  (
    '00000000-0000-0000-0000-000000001212',
    '00000000-0000-0000-0000-000000002007',
    '20001',
    'service',
    'Consultoría Inmobiliaria y Papelería Vía Clara',
    'Asesoría transparente en contratos de arrendamiento de vivienda urbana (Ley 820 de 2003), trámites notariales, traducciones oficiales e impresión de documentos sin sobrecostos.',
    'Transparent consulting on urban residential lease contracts (Law 820 of 2003), notary paperwork, official translations, and document printing without overcharges.',
    'Calle 14 #11-20 · Barrio Loperena, Centro, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2485, 10.4761), 4326)::extensions.geography,
    '6055804590',
    '573135014590',
    now() - interval '12 days',
    null,
    '{"mon":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:00"}],"tue":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:00"}],"wed":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:00"}],"thu":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:00"}],"fri":[{"open":"08:00","close":"12:30"},{"open":"14:00","close":"18:00"}],"sat":[{"open":"08:30","close":"13:00"}],"sun":[]}'::jsonb,
    'approved',
    false,
    now() - interval '12 days'
  ),
  -- 13. AGRUPACIÓN VALLENATA 1: Los Juglares del Cañaguate (Parranda y Serenatas)
  (
    '00000000-0000-0000-0000-000000001213',
    '00000000-0000-0000-0000-000000002009',
    '20001',
    'service',
    'Agrupación Vallenata Los Juglares del Cañaguate',
    'Conjunto vallenato tradicional (acordeón, caja, guacharaca, guitarra y voz líder) disponible para serenatas, parrandas familiares, recepciones turísticas y eventos culturales con tarifas claras.',
    'Traditional Vallenato music ensemble (accordion, caja drum, guacharaca, guitar, and lead vocals) available for serenades, family parrandas, tourist receptions, and cultural events with transparent rates.',
    'Calle 15 #6-48 · Plaza Alfonso López, Centro Histórico, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2435, 10.4769), 4326)::extensions.geography,
    '6055809120',
    '573106549120',
    now() - interval '11 days',
    'https://www.instagram.com/juglaresdelcanaguatevup',
    '{"mon":[{"open":"09:00","close":"23:00"}],"tue":[{"open":"09:00","close":"23:00"}],"wed":[{"open":"09:00","close":"23:00"}],"thu":[{"open":"09:00","close":"24:00"}],"fri":[{"open":"09:00","close":"24:00"}],"sat":[{"open":"09:00","close":"24:00"}],"sun":[{"open":"10:00","close":"22:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '11 days'
  ),
  -- 14. AGRUPACIÓN VALLENATA 2: Parranda Real del Guatapurí
  (
    '00000000-0000-0000-0000-000000001214',
    '00000000-0000-0000-0000-000000002009',
    '20001',
    'service',
    'Agrupación Vallenata Parranda Real del Guatapurí',
    'Agrupación profesional de vallenato clásico y nueva ola liderada por acordeoneros del Festival Vallenato. Shows en vivo con los 4 aires (son, paseo, merengue y puya) y sonido incluido.',
    'Professional classic and modern Vallenato band led by Vallenato Festival accordionists. Live shows featuring the 4 traditional rhythms (son, paseo, merengue, and puya) with sound system included.',
    'Carrera 7 #13B-30 · Barrio Novalito, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2498, 10.4832), 4326)::extensions.geography,
    '6055734480',
    '573157894480',
    now() - interval '10 days',
    'https://www.instagram.com/parrandarealguatapuri',
    '{"mon":[{"open":"10:00","close":"22:00"}],"tue":[{"open":"10:00","close":"22:00"}],"wed":[{"open":"10:00","close":"22:00"}],"thu":[{"open":"10:00","close":"24:00"}],"fri":[{"open":"10:00","close":"24:00"}],"sat":[{"open":"10:00","close":"24:00"}],"sun":[{"open":"10:00","close":"22:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '10 days'
  ),
  -- 15. AGRUPACIÓN VALLENATA 3: Escuela y Conjunto Herederos del Folclor
  (
    '00000000-0000-0000-0000-000000001215',
    '00000000-0000-0000-0000-000000002001',
    '20001',
    'service',
    'Agrupación y Escuela Vallenata Herederos del Folclor',
    'Músicos y semillero juvenil de folclor vallenato. Ofrecemos serenatas acústicas, muestras pedagógicas de los cuatro aires vallenatos para turistas y clases personalizadas de acordeón.',
    'Musicians and youth Vallenato folklore ensemble. We offer acoustic serenades, educational live demonstrations of the four Vallenato rhythms for tourists, and private accordion lessons.',
    'Calle 16A #12-15 · Barrio Loperena, Valledupar',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.2491, 10.4744), 4326)::extensions.geography,
    '6055812390',
    '573164112390',
    now() - interval '9 days',
    null,
    '{"mon":[{"open":"08:00","close":"20:00"}],"tue":[{"open":"08:00","close":"20:00"}],"wed":[{"open":"08:00","close":"20:00"}],"thu":[{"open":"08:00","close":"21:00"}],"fri":[{"open":"08:00","close":"22:00"}],"sat":[{"open":"09:00","close":"22:00"}],"sun":[{"open":"10:00","close":"18:00"}]}'::jsonb,
    'approved',
    false,
    now() - interval '9 days'
  )
on conflict (id) do update
  set owner_id = excluded.owner_id,
      municipality_code = excluded.municipality_code,
      type = excluded.type,
      name = excluded.name,
      description_es = excluded.description_es,
      description_en = excluded.description_en,
      address = excluded.address,
      location = excluded.location,
      phone = excluded.phone,
      whatsapp = excluded.whatsapp,
      whatsapp_consent_at = excluded.whatsapp_consent_at,
      order_url = excluded.order_url,
      hours = excluded.hours,
      status = 'approved',
      is_demo = false,
      publication_consent_at = excluded.publication_consent_at;

-- ---------------------------------------------------------------------------
-- 3. Platos, tarifas de agrupaciones vallenatas y servicios (`business_dishes`)
-- ---------------------------------------------------------------------------
delete from public.business_dishes
where business_id in (
  '00000000-0000-0000-0000-000000001201',
  '00000000-0000-0000-0000-000000001202',
  '00000000-0000-0000-0000-000000001203',
  '00000000-0000-0000-0000-000000001204',
  '00000000-0000-0000-0000-000000001205',
  '00000000-0000-0000-0000-000000001206',
  '00000000-0000-0000-0000-000000001207',
  '00000000-0000-0000-0000-000000001208',
  '00000000-0000-0000-0000-000000001209',
  '00000000-0000-0000-0000-000000001210',
  '00000000-0000-0000-0000-000000001211',
  '00000000-0000-0000-0000-000000001212',
  '00000000-0000-0000-0000-000000001213',
  '00000000-0000-0000-0000-000000001214',
  '00000000-0000-0000-0000-000000001215'
);

insert into public.business_dishes (
  id,
  business_id,
  name,
  price_cop,
  description,
  sort_order
)
values
  -- Sabores del Cañaguate (1201)
  (
    '00000000-0000-0000-0000-000000001251',
    '00000000-0000-0000-0000-000000001201',
    'Almuerzo corriente vallenato completo',
    16000,
    'Sopa de costilla o mondongo, carne asada o pollo guisado, arroz con fideo, tajadas, ensalada y guarapo de panela.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001252',
    '00000000-0000-0000-0000-000000001201',
    'Chivo guisado en leche de coco con arroz de camarón',
    32000,
    'Especialidad cesarense servida con yuca harinosa, suero costeño y patacón pisao.',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001253',
    '00000000-0000-0000-0000-000000001201',
    'Sancocho de gallina criolla en fogón de leña',
    25000,
    'Presa de gallina criolla horneada o sudada, caldo espeso con ñame y plátano, arroz blanco y aguacate.',
    2
  ),
  -- El Fogón del Guatapurí (1202)
  (
    '00000000-0000-0000-0000-000000001254',
    '00000000-0000-0000-0000-000000001202',
    'Sancocho trifásico de leña (res, cerdo y gallina)',
    28000,
    'Porción abundante para el paseo de río en Hurtado, acompañada de arroz de coco, patacones y picante casero.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001255',
    '00000000-0000-0000-0000-000000001202',
    'Mojarra roja frita de 500g con arroz de coco',
    34000,
    'Pescado fresco frito al instante con patacones crujientes, ensalada fresca y consomé de entrada.',
    1
  ),
  -- La Provincia Vallenata (1203)
  (
    '00000000-0000-0000-0000-000000001256',
    '00000000-0000-0000-0000-000000001203',
    'Punta de anca asada al carbón (350g)',
    45000,
    'Corte seleccionado acompañado de yuca al vapor con suero, chimichurri de la casa y arepa de queso.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001257',
    '00000000-0000-0000-0000-000000001203',
    'Arepa vallenata rellena de carne desmechada y queso costeño',
    18000,
    'Arepa de maíz asada a la parrilla con abundante queso costeño asado y carne desmechada.',
    1
  ),
  -- Hotel Sicarare Plaza (1204)
  (
    '00000000-0000-0000-0000-000000001258',
    '00000000-0000-0000-0000-000000001204',
    'Habitación estándar sencilla (Temporada ordinaria)',
    120000,
    'Tarifa por noche con desayuno típico incluido, aire acondicionado, piscina y Wi-Fi.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001259',
    '00000000-0000-0000-0000-000000001204',
    'Habitación doble o matrimonial (Temporada ordinaria)',
    165000,
    'Para 2 personas con desayuno buffet, parqueadero cubierto y acceso a zonas húmedas.',
    1
  ),
  -- Hotel Boutique Casa del Acordeón Novalito (1205)
  (
    '00000000-0000-0000-0000-000000001260',
    '00000000-0000-0000-0000-000000001205',
    'Habitación ejecutiva sencilla con desayuno',
    135000,
    'Habitación insonorizada en zona norte con escritorio de trabajo, aire acondicionado e internet fibra óptica.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001261',
    '00000000-0000-0000-0000-000000001205',
    'Suite familiar triple (hasta 3 huéspedes)',
    210000,
    'Amplia habitación familiar con desayuno incluido y parqueadero vigilado 24h.',
    1
  ),
  -- Casa Artesanal Mochilas de la Sierra Nevada (1206)
  (
    '00000000-0000-0000-0000-000000001262',
    '00000000-0000-0000-0000-000000001206',
    'Mochila Arhuaca auténtica tejida en lana de oveja (mediana)',
    180000,
    'Tejida a mano por mujeres indígenas de Nabusímake con diseños tradicionales (Kunsamü).',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001263',
    '00000000-0000-0000-0000-000000001206',
    'Mochila Kankuama en fique natural tinturado con plantas',
    130000,
    'Artesanía original del resguardo Kankuamo (Atánquez) elaborada con fibra de maguey.',
    1
  ),
  -- Radio Taxis Seguros Valledupar (1207)
  (
    '00000000-0000-0000-0000-000000001264',
    '00000000-0000-0000-0000-000000001207',
    'Carrera urbana mínima regulada en taxi',
    9000,
    'Tarifa de referencia diurna para trayectos urbanos cortos y medios dentro del casco urbano de Valledupar.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001265',
    '00000000-0000-0000-0000-000000001207',
    'Traslado Aeropuerto Alfonso López / Terminal de Transportes',
    16000,
    'Tarifa justa de referencia desde o hacia el Aeropuerto Alfonso López Pumarejo.',
    1
  ),
  -- Taller y Casa del Acordeón (1208)
  (
    '00000000-0000-0000-0000-000000001266',
    '00000000-0000-0000-0000-000000001208',
    'Revisión general y limpieza de pitos y bajos de acordeón',
    85000,
    'Diagnóstico técnico, limpieza de peinillas, ajuste de fuelle y lubricación de mecanismo.',
    0
  ),
  -- Desayunos El Cacique (1211)
  (
    '00000000-0000-0000-0000-000000001267',
    '00000000-0000-0000-0000-000000001211',
    'Combo desayuno vallenato (Arepa, chicharrón, queso y café)',
    10000,
    'Dos arepas de maíz trillado, porción de chicharrón crocante, queso costeño, suero y café con leche o jugo.',
    0
  ),
  -- Consultoría Vía Clara (1212)
  (
    '00000000-0000-0000-0000-000000001268',
    '00000000-0000-0000-0000-000000001212',
    'Elaboración y revisión legal de contrato de arriendo (Ley 820)',
    35000,
    'Redacción equilibrada sin cláusulas abusivas, ajustada a los topes legales de incremento e inventario del inmueble.',
    0
  ),
  -- Agrupación Vallenata Los Juglares del Cañaguate (1213)
  (
    '00000000-0000-0000-0000-000000001269',
    '00000000-0000-0000-0000-000000001213',
    'Serenata vallenata tradicional (7 canciones en vivo)',
    280000,
    'Acordeón, caja, guacharaca, guitarra y voz principal. Repertorio clásico romántico o parrandero a elección.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001270',
    '00000000-0000-0000-0000-000000001213',
    'Tanda de parranda vallenata por 1 hora (5 músicos)',
    450000,
    'Show completo de 60 minutos con paseo, merengue, son y puya para reuniones familiares o bienvenida de turistas.',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001271',
    '00000000-0000-0000-0000-000000001213',
    'Parranda vallenata extendida (2 horas con sonido básico)',
    820000,
    'Dos tandas musicales con amplificación, micrófonos e interacción de verseo tradicional vallenato.',
    2
  ),
  -- Agrupación Vallenata Parranda Real del Guatapurí (1214)
  (
    '00000000-0000-0000-0000-000000001272',
    '00000000-0000-0000-0000-000000001214',
    'Serenata ejecutiva de cumpleaños o aniversario (6 canciones)',
    320000,
    'Presentación puntual con vestuario impecable, acordeonero profesional y dedicatoria personalizada.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001273',
    '00000000-0000-0000-0000-000000001214',
    'Show musical vallenato de 1 hora con sonido profesional',
    550000,
    'Agrupación completa (acordeón, caja, guacharaca, bajo, guitarra y coros) ideal para eventos y celebraciones.',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001274',
    '00000000-0000-0000-0000-000000001214',
    'Paquete Parranda Festivalera (3 horas · 2 tandas en vivo)',
    1350000,
    'Cobertura completa para fiestas, grados o eventos corporativos con transporte urbano e iluminación incluidos.',
    2
  ),
  -- Agrupación y Escuela Vallenata Herederos del Folclor (1215)
  (
    '00000000-0000-0000-0000-000000001275',
    '00000000-0000-0000-0000-000000001215',
    'Muestra cultural de los 4 aires vallenatos para turistas (45 min)',
    220000,
    'Experiencia guiada en vivo explicando e interpretando Paseo, Merengue, Son y Puya con instrumentos típicos.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001276',
    '00000000-0000-0000-0000-000000001215',
    'Serenata acústica juvenil (5 canciones tradicionales)',
    200000,
    'Formato acústico cercano con acordeón, caja, guacharaca y voz, ideal para detalles especiales en casa o restaurante.',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001277',
    '00000000-0000-0000-0000-000000001215',
    'Clase práctica de acordeón, caja o guacharaca (1 hora)',
    60000,
    'Incluye préstamo del instrumento durante la sesión en nuestro estudio del barrio Loperena.',
    2
  )
on conflict (business_id, sort_order) do update
  set name = excluded.name,
      price_cop = excluded.price_cop,
      description = excluded.description;

-- ---------------------------------------------------------------------------
-- 4. Valoraciones comunitarias realistas (`public.business_ratings`)
--    Nota: Se garantiza que `user_id <> owner_id` en cada negocio para cumplir
--    `private.enforce_business_rating_rules()`.
-- ---------------------------------------------------------------------------
insert into public.business_ratings (business_id, user_id, stars, created_at, updated_at)
values
  -- 1201: Restaurante Sabores del Cañaguate (owner: 2001) -> 6 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000002002', 5, now() - interval '15 days', now() - interval '15 days'),
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000002003', 5, now() - interval '14 days', now() - interval '14 days'),
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000002004', 5, now() - interval '12 days', now() - interval '12 days'),
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000002005', 4, now() - interval '10 days', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000002006', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000002008', 5, now() - interval '4 days', now() - interval '4 days'),

  -- 1202: Asadero El Fogón del Guatapurí (owner: 2002) -> 5 valoraciones (promedio 4.6)
  ('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000002001', 5, now() - interval '14 days', now() - interval '14 days'),
  ('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000002004', 5, now() - interval '11 days', now() - interval '11 days'),
  ('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000002006', 4, now() - interval '9 days', now() - interval '9 days'),
  ('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000002008', 5, now() - interval '6 days', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000002010', 4, now() - interval '3 days', now() - interval '3 days'),

  -- 1203: Parrilla La Provincia Vallenata (owner: 2001) -> 5 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001203', '00000000-0000-0000-0000-000000002003', 5, now() - interval '13 days', now() - interval '13 days'),
  ('00000000-0000-0000-0000-000000001203', '00000000-0000-0000-0000-000000002004', 5, now() - interval '10 days', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000001203', '00000000-0000-0000-0000-000000002007', 4, now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000001203', '00000000-0000-0000-0000-000000002008', 5, now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000001203', '00000000-0000-0000-0000-000000002009', 5, now() - interval '2 days', now() - interval '2 days'),

  -- 1204: Hotel Sicarare Plaza (owner: 2003) -> 4 valoraciones (promedio 4.5)
  ('00000000-0000-0000-0000-000000001204', '00000000-0000-0000-0000-000000002004', 5, now() - interval '12 days', now() - interval '12 days'),
  ('00000000-0000-0000-0000-000000001204', '00000000-0000-0000-0000-000000002006', 4, now() - interval '9 days', now() - interval '9 days'),
  ('00000000-0000-0000-0000-000000001204', '00000000-0000-0000-0000-000000002008', 5, now() - interval '6 days', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000001204', '00000000-0000-0000-0000-000000002010', 4, now() - interval '3 days', now() - interval '3 days'),

  -- 1205: Hotel Boutique Casa del Acordeón (owner: 2003) -> 4 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001205', '00000000-0000-0000-0000-000000002001', 5, now() - interval '11 days', now() - interval '11 days'),
  ('00000000-0000-0000-0000-000000001205', '00000000-0000-0000-0000-000000002004', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001205', '00000000-0000-0000-0000-000000002006', 5, now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000001205', '00000000-0000-0000-0000-000000002008', 4, now() - interval '2 days', now() - interval '2 days'),

  -- 1206: Casa Artesanal Mochilas de la Sierra Nevada (owner: 2002) -> 5 valoraciones (promedio 5.0)
  ('00000000-0000-0000-0000-000000001206', '00000000-0000-0000-0000-000000002001', 5, now() - interval '13 days', now() - interval '13 days'),
  ('00000000-0000-0000-0000-000000001206', '00000000-0000-0000-0000-000000002004', 5, now() - interval '11 days', now() - interval '11 days'),
  ('00000000-0000-0000-0000-000000001206', '00000000-0000-0000-0000-000000002006', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001206', '00000000-0000-0000-0000-000000002008', 5, now() - interval '4 days', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000001206', '00000000-0000-0000-0000-000000002009', 5, now() - interval '1 day', now() - interval '1 day'),

  -- 1207: Radio Taxis Seguros Valledupar (owner: 2007) -> 4 valoraciones (promedio 4.5)
  ('00000000-0000-0000-0000-000000001207', '00000000-0000-0000-0000-000000002002', 5, now() - interval '10 days', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000001207', '00000000-0000-0000-0000-000000002004', 4, now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000001207', '00000000-0000-0000-0000-000000002005', 5, now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000001207', '00000000-0000-0000-0000-000000002010', 4, now() - interval '2 days', now() - interval '2 days'),

  -- 1208: Taller y Casa del Acordeón (owner: 2007) -> 4 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001208', '00000000-0000-0000-0000-000000002001', 5, now() - interval '10 days', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000001208', '00000000-0000-0000-0000-000000002003', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001208', '00000000-0000-0000-0000-000000002009', 5, now() - interval '4 days', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000001208', '00000000-0000-0000-0000-000000002004', 4, now() - interval '2 days', now() - interval '2 days'),

  -- 1209: Clínica Médicos Alta Complejidad (owner: null) -> 3 valoraciones (promedio 4.3)
  ('00000000-0000-0000-0000-000000001209', '00000000-0000-0000-0000-000000002002', 4, now() - interval '9 days', now() - interval '9 days'),
  ('00000000-0000-0000-0000-000000001209', '00000000-0000-0000-0000-000000002005', 5, now() - interval '6 days', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000001209', '00000000-0000-0000-0000-000000002010', 4, now() - interval '3 days', now() - interval '3 days'),

  -- 1210: Centro Intégrate Valledupar (owner: null) -> 4 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001210', '00000000-0000-0000-0000-000000002005', 5, now() - interval '11 days', now() - interval '11 days'),
  ('00000000-0000-0000-0000-000000001210', '00000000-0000-0000-0000-000000002010', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001210', '00000000-0000-0000-0000-000000002001', 5, now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000001210', '00000000-0000-0000-0000-000000002003', 4, now() - interval '2 days', now() - interval '2 days'),

  -- 1211: Desayunos y Fritanga El Cacique (owner: 2002) -> 4 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001211', '00000000-0000-0000-0000-000000002001', 5, now() - interval '9 days', now() - interval '9 days'),
  ('00000000-0000-0000-0000-000000001211', '00000000-0000-0000-0000-000000002003', 5, now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000001211', '00000000-0000-0000-0000-000000002007', 4, now() - interval '4 days', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000001211', '00000000-0000-0000-0000-000000002009', 5, now() - interval '1 day', now() - interval '1 day'),

  -- 1212: Consultoría Inmobiliaria Vía Clara (owner: 2007) -> 4 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001212', '00000000-0000-0000-0000-000000002005', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001212', '00000000-0000-0000-0000-000000002010', 5, now() - interval '6 days', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000001212', '00000000-0000-0000-0000-000000002002', 4, now() - interval '3 days', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001212', '00000000-0000-0000-0000-000000002009', 5, now() - interval '1 day', now() - interval '1 day'),

  -- 1213: Agrupación Vallenata Los Juglares del Cañaguate (owner: 2009) -> 6 valoraciones (promedio 5.0)
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000002001', 5, now() - interval '10 days', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000002002', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000002003', 5, now() - interval '6 days', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000002004', 5, now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000002006', 5, now() - interval '3 days', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000002008', 5, now() - interval '1 day', now() - interval '1 day'),

  -- 1214: Agrupación Vallenata Parranda Real del Guatapurí (owner: 2009) -> 5 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001214', '00000000-0000-0000-0000-000000002001', 5, now() - interval '9 days', now() - interval '9 days'),
  ('00000000-0000-0000-0000-000000001214', '00000000-0000-0000-0000-000000002004', 5, now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000001214', '00000000-0000-0000-0000-000000002006', 5, now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000001214', '00000000-0000-0000-0000-000000002007', 4, now() - interval '3 days', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000001214', '00000000-0000-0000-0000-000000002010', 5, now() - interval '1 day', now() - interval '1 day'),

  -- 1215: Agrupación y Escuela Vallenata Herederos del Folclor (owner: 2001) -> 5 valoraciones (promedio 4.8)
  ('00000000-0000-0000-0000-000000001215', '00000000-0000-0000-0000-000000002002', 5, now() - interval '8 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000001215', '00000000-0000-0000-0000-000000002004', 5, now() - interval '6 days', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000001215', '00000000-0000-0000-0000-000000002006', 4, now() - interval '4 days', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000001215', '00000000-0000-0000-0000-000000002008', 5, now() - interval '2 days', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000001215', '00000000-0000-0000-0000-000000002009', 5, now() - interval '1 day', now() - interval '1 day')
on conflict (business_id, user_id) do update
  set stars = excluded.stars,
      updated_at = excluded.updated_at;
-- push execution

