-- ============================================================================
-- Seed 09 (VJ-15) · Contenido cultural verificable bilingüe de Valledupar (20001)
-- ============================================================================
-- Reglas de curaduría y atribución (VJ-15 / docs/fuentes-y-licencias.md §3):
--   * Toda tarjeta cuenta con fuente oficial o institucional verificable
--     (`source_citation` y `source_url` bajo esquema `https://`).
--   * Se provee paridad completa Español (`es`) e Inglés (`en`) mediante `slug`.
--   * No se incluyen imágenes sin licencia verificada (`image_path = null` a
--     menos que exista `image_license` explícita).
--   * Los eventos reales llevan `is_demo = false` y sus fechas oficiales reales;
--     nunca se simula que el Festival Vallenato está activo fuera de su ventana.
-- ============================================================================

insert into public.city_content (
  municipality_code,
  locale,
  slug,
  section,
  title,
  body,
  image_path,
  image_license,
  source_citation,
  source_url,
  sort_order,
  is_demo
)
values
  -- 1. WELCOME (ES / EN)
  (
    '20001',
    'es',
    'valledupar_welcome',
    'welcome',
    'Valledupar, Ciudad de los Santos Reyes del Valle de Upar',
    'Capital del departamento del Cesar, fundada el 6 de enero de 1550 por Hernando de Santana. Reconocida como cuna del folclor vallenato y centro agroindustrial, comercial y universitario del nororiente caribe colombiano.',
    null,
    null,
    'Alcaldía de Valledupar — Reseña histórica e institucional del municipio (DIVIPOLA 20001)',
    'https://www.valledupar-cesar.gov.co',
    1,
    false
  ),
  (
    '20001',
    'en',
    'valledupar_welcome',
    'welcome',
    'Valledupar, City of the Holy Kings of the Upar Valley',
    'Capital of the department of Cesar, founded on January 6, 1550 by Hernando de Santana. Recognized as the cradle of Vallenato folklore and an agro-industrial, commercial, and university hub in the northeastern Colombian Caribbean.',
    null,
    null,
    'Mayor''s Office of Valledupar — Institutional and historical municipality profile (DIVIPOLA 20001)',
    'https://www.valledupar-cesar.gov.co',
    1,
    false
  ),

  -- 2. CONTEXT (ES / EN)
  (
    '20001',
    'es',
    'valledupar_context',
    'context',
    'Valle entre dos sistemas montañosos y el río Guatapurí',
    'Ubicada a 169 metros sobre el nivel del mar entre la Sierra Nevada de Santa Marta al occidente y la Serranía del Perijá al oriente. Su trama urbana está articulada en cinco sectores de referencia (Norte, Centro, Sur, Oriente y Occidente) bordeados por el río Guatapurí.',
    null,
    null,
    'Instituto Geográfico Agustín Codazzi (IGAC) y DANE — Geografía del Cesar y Valledupar',
    'https://www.dane.gov.co',
    2,
    false
  ),
  (
    '20001',
    'en',
    'valledupar_context',
    'context',
    'Valley Between Two Mountain Ranges and the Guatapurí River',
    'Located at 169 meters above sea level between the Sierra Nevada de Santa Marta to the west and the Serranía del Perijá to the east. Its urban layout spans five reference zones (North, Downtown, South, East, and West) bordered by the Guatapurí River.',
    null,
    null,
    'Agustín Codazzi Geographic Institute (IGAC) and DANE — Geography of Cesar and Valledupar',
    'https://www.dane.gov.co',
    2,
    false
  ),

  -- 3. CULTURE (ES / EN)
  (
    '20001',
    'es',
    'vallenato_unesco',
    'culture',
    'Música Vallenata Tradicional y Ciudad Creativa UNESCO',
    'La música vallenata tradicional del Magdalena Grande —interpretada con caja, guacharaca y acordeón diatónico en los cuatro aires: paseo, merengue, son y puya— fue inscrita por la UNESCO en 2015 en la Lista de Patrimonio Cultural Inmaterial. En 2019, Valledupar fue designada Ciudad Creativa de la Música por la UNESCO.',
    null,
    null,
    'UNESCO — Decisión 10.COM 10.a.3 (2015) y Red de Ciudades Creativas de la UNESCO (2019)',
    'https://ich.unesco.org/es/USL/la-musica-vallenata-tradicional-del-magdalena-grande-01095',
    3,
    false
  ),
  (
    '20001',
    'en',
    'vallenato_unesco',
    'culture',
    'Traditional Vallenato Music and UNESCO Creative City',
    'Traditional Vallenato music of the Greater Magdalena region—performed with caja, guacharaca, and diatonic accordion across four rhythms: paseo, merengue, son, and puya—was inscribed by UNESCO in 2015 on the Intangible Cultural Heritage List. In 2019, Valledupar was designated a UNESCO Creative City of Music.',
    null,
    null,
    'UNESCO — Decision 10.COM 10.a.3 (2015) and UNESCO Creative Cities Network (2019)',
    'https://ich.unesco.org/en/USL/traditional-vallenato-music-of-the-greater-magdalena-region-01095',
    3,
    false
  ),

  -- 4. PLACES (ES / EN)
  (
    '20001',
    'es',
    'plaza_alfonso_lopez_y_hurtado',
    'places',
    'Plaza Alfonso López, Centro Histórico y Balneario Hurtado',
    'La Plaza Alfonso López en el Centro Histórico conserva la arquitectura republicana y colonial donde nació el Festival de la Leyenda Vallenata en 1968. Al norte oriente, el Balneario Hurtado sobre el río Guatapurí y el Parque de la Leyenda Vallenata "Consuelo Araujonoguera" integran el corredor ambiental y cultural de la ciudad.',
    null,
    null,
    'Ministerio de las Culturas, las Artes y los Saberes de Colombia — Patrimonio Urbano de Valledupar',
    'https://www.mincultura.gov.co',
    4,
    false
  ),
  (
    '20001',
    'en',
    'plaza_alfonso_lopez_y_hurtado',
    'places',
    'Alfonso López Square, Historic Center, and Hurtado Riverfront',
    'Alfonso López Square in the Historic Center preserves the colonial and republican architecture where the Vallenato Legend Festival began in 1968. To the northeast, the Hurtado riverfront along the Guatapurí River and the "Consuelo Araujonoguera" Vallenato Legend Park form the city''s main cultural and environmental corridor.',
    null,
    null,
    'Ministry of Cultures, Arts, and Knowledge of Colombia — Urban Heritage of Valledupar',
    'https://www.mincultura.gov.co',
    4,
    false
  ),

  -- 5. GASTRONOMY (ES / EN)
  (
    '20001',
    'es',
    'gastronomia_tradicional_cesar',
    'gastronomy',
    'Gastronomía tradicional del valle del Cacique Upar',
    'La cocina local destaca por el sancocho de gallina criolla en fogón de leña, el chivo guisado o asado acompañado de bollo limpio y yuca, el arroz de fideo con carne molida y los amasijos tradicionales como las almojábanas y chiricanas de maíz y queso costeño.',
    null,
    null,
    'Ministerio de Cultura — Biblioteca Básica de Cocinas Tradicionales de Colombia (Región Caribe / Cesar)',
    'https://www.mincultura.gov.co',
    5,
    false
  ),
  (
    '20001',
    'en',
    'gastronomia_tradicional_cesar',
    'gastronomy',
    'Traditional Cuisine of the Cacique Upar Valley',
    'Local gastronomy features wood-fired creole hen sancocho, stewed or roasted goat served with bollo limpio and cassava, vermicelli rice with ground beef, and traditional corn and coastal-cheese baked goods such as almojábanas and chiricanas.',
    null,
    null,
    'Ministry of Culture — Basic Library of Traditional Colombian Cuisines (Caribbean / Cesar Region)',
    'https://www.mincultura.gov.co',
    5,
    false
  ),

  -- 6. EMERGENCY & CIVIC GUIDANCE (ES / EN)
  (
    '20001',
    'es',
    'lineas_atencion_y_emergencia_vup',
    'emergency',
    'Líneas de emergencia y orientación institucional en Valledupar',
    'Para emergencias médicas, policiales o de tránsito está habilitada la Línea Única Nacional 123 (24 horas). Para orientación en derechos ciudadanos, arrendamiento o atención a población migrante, acuda a la Personería Municipal de Valledupar o a la Defensoría del Pueblo Regional Cesar.',
    null,
    null,
    'Alcaldía de Valledupar / Defensoría del Pueblo Regional Cesar — Directorio de Atención Ciudadana',
    'https://www.defensoria.gov.co',
    6,
    false
  ),
  (
    '20001',
    'en',
    'lineas_atencion_y_emergencia_vup',
    'emergency',
    'Emergency Hotlines and Institutional Guidance in Valledupar',
    'For medical, police, or traffic emergencies, dial the National Emergency Hotline 123 (24/7). For civic rights guidance, housing inquiries, or migrant support, contact the Municipal Ombudsman (Personería de Valledupar) or the Regional Ombudsman''s Office (Defensoría del Pueblo Regional Cesar).',
    null,
    null,
    'Mayor''s Office of Valledupar / Regional Ombudsman''s Office of Cesar — Citizen Service Directory',
    'https://www.defensoria.gov.co',
    6,
    false
  )
on conflict (municipality_code, locale, section, title) do update
  set slug = excluded.slug,
      body = excluded.body,
      image_path = excluded.image_path,
      image_license = excluded.image_license,
      source_citation = excluded.source_citation,
      source_url = excluded.source_url,
      sort_order = excluded.sort_order,
      is_demo = excluded.is_demo;

-- ---------------------------------------------------------------------------
-- Evento oficial anual verificable (Festival de la Leyenda Vallenata)
-- ---------------------------------------------------------------------------
-- Se registra en su ventana real de abril-mayo (`is_demo = false`) para que
-- `get_city_events_status` informe honestamente su estado temporal (`upcoming`
-- o `past` fuera de abril-mayo) sin afirmar jamás que está activo en otra época.
insert into public.events (
  municipality_code,
  name,
  description_es,
  description_en,
  venue,
  starts_at,
  ends_at,
  is_demo,
  source_citation
)
select
  '20001',
  'Festival de la Leyenda Vallenata (Edición Anual Oficial)',
  'Certamen folclórico anual de acordeoneros, verseadores y canciones inéditas en Valledupar. Se celebra oficialmente a finales de abril.',
  'Annual folkloric contest of accordionists, traditional improvisors, and unreleased songs in Valledupar. Officially held in late April.',
  'Parque de la Leyenda Vallenata Consuelo Araujonoguera y Plaza Alfonso López',
  '2027-04-28 00:00:00-05'::timestamptz,
  '2027-05-02 23:59:59-05'::timestamptz,
  false,
  'Fundación Festival de la Leyenda Vallenata — Programación anual oficial'
where not exists (
  select 1
  from public.events
  where municipality_code = '20001'
    and name = 'Festival de la Leyenda Vallenata (Edición Anual Oficial)'
);
