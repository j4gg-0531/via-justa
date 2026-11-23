-- ============================================================================
-- Seed 13 · Reportes ciudadanos variados de precios por zona (Valledupar 20001)
-- ============================================================================
-- Completa cobertura estadística (N >= 3) en las 5 zonas de Valledupar
-- (`vup_centro`, `vup_norte`, `vup_sur`, `vup_oriente`, `vup_occidente`) y en
-- las 9 categorías activas, incorporando variación realista (precios justos,
-- moderados y algunas alertas de sobrecobro) asociados a los usuarios semilla
-- (`2001`..`2010`) para enriquecer el Mapa, el Semáforo, el Planificador de
-- Presupuesto y "Mi actividad → Aportes".
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
  -- 1. TAXI URBANO (transport_taxi_minimal) · 12 reportes variados (3 rangos)
  -- ==========================================================================
  -- Cortos (0_2_km)
  ('00000000-0000-0000-0000-000000003001', '00000000-0000-0000-0000-000000002004', 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_centro', 8000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.476), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.249, 10.474), 4326)::extensions.geography,
    0.59, '0_2_km', 'Plaza Alfonso López → Barrio Loperena', false, false, false, 'Reporte ciudadano taxi corto', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000003002', '00000000-0000-0000-0000-000000002006', 'transport_taxi_minimal', '20001', 'vup_norte', 'vup_norte', 9000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.487), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.256, 10.491), 4326)::extensions.geography,
    0.62, '0_2_km', 'Novalito → CC Guatapurí Plaza', false, false, false, 'Reporte ciudadano taxi corto Norte', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003003', '00000000-0000-0000-0000-000000002008', 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_norte', 10500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.486), 4326)::extensions.geography,
    1.39, '0_2_km', 'Carrera 9 → San Joaquín (nocturno)', false, false, false, 'Tarifa nocturna moderada', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003004', '00000000-0000-0000-0000-000000002004', 'transport_taxi_minimal', '20001', 'vup_oriente', 'vup_norte', 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.260, 10.497), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.488), 4326)::extensions.geography,
    1.26, '0_2_km', 'Balneario Hurtado → Novalito (cobro elevado)', false, false, false, 'Alerta de sobrecobro en salida de balneario', now() - interval '4 days'),

  -- Medios (2_5_km)
  ('00000000-0000-0000-0000-000000003005', '00000000-0000-0000-0000-000000002005', 'transport_taxi_minimal', '20001', 'vup_sur', 'vup_norte', 12000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.448), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.485), 4326)::extensions.geography,
    4.14, '2_5_km', 'Mayales → Novalito', false, false, false, 'Reporte ciudadano taxi medio', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003006', '00000000-0000-0000-0000-000000002010', 'transport_taxi_minimal', '20001', 'vup_occidente', 'vup_centro', 11500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.277, 10.468), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.475), 4326)::extensions.geography,
    3.59, '2_5_km', 'Avenida Fundación → Centro Histórico', false, false, false, 'Reporte ciudadano taxi medio Occidente', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003007', '00000000-0000-0000-0000-000000002003', 'transport_taxi_minimal', '20001', 'vup_centro', 'vup_oriente', 13000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.475), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.498), 4326)::extensions.geography,
    3.04, '2_5_km', 'Hotel Sicarare → Parque de la Leyenda', false, false, false, 'Carrera hacia el Parque de la Leyenda', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003008', '00000000-0000-0000-0000-000000002008', 'transport_taxi_minimal', '20001', 'vup_sur', 'vup_centro', 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.476), 4326)::extensions.geography,
    3.46, '2_5_km', 'Terminal → Plaza Alfonso López (sobrecobro)', false, false, false, 'Cobro excesivo reportado a visitante', now() - interval '7 days'),

  -- Largos (gt_5_km)
  ('00000000-0000-0000-0000-000000003009', '00000000-0000-0000-0000-000000002001', 'transport_taxi_minimal', '20001', 'vup_occidente', 'vup_norte', 15500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.283, 10.466), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.492), 4326)::extensions.geography,
    4.45, '2_5_km', 'La Nevada → Guatapurí Plaza', false, false, false, 'Recorrido transversal de día', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000003010', '00000000-0000-0000-0000-000000002006', 'transport_taxi_minimal', '20001', 'vup_sur', 'vup_oriente', 16500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.249, 10.439), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.499), 4326)::extensions.geography,
    6.82, 'gt_5_km', 'Aeropuerto Alfonso López → Balneario Hurtado', false, false, false, 'Trayecto largo norte-sur', now() - interval '9 days'),
  ('00000000-0000-0000-0000-000000003011', '00000000-0000-0000-0000-000000002007', 'transport_taxi_minimal', '20001', 'vup_occidente', 'vup_sur', 17500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.284, 10.474), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.440), 4326)::extensions.geography,
    5.61, 'gt_5_km', 'Ciudadela 450 Años → Aeropuerto', false, false, false, 'Carrera larga hacia zona sur', now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000003012', '00000000-0000-0000-0000-000000002008', 'transport_taxi_minimal', '20001', 'vup_oriente', 'vup_sur', 25000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.500), 4326)::extensions.geography,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.442), 4326)::extensions.geography,
    6.61, 'gt_5_km', 'Río Guatapurí → Aeropuerto (fin de semana)', false, false, false, 'Alerta sobrecobro horario nocturno', now() - interval '11 days'),

  -- ==========================================================================
  -- 2. TRASLADO AEROPUERTO / TERMINAL (transport_airport_transfer) · 14 reportes
  -- ==========================================================================
  -- Centro (+2 variados)
  ('00000000-0000-0000-0000-000000003013', '00000000-0000-0000-0000-000000002004', 'transport_airport_transfer', '20001', 'vup_centro', null, 21000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.475), 4326)::extensions.geography, null, null, null,
    'Hotel Sicarare → Aeropuerto Alfonso López', false, false, false, 'Tarifa justa acordada', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000003014', '00000000-0000-0000-0000-000000002008', 'transport_airport_transfer', '20001', 'vup_centro', null, 34000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.477), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Plaza Alfonso López (cobro turista)', false, false, false, 'Alerta de sobrecobro en llegada de vuelo', now() - interval '5 days'),

  -- Norte (3 reportes -> mediana 26.000)
  ('00000000-0000-0000-0000-000000003015', '00000000-0000-0000-0000-000000002003', 'transport_airport_transfer', '20001', 'vup_norte', null, 25000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.488), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Casa del Acordeón Novalito', false, false, false, 'Traslado con taxista autorizado', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003016', '00000000-0000-0000-0000-000000002006', 'transport_airport_transfer', '20001', 'vup_norte', null, 26000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.255, 10.491), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → CC Guatapurí Plaza', false, false, false, 'Traslado diurno normal', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003017', '00000000-0000-0000-0000-000000002008', 'transport_airport_transfer', '20001', 'vup_norte', null, 38000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.486), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → San Joaquín (noche)', false, false, false, 'Alerta de tarifa elevada en vuelo nocturno', now() - interval '7 days'),

  -- Sur (3 reportes -> mediana 16.000)
  ('00000000-0000-0000-0000-000000003018', '00000000-0000-0000-0000-000000002007', 'transport_airport_transfer', '20001', 'vup_sur', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.445), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Terminal de Transportes', false, false, false, 'Traslado corto zona sur', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003019', '00000000-0000-0000-0000-000000002005', 'transport_airport_transfer', '20001', 'vup_sur', null, 16000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.451), 4326)::extensions.geography, null, null, null,
    'Terminal → Sector Mayales Plaza', false, false, false, 'Tarifa estándar', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003020', '00000000-0000-0000-0000-000000002010', 'transport_airport_transfer', '20001', 'vup_sur', null, 19500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.250, 10.447), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Barrio Fundadores Sur', false, false, false, 'Recargo moderado con equipaje', now() - interval '9 days'),

  -- Oriente (3 reportes -> mediana 28.000)
  ('00000000-0000-0000-0000-000000003021', '00000000-0000-0000-0000-000000002004', 'transport_airport_transfer', '20001', 'vup_oriente', null, 27000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.498), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Balneario Hurtado', false, false, false, 'Traslado directo hacia el río', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003022', '00000000-0000-0000-0000-000000002002', 'transport_airport_transfer', '20001', 'vup_oriente', null, 28000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.259, 10.495), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Parque de la Leyenda', false, false, false, 'Tarifa habitual zona turística', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003023', '00000000-0000-0000-0000-000000002006', 'transport_airport_transfer', '20001', 'vup_oriente', null, 33000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.263, 10.500), 4326)::extensions.geography, null, null, null,
    'Terminal → Ribera Guatapurí (puente festivo)', false, false, false, 'Variación moderada en festivo', now() - interval '11 days'),

  -- Occidente (3 reportes -> mediana 22.000)
  ('00000000-0000-0000-0000-000000003024', '00000000-0000-0000-0000-000000002005', 'transport_airport_transfer', '20001', 'vup_occidente', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.278, 10.468), 4326)::extensions.geography, null, null, null,
    'Terminal → La Nevada', false, false, false, 'Tarifa justa pactada', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003025', '00000000-0000-0000-0000-000000002010', 'transport_airport_transfer', '20001', 'vup_occidente', null, 22000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.281, 10.471), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Ciudadela 450 Años', false, false, false, 'Traslado diurno normal', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000003026', '00000000-0000-0000-0000-000000002002', 'transport_airport_transfer', '20001', 'vup_occidente', null, 26000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.275, 10.465), 4326)::extensions.geography, null, null, null,
    'Aeropuerto → Sabanas del Valle', false, false, false, 'Recargo leve nocturno', now() - interval '12 days'),

  -- ==========================================================================
  -- 3. ALMUERZO EJECUTIVO / CORRIENTE (food_corrientazo) · 10 reportes variados
  -- ==========================================================================
  ('00000000-0000-0000-0000-000000003027', '00000000-0000-0000-0000-000000002001', 'food_corrientazo', '20001', 'vup_centro', null, 16000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.476), 4326)::extensions.geography, null, null, null,
    'Sabores del Cañaguate · Menú del día', false, false, false, 'Almuerzo completo con jugo de corozo', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000003028', '00000000-0000-0000-0000-000000002004', 'food_corrientazo', '20001', 'vup_centro', null, 24000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.477), 4326)::extensions.geography, null, null, null,
    'Restaurante turístico sin carta · Plaza', false, false, false, 'Alerta: sobrecobro en almuerzo corriente', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003029', '00000000-0000-0000-0000-000000002003', 'food_corrientazo', '20001', 'vup_norte', null, 19000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.486), 4326)::extensions.geography, null, null, null,
    'Comedor Ejecutivo Novalito', false, false, false, 'Ejecutivo con sopa y principio', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003030', '00000000-0000-0000-0000-000000002006', 'food_corrientazo', '20001', 'vup_norte', null, 23000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.256, 10.491), 4326)::extensions.geography, null, null, null,
    'Plazoleta CC Guatapurí', false, false, false, 'Precio moderadamente superior en centro comercial', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003031', '00000000-0000-0000-0000-000000002005', 'food_corrientazo', '20001', 'vup_sur', null, 14500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.451), 4326)::extensions.geography, null, null, null,
    'Asadero Mayales', false, false, false, 'Corrientazo abundante', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003032', '00000000-0000-0000-0000-000000002007', 'food_corrientazo', '20001', 'vup_sur', null, 18500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.444), 4326)::extensions.geography, null, null, null,
    'Restaurante interno Terminal', false, false, false, 'Variación moderada dentro de terminal', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000003033', '00000000-0000-0000-0000-000000002002', 'food_corrientazo', '20001', 'vup_oriente', null, 21000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.499), 4326)::extensions.geography, null, null, null,
    'El Fogón del Guatapurí · Almuerzo', false, false, false, 'Almuerzo campestre cerca del río', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003034', '00000000-0000-0000-0000-000000002008', 'food_corrientazo', '20001', 'vup_oriente', null, 30000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.501), 4326)::extensions.geography, null, null, null,
    'Kiosco ribera Hurtado (sin lista de precios)', false, false, false, 'Alerta: sobrecobro por plato sencillo', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000003035', '00000000-0000-0000-0000-000000002010', 'food_corrientazo', '20001', 'vup_occidente', null, 13500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.277, 10.468), 4326)::extensions.geography, null, null, null,
    'Comedor Popular La Nevada', false, false, false, 'Menú casero económico', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003036', '00000000-0000-0000-0000-000000002009', 'food_corrientazo', '20001', 'vup_occidente', null, 17000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.273, 10.471), 4326)::extensions.geography, null, null, null,
    'Restaurante Garupal', false, false, false, 'Ejecutivo con proteína especial', now() - interval '9 days'),

  -- ==========================================================================
  -- 4. DESAYUNO TÍPICO (food_breakfast) · 14 reportes en todas las zonas
  -- ==========================================================================
  -- Centro (+2)
  ('00000000-0000-0000-0000-000000003037', '00000000-0000-0000-0000-000000002001', 'food_breakfast', '20001', 'vup_centro', null, 12000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.474), 4326)::extensions.geography, null, null, null,
    'Arepas y Café Calle 16', false, false, false, 'Arepa con queso, huevos y café', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000003038', '00000000-0000-0000-0000-000000002004', 'food_breakfast', '20001', 'vup_centro', null, 17500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.476), 4326)::extensions.geography, null, null, null,
    'Café Boutique Plaza Alfonso López', false, false, false, 'Desayuno turístico con sobrecosto', now() - interval '6 days'),

  -- Norte (3 -> mediana 14.000)
  ('00000000-0000-0000-0000-000000003039', '00000000-0000-0000-0000-000000002003', 'food_breakfast', '20001', 'vup_norte', null, 13000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.487), 4326)::extensions.geography, null, null, null,
    'Panadería San Joaquín', false, false, false, 'Bollo limpio con chicharrón y chocolate', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003040', '00000000-0000-0000-0000-000000002006', 'food_breakfast', '20001', 'vup_norte', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.254, 10.489), 4326)::extensions.geography, null, null, null,
    'Cafetería Los Cortijos', false, false, false, 'Desayuno vallenato completo', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003041', '00000000-0000-0000-0000-000000002008', 'food_breakfast', '20001', 'vup_norte', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.256, 10.491), 4326)::extensions.geography, null, null, null,
    'Café Guatapurí Plaza', false, false, false, 'Tarifa moderada en centro comercial', now() - interval '8 days'),

  -- Sur (3 -> mediana 10.000)
  ('00000000-0000-0000-0000-000000003042', '00000000-0000-0000-0000-000000002005', 'food_breakfast', '20001', 'vup_sur', null, 9000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.446), 4326)::extensions.geography, null, null, null,
    'Fritanga del Terminal', false, false, false, 'Carimañolas, empanadas y tinto', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003043', '00000000-0000-0000-0000-000000002007', 'food_breakfast', '20001', 'vup_sur', null, 10000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.450), 4326)::extensions.geography, null, null, null,
    'Desayunadero Mayales', false, false, false, 'Arepa con carne desmechada y jugo', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003044', '00000000-0000-0000-0000-000000002010', 'food_breakfast', '20001', 'vup_sur', null, 11500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.249, 10.444), 4326)::extensions.geography, null, null, null,
    'Cafetería Avenida Aeropuerto', false, false, false, 'Desayuno con proteína y bebida', now() - interval '7 days'),

  -- Oriente (3 -> mediana 14.000)
  ('00000000-0000-0000-0000-000000003045', '00000000-0000-0000-0000-000000002002', 'food_breakfast', '20001', 'vup_oriente', null, 13000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.498), 4326)::extensions.geography, null, null, null,
    'Parador Balneario Hurtado', false, false, false, 'Arepa de queso con café con leche', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003046', '00000000-0000-0000-0000-000000002004', 'food_breakfast', '20001', 'vup_oriente', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.260, 10.496), 4326)::extensions.geography, null, null, null,
    'Fonda Parque de la Leyenda', false, false, false, 'Desayuno típico vallenato', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003047', '00000000-0000-0000-0000-000000002006', 'food_breakfast', '20001', 'vup_oriente', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.500), 4326)::extensions.geography, null, null, null,
    'Estadero Ribera Guatapurí', false, false, false, 'Alerta: sobrecobro dominical en balneario', now() - interval '10 days'),

  -- Occidente (3 -> mediana 10.000)
  ('00000000-0000-0000-0000-000000003048', '00000000-0000-0000-0000-000000002002', 'food_breakfast', '20001', 'vup_occidente', null, 9500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.277, 10.468), 4326)::extensions.geography, null, null, null,
    'Desayunos y Fritanga El Cacique', false, false, false, 'Arepa limpia con chicharrón y peto', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000003049', '00000000-0000-0000-0000-000000002005', 'food_breakfast', '20001', 'vup_occidente', null, 10000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.281, 10.470), 4326)::extensions.geography, null, null, null,
    'Panadería La Nevada', false, false, false, 'Desayuno completo económico', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003050', '00000000-0000-0000-0000-000000002010', 'food_breakfast', '20001', 'vup_occidente', null, 11000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.274, 10.466), 4326)::extensions.geography, null, null, null,
    'Arepas Ciudadela 450 Años', false, false, false, 'Bollo con queso costeño y jugo', now() - interval '8 days'),

  -- ==========================================================================
  -- 5. HABITACIÓN ESTÁNDAR NOCHE (lodging_standard_night) · 10 reportes nuevos
  -- ==========================================================================
  -- Oriente (3 -> mediana 110.000)
  ('00000000-0000-0000-0000-000000003051', '00000000-0000-0000-0000-000000002004', 'lodging_standard_night', '20001', 'vup_oriente', null, 100000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.260, 10.495), 4326)::extensions.geography, null, null, null,
    'Posada Turística Hurtado', false, false, false, 'Habitación estándar con aire', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003052', '00000000-0000-0000-0000-000000002006', 'lodging_standard_night', '20001', 'vup_oriente', null, 110000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.498), 4326)::extensions.geography, null, null, null,
    'Hotel Campestre Río Guatapurí', false, false, false, 'Noche con desayuno incluido', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003053', '00000000-0000-0000-0000-000000002008', 'lodging_standard_night', '20001', 'vup_oriente', null, 155000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.259, 10.497), 4326)::extensions.geography, null, null, null,
    'Alojamiento Parque de la Leyenda (evento)', false, false, false, 'Alerta: tarifa inflada fin de semana', now() - interval '9 days'),

  -- Occidente (3 -> mediana 68.000)
  ('00000000-0000-0000-0000-000000003054', '00000000-0000-0000-0000-000000002005', 'lodging_standard_night', '20001', 'vup_occidente', null, 62000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.278, 10.468), 4326)::extensions.geography, null, null, null,
    'Hospedaje La Nevada', false, false, false, 'Habitación limpia económica', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003055', '00000000-0000-0000-0000-000000002010', 'lodging_standard_night', '20001', 'vup_occidente', null, 68000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.274, 10.469), 4326)::extensions.geography, null, null, null,
    'Residencias Avenida Fundación', false, false, false, 'Noche estándar con ventilador/aire', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003056', '00000000-0000-0000-0000-000000002009', 'lodging_standard_night', '20001', 'vup_occidente', null, 75000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.280, 10.472), 4326)::extensions.geography, null, null, null,
    'Hotel Familiar Garupal', false, false, false, 'Habitación doble tranquila', now() - interval '10 days'),

  -- Variación extra en Centro, Norte y Sur (4)
  ('00000000-0000-0000-0000-000000003057', '00000000-0000-0000-0000-000000002004', 'lodging_standard_night', '20001', 'vup_centro', null, 125000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.475), 4326)::extensions.geography, null, null, null,
    'Hotel Boutique Centro Histórico', false, false, false, 'Alerta: tarifa muy superior a mediana zonal', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003058', '00000000-0000-0000-0000-000000002003', 'lodging_standard_night', '20001', 'vup_norte', null, 120000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.488), 4326)::extensions.geography, null, null, null,
    'Casa del Acordeón Novalito · Estándar', false, false, false, 'Habitación climatizada con parqueadero', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003059', '00000000-0000-0000-0000-000000002008', 'lodging_standard_night', '20001', 'vup_norte', null, 150000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.255, 10.491), 4326)::extensions.geography, null, null, null,
    'Hotel Zona Rosa Norte (sin reserva)', false, false, false, 'Alerta: sobrecobro en recepción', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000003060', '00000000-0000-0000-0000-000000002005', 'lodging_standard_night', '20001', 'vup_sur', null, 92000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.448), 4326)::extensions.geography, null, null, null,
    'Hotel Ejecutivo Mayales', false, false, false, 'Variación moderada frente al promedio sur', now() - interval '8 days'),

  -- ==========================================================================
  -- 6. LAVANDERÍA (services_laundry_load) · 12 reportes (todas las zonas)
  -- ==========================================================================
  -- Sur (3 -> mediana 16.000)
  ('00000000-0000-0000-0000-000000003061', '00000000-0000-0000-0000-000000002005', 'services_laundry_load', '20001', 'vup_sur', null, 15000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.446), 4326)::extensions.geography, null, null, null,
    'Lavandería Express Terminal', false, false, false, 'Carga completa lavado y secado', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003062', '00000000-0000-0000-0000-000000002007', 'services_laundry_load', '20001', 'vup_sur', null, 16000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.450), 4326)::extensions.geography, null, null, null,
    'Lavaseco Mayales', false, false, false, 'Tarifa justa del sector', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003063', '00000000-0000-0000-0000-000000002010', 'services_laundry_load', '20001', 'vup_sur', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.249, 10.448), 4326)::extensions.geography, null, null, null,
    'Lavandería San Martín', false, false, false, 'Incluye doblado el mismo día', now() - interval '8 days'),

  -- Oriente (3 -> mediana 20.000)
  ('00000000-0000-0000-0000-000000003064', '00000000-0000-0000-0000-000000002004', 'services_laundry_load', '20001', 'vup_oriente', null, 19000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.259, 10.494), 4326)::extensions.geography, null, null, null,
    'Lavandería Las Flores', false, false, false, 'Servicio estándar 1 carga', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003065', '00000000-0000-0000-0000-000000002006', 'services_laundry_load', '20001', 'vup_oriente', null, 20000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.497), 4326)::extensions.geography, null, null, null,
    'Lavaseco Sector Hurtado', false, false, false, 'Lavado y secado rápido', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003066', '00000000-0000-0000-0000-000000002008', 'services_laundry_load', '20001', 'vup_oriente', null, 28000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.499), 4326)::extensions.geography, null, null, null,
    'Lavandería Hotelera Oriente', false, false, false, 'Alerta: cobro elevado por carga', now() - interval '9 days'),

  -- Occidente (3 -> mediana 15.000)
  ('00000000-0000-0000-0000-000000003067', '00000000-0000-0000-0000-000000002002', 'services_laundry_load', '20001', 'vup_occidente', null, 14000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.279, 10.468), 4326)::extensions.geography, null, null, null,
    'Lavandería La Nevada', false, false, false, 'Servicio económico por carga', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003068', '00000000-0000-0000-0000-000000002010', 'services_laundry_load', '20001', 'vup_occidente', null, 15000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.276, 10.470), 4326)::extensions.geography, null, null, null,
    'Lavaseco Ciudadela 450 Años', false, false, false, 'Precio justo de barrio', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003069', '00000000-0000-0000-0000-000000002005', 'services_laundry_load', '20001', 'vup_occidente', null, 16500,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.273, 10.467), 4326)::extensions.geography, null, null, null,
    'Lavandería Los Fundadores', false, false, false, 'Carga grande con suavizante', now() - interval '10 days'),

  -- Extra Centro y Norte (3)
  ('00000000-0000-0000-0000-000000003070', '00000000-0000-0000-0000-000000002004', 'services_laundry_load', '20001', 'vup_centro', null, 25000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.476), 4326)::extensions.geography, null, null, null,
    'Lavaseco Express Plaza', false, false, false, 'Alerta: sobrecobro servicio exprés', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003071', '00000000-0000-0000-0000-000000002003', 'services_laundry_load', '20001', 'vup_norte', null, 24000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.255, 10.490), 4326)::extensions.geography, null, null, null,
    'Lavandería Premium Norte', false, false, false, 'Precio moderadamente superior', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003072', '00000000-0000-0000-0000-000000002009', 'services_laundry_load', '20001', 'vup_centro', null, 18000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.474), 4326)::extensions.geography, null, null, null,
    'Lavandería Barrio Loperena', false, false, false, 'Tarifa habitual del centro', now() - interval '7 days'),

  -- ==========================================================================
  -- 7. ARRIENDO HABITACIÓN MENSUAL (housing_room_monthly) · 14 reportes
  -- ==========================================================================
  -- Centro (+2)
  ('00000000-0000-0000-0000-000000003073', '00000000-0000-0000-0000-000000002005', 'housing_room_monthly', '20001', 'vup_centro', null, 430000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.248, 10.475), 4326)::extensions.geography, null, null, null,
    'Habitación amoblada Barrio Loperena', false, false, false, 'Con servicios y wifi incluidos', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003074', '00000000-0000-0000-0000-000000002010', 'housing_room_monthly', '20001', 'vup_centro', null, 600000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.476), 4326)::extensions.geography, null, null, null,
    'Habitación Centro sin contrato escrito', false, false, false, 'Alerta: canon inflado para recién llegado', now() - interval '7 days'),

  -- Norte (3 -> mediana 540.000)
  ('00000000-0000-0000-0000-000000003075', '00000000-0000-0000-0000-000000002003', 'housing_room_monthly', '20001', 'vup_norte', null, 520000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.251, 10.486), 4326)::extensions.geography, null, null, null,
    'Habitación estudiantil San Joaquín', false, false, false, 'Con baño privado y servicios', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003076', '00000000-0000-0000-0000-000000002006', 'housing_room_monthly', '20001', 'vup_norte', null, 540000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.254, 10.489), 4326)::extensions.geography, null, null, null,
    'Habitación amoblada Los Cortijos', false, false, false, 'Canon mensual justo zona norte', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003077', '00000000-0000-0000-0000-000000002010', 'housing_room_monthly', '20001', 'vup_norte', null, 650000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.488), 4326)::extensions.geography, null, null, null,
    'Habitación ejecutiva Novalito', false, false, false, 'Variación moderada por aire acondicionado', now() - interval '11 days'),

  -- Sur (3 -> mediana 350.000)
  ('00000000-0000-0000-0000-000000003078', '00000000-0000-0000-0000-000000002005', 'housing_room_monthly', '20001', 'vup_sur', null, 330000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.449), 4326)::extensions.geography, null, null, null,
    'Habitación Barrio Mayales', false, false, false, 'Habitación sencilla con servicios', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003079', '00000000-0000-0000-0000-000000002007', 'housing_room_monthly', '20001', 'vup_sur', null, 350000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.446), 4326)::extensions.geography, null, null, null,
    'Habitación Sector Terminal', false, false, false, 'Canon estándar zona sur', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000003080', '00000000-0000-0000-0000-000000002010', 'housing_room_monthly', '20001', 'vup_sur', null, 390000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.250, 10.452), 4326)::extensions.geography, null, null, null,
    'Habitación Los Álamos', false, false, false, 'Con acceso a cocina compartida', now() - interval '12 days'),

  -- Oriente (3 -> mediana 450.000)
  ('00000000-0000-0000-0000-000000003081', '00000000-0000-0000-0000-000000002002', 'housing_room_monthly', '20001', 'vup_oriente', null, 430000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.259, 10.494), 4326)::extensions.geography, null, null, null,
    'Habitación Las Flores Oriente', false, false, false, 'Buen acceso a transporte', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003082', '00000000-0000-0000-0000-000000002009', 'housing_room_monthly', '20001', 'vup_oriente', null, 450000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.496), 4326)::extensions.geography, null, null, null,
    'Habitación cerca del Parque de la Leyenda', false, false, false, 'Incluye agua, luz e internet', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000003083', '00000000-0000-0000-0000-000000002004', 'housing_room_monthly', '20001', 'vup_oriente', null, 510000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.498), 4326)::extensions.geography, null, null, null,
    'Habitación amoblada Sector Hurtado', false, false, false, 'Canon en límite superior razonable', now() - interval '13 days'),

  -- Occidente (3 -> mediana 340.000)
  ('00000000-0000-0000-0000-000000003084', '00000000-0000-0000-0000-000000002005', 'housing_room_monthly', '20001', 'vup_occidente', null, 320000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.280, 10.469), 4326)::extensions.geography, null, null, null,
    'Habitación Barrio La Nevada', false, false, false, 'Opción accesible para instalación', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003085', '00000000-0000-0000-0000-000000002010', 'housing_room_monthly', '20001', 'vup_occidente', null, 340000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.276, 10.471), 4326)::extensions.geography, null, null, null,
    'Habitación Ciudadela 450 Años', false, false, false, 'Con servicios públicos básicos', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003086', '00000000-0000-0000-0000-000000002002', 'housing_room_monthly', '20001', 'vup_occidente', null, 370000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.273, 10.468), 4326)::extensions.geography, null, null, null,
    'Habitación Barrio Garupal', false, false, false, 'Baño privado y entrada independiente', now() - interval '9 days'),

  -- ==========================================================================
  -- 8. APARTAESTUDIO MENSUAL (housing_studio_monthly) · 14 reportes
  -- ==========================================================================
  -- Centro (+2)
  ('00000000-0000-0000-0000-000000003087', '00000000-0000-0000-0000-000000002001', 'housing_studio_monthly', '20001', 'vup_centro', null, 790000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.475), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Barrio Loperena', false, false, false, 'Contrato anual Ley 820', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003088', '00000000-0000-0000-0000-000000002005', 'housing_studio_monthly', '20001', 'vup_centro', null, 1100000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.244, 10.477), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Centro (canon sobrevalorado)', false, false, false, 'Alerta: muy por encima de la mediana zonal', now() - interval '8 days'),

  -- Norte (3 -> mediana 980.000)
  ('00000000-0000-0000-0000-000000003089', '00000000-0000-0000-0000-000000002003', 'housing_studio_monthly', '20001', 'vup_norte', null, 950000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.487), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Sector Novalito', false, false, false, 'Edificio con portería y parqueadero', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003090', '00000000-0000-0000-0000-000000002006', 'housing_studio_monthly', '20001', 'vup_norte', null, 980000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.255, 10.490), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Los Cortijos', false, false, false, 'Canon estándar norte de la ciudad', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003091', '00000000-0000-0000-0000-000000002010', 'housing_studio_monthly', '20001', 'vup_norte', null, 1180000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.257, 10.492), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Pontevedra', false, false, false, 'Variación moderada en conjunto cerrado', now() - interval '11 days'),

  -- Sur (3 -> mediana 640.000)
  ('00000000-0000-0000-0000-000000003092', '00000000-0000-0000-0000-000000002007', 'housing_studio_monthly', '20001', 'vup_sur', null, 600000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.450), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Mayales', false, false, false, 'Sin amoblar, servicios independientes', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003093', '00000000-0000-0000-0000-000000002005', 'housing_studio_monthly', '20001', 'vup_sur', null, 640000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.249, 10.447), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Fundadores Sur', false, false, false, 'Tarifa justa de arriendo mensual', now() - interval '7 days'),
  ('00000000-0000-0000-0000-000000003094', '00000000-0000-0000-0000-000000002010', 'housing_studio_monthly', '20001', 'vup_sur', null, 700000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.245, 10.452), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Panamá Sur', false, false, false, 'Cocina integral y balcón', now() - interval '12 days'),

  -- Oriente (3 -> mediana 820.000)
  ('00000000-0000-0000-0000-000000003095', '00000000-0000-0000-0000-000000002002', 'housing_studio_monthly', '20001', 'vup_oriente', null, 780000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.259, 10.495), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Sector Parque de la Leyenda', false, false, false, 'Zona tranquila cerca del río', now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000003096', '00000000-0000-0000-0000-000000002009', 'housing_studio_monthly', '20001', 'vup_oriente', null, 820000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.497), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Ribera Oriente', false, false, false, 'Canon estándar sector oriente', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000003097', '00000000-0000-0000-0000-000000002004', 'housing_studio_monthly', '20001', 'vup_oriente', null, 920000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.499), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Balneario Hurtado', false, false, false, 'Con aire acondicionado incluido', now() - interval '13 days'),

  -- Occidente (3 -> mediana 620.000)
  ('00000000-0000-0000-0000-000000003098', '00000000-0000-0000-0000-000000002005', 'housing_studio_monthly', '20001', 'vup_occidente', null, 580000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.281, 10.469), 4326)::extensions.geography, null, null, null,
    'Apartaestudio La Nevada', false, false, false, 'Opción económica familiar', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003099', '00000000-0000-0000-0000-000000002010', 'housing_studio_monthly', '20001', 'vup_occidente', null, 620000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.277, 10.471), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Ciudadela 450 Años', false, false, false, 'Canon habitual zona occidente', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003100', '00000000-0000-0000-0000-000000002002', 'housing_studio_monthly', '20001', 'vup_occidente', null, 680000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.274, 10.468), 4326)::extensions.geography, null, null, null,
    'Apartaestudio Sabanas del Valle', false, false, false, 'Recién remodelado con patio', now() - interval '10 days'),

  -- ==========================================================================
  -- 9. MERCADO BÁSICO SEMANAL (groceries_basic_weekly) · 14 reportes
  -- ==========================================================================
  -- Centro (+2)
  ('00000000-0000-0000-0000-000000003101', '00000000-0000-0000-0000-000000002001', 'groceries_basic_weekly', '20001', 'vup_centro', null, 130000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.243, 10.473), 4326)::extensions.geography, null, null, null,
    'Mercado Público Galería Popular', false, false, false, 'Frutas, verduras, granos y proteína semanal', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000003102', '00000000-0000-0000-0000-000000002006', 'groceries_basic_weekly', '20001', 'vup_centro', null, 165000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.475), 4326)::extensions.geography, null, null, null,
    'Supermercado de cadena Centro', false, false, false, 'Canasta moderadamente más alta que galería', now() - interval '6 days'),

  -- Norte (3 -> mediana 160.000)
  ('00000000-0000-0000-0000-000000003103', '00000000-0000-0000-0000-000000002003', 'groceries_basic_weekly', '20001', 'vup_norte', null, 150000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.252, 10.487), 4326)::extensions.geography, null, null, null,
    'Fruver y Tienda San Joaquín', false, false, false, 'Canasta semanal completa 1 persona', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003104', '00000000-0000-0000-0000-000000002006', 'groceries_basic_weekly', '20001', 'vup_norte', null, 160000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.255, 10.491), 4326)::extensions.geography, null, null, null,
    'Supermercado Guatapurí Plaza', false, false, false, 'Mercado semanal en cadena norte', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003105', '00000000-0000-0000-0000-000000002008', 'groceries_basic_weekly', '20001', 'vup_norte', null, 195000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.253, 10.489), 4326)::extensions.geography, null, null, null,
    'Minimercado Novalito Express', false, false, false, 'Precio moderadamente alto en tienda de conveniencia', now() - interval '9 days'),

  -- Sur (3 -> mediana 120.000)
  ('00000000-0000-0000-0000-000000003106', '00000000-0000-0000-0000-000000002005', 'groceries_basic_weekly', '20001', 'vup_sur', null, 115000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.247, 10.449), 4326)::extensions.geography, null, null, null,
    'Tienda de Descuento Mayales', false, false, false, 'Canasta básica muy rendidora', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003107', '00000000-0000-0000-0000-000000002007', 'groceries_basic_weekly', '20001', 'vup_sur', null, 120000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.246, 10.446), 4326)::extensions.geography, null, null, null,
    'Granero Sector Terminal', false, false, false, 'Granos, huevos, verduras y lácteos', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003108', '00000000-0000-0000-0000-000000002010', 'groceries_basic_weekly', '20001', 'vup_sur', null, 132000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.249, 10.451), 4326)::extensions.geography, null, null, null,
    'Autoservicio Fundadores', false, false, false, 'Mercado semanal completo', now() - interval '8 days'),

  -- Oriente (3 -> mediana 145.000)
  ('00000000-0000-0000-0000-000000003109', '00000000-0000-0000-0000-000000002002', 'groceries_basic_weekly', '20001', 'vup_oriente', null, 138000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.259, 10.494), 4326)::extensions.geography, null, null, null,
    'Fruver Las Flores', false, false, false, 'Frutas, tubérculos y víveres básicos', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000003110', '00000000-0000-0000-0000-000000002009', 'groceries_basic_weekly', '20001', 'vup_oriente', null, 145000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.261, 10.497), 4326)::extensions.geography, null, null, null,
    'Supermercado Sector Hurtado', false, false, false, 'Mercado estándar zona oriente', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000003111', '00000000-0000-0000-0000-000000002004', 'groceries_basic_weekly', '20001', 'vup_oriente', null, 162000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.262, 10.499), 4326)::extensions.geography, null, null, null,
    'Tienda Turística Ribera del Río', false, false, false, 'Precios ligeramente superiores por zona', now() - interval '10 days'),

  -- Occidente (3 -> mediana 122.000)
  ('00000000-0000-0000-0000-000000003112', '00000000-0000-0000-0000-000000002005', 'groceries_basic_weekly', '20001', 'vup_occidente', null, 118000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.280, 10.468), 4326)::extensions.geography, null, null, null,
    'Supermercado La Nevada', false, false, false, 'Canasta semanal accesible', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000003113', '00000000-0000-0000-0000-000000002010', 'groceries_basic_weekly', '20001', 'vup_occidente', null, 122000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.276, 10.470), 4326)::extensions.geography, null, null, null,
    'Tienda Popular Ciudadela 450 Años', false, false, false, 'Mercado básico 1 semana', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000003114', '00000000-0000-0000-0000-000000002002', 'groceries_basic_weekly', '20001', 'vup_occidente', null, 134000,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-73.273, 10.467), 4326)::extensions.geography, null, null, null,
    'Autoservicio Garupal', false, false, false, 'Canasta con carnes y lácteos', now() - interval '9 days')
on conflict (id) do update
  set user_id = excluded.user_id,
      category_id = excluded.category_id,
      municipality_code = excluded.municipality_code,
      zone_id = excluded.zone_id,
      destination_zone_id = excluded.destination_zone_id,
      amount_cop = excluded.amount_cop,
      location = excluded.location,
      destination_location = excluded.destination_location,
      distance_km = excluded.distance_km,
      distance_range = excluded.distance_range,
      place_name = excluded.place_name,
      is_seed = false,
      is_demo = false,
      is_hidden = false,
      source_note = excluded.source_note,
      created_at = excluded.created_at;
