-- ============================================================================
-- Seed 10 · Enriquecimiento de catálogo, horarios y platos/servicios (VJ-17)
-- ============================================================================
-- Completa los negocios DEMO de Valledupar (`20001`, creados en `08_businesses_demo.sql`)
-- con horarios estructurados (`hours`), enlace externo de carta (`order_url`) y
-- platos/servicios destacados (`public.business_dishes`) para las vistas de
-- Catálogo y Detalle de Negocios (VJ-17).
-- ============================================================================

-- 1. Horarios estructurados y enlaces externos de referencia
update public.businesses
set hours = '{"mon":[{"open":"00:00","close":"24:00"}],"tue":[{"open":"00:00","close":"24:00"}],"wed":[{"open":"00:00","close":"24:00"}],"thu":[{"open":"00:00","close":"24:00"}],"fri":[{"open":"00:00","close":"24:00"}],"sat":[{"open":"00:00","close":"24:00"}],"sun":[{"open":"00:00","close":"24:00"}]}'::jsonb,
    publication_consent_at = coalesce(publication_consent_at, now())
where id = '00000000-0000-0000-0000-000000000801';

update public.businesses
set hours = '{"mon":[{"open":"07:30","close":"17:30"}],"tue":[{"open":"07:30","close":"17:30"}],"wed":[{"open":"07:30","close":"17:30"}],"thu":[{"open":"07:30","close":"17:30"}],"fri":[{"open":"07:30","close":"17:30"}],"sat":[{"open":"08:00","close":"12:30"}],"sun":[]}'::jsonb,
    publication_consent_at = coalesce(publication_consent_at, now())
where id = '00000000-0000-0000-0000-000000000802';

update public.businesses
set hours = '{"mon":[{"open":"08:00","close":"12:00"},{"open":"14:00","close":"17:00"}],"tue":[{"open":"08:00","close":"12:00"},{"open":"14:00","close":"17:00"}],"wed":[{"open":"08:00","close":"12:00"},{"open":"14:00","close":"17:00"}],"thu":[{"open":"08:00","close":"12:00"},{"open":"14:00","close":"17:00"}],"fri":[{"open":"08:00","close":"12:00"},{"open":"14:00","close":"16:30"}],"sat":[],"sun":[]}'::jsonb,
    publication_consent_at = coalesce(publication_consent_at, now())
where id = '00000000-0000-0000-0000-000000000803';

update public.businesses
set hours = '{"mon":[{"open":"11:30","close":"15:30"}],"tue":[{"open":"11:30","close":"15:30"}],"wed":[{"open":"11:30","close":"15:30"}],"thu":[{"open":"11:30","close":"15:30"}],"fri":[{"open":"11:30","close":"21:00"}],"sat":[{"open":"11:30","close":"21:30"}],"sun":[{"open":"11:30","close":"16:30"}]}'::jsonb,
    order_url = 'https://www.valledupar-gastronomia-demo.co/carta-pilon-vallenato',
    publication_consent_at = coalesce(publication_consent_at, now())
where id = '00000000-0000-0000-0000-000000000804';

update public.businesses
set hours = '{"mon":[{"open":"06:00","close":"23:00"}],"tue":[{"open":"06:00","close":"23:00"}],"wed":[{"open":"06:00","close":"23:00"}],"thu":[{"open":"06:00","close":"23:00"}],"fri":[{"open":"06:00","close":"23:30"}],"sat":[{"open":"06:00","close":"23:30"}],"sun":[{"open":"07:00","close":"22:00"}]}'::jsonb,
    publication_consent_at = coalesce(publication_consent_at, now())
where id = '00000000-0000-0000-0000-000000000805';

-- 2. Platos y servicios destacados (`public.business_dishes`)
insert into public.business_dishes (
  id,
  business_id,
  name,
  price_cop,
  description,
  sort_order
)
values
  (
    '00000000-0000-0000-0000-000000001001',
    '00000000-0000-0000-0000-000000000804',
    '[DEMO] Almuerzo ejecutivo vallenato (Corrientazo)',
    15000,
    'Sopa del día, proteína asada, arroz con fideo, patacón, ensalada y guarapo.',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001002',
    '00000000-0000-0000-0000-000000000804',
    '[DEMO] Sancocho de gallina criolla',
    22000,
    'Porción tradicional servida con arroz blanco, aguacate y picante casero.',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001003',
    '00000000-0000-0000-0000-000000000804',
    '[DEMO] Chivo guisado con arroz de camarón',
    28000,
    'Plato típico cesarense acompañado de yuca cocida y suero costeño.',
    2
  ),
  (
    '00000000-0000-0000-0000-000000001004',
    '00000000-0000-0000-0000-000000000805',
    '[DEMO] Habitación estándar sencilla (1 noche)',
    95000,
    'Aire acondicionado, Wi-Fi y desayuno típico incluido (temporada ordinaria).',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001005',
    '00000000-0000-0000-0000-000000000805',
    '[DEMO] Habitación doble acomodación (1 noche)',
    145000,
    'Para dos personas con aire acondicionado, baño privado y desayuno.',
    1
  )
on conflict (business_id, sort_order) do update
  set name = excluded.name,
      price_cop = excluded.price_cop,
      description = excluded.description;
