-- ============================================================================
-- Seed 02 · Municipios del Cesar (25) con Valledupar como piloto
-- ============================================================================
-- Códigos DIVIPOLA de 5 dígitos. Alineados con
-- assets/data/municipalities_cesar.json para que el frontend no cambie.
-- Solo Valledupar (20001) queda con is_pilot = true.
-- ============================================================================

insert into public.municipalities (code, department_code, name, is_pilot) values
  ('20001', '20', 'Valledupar', true),
  ('20011', '20', 'Aguachica', false),
  ('20013', '20', 'Agustín Codazzi', false),
  ('20032', '20', 'Astrea', false),
  ('20045', '20', 'Becerril', false),
  ('20060', '20', 'Bosconia', false),
  ('20175', '20', 'Chimichagua', false),
  ('20178', '20', 'Chiriguaná', false),
  ('20228', '20', 'Curumaní', false),
  ('20238', '20', 'El Copey', false),
  ('20250', '20', 'El Paso', false),
  ('20295', '20', 'Gamarra', false),
  ('20310', '20', 'González', false),
  ('20383', '20', 'La Gloria', false),
  ('20400', '20', 'La Jagua de Ibirico', false),
  ('20443', '20', 'Manaure Balcón del Cesar', false),
  ('20517', '20', 'Pailitas', false),
  ('20550', '20', 'Pelaya', false),
  ('20570', '20', 'Pueblo Bello', false),
  ('20614', '20', 'Río de Oro', false),
  ('20621', '20', 'La Paz', false),
  ('20710', '20', 'San Alberto', false),
  ('20750', '20', 'San Diego', false),
  ('20770', '20', 'San Martín', false),
  ('20787', '20', 'Tamalameque', false)
on conflict (code) do update
  set department_code = excluded.department_code,
      name = excluded.name,
      is_pilot = excluded.is_pilot;
