-- ============================================================================
-- Seed 06 · Evento de demostración (is_demo = true, no presentar como real)
-- ============================================================================
-- El Festival Vallenato no está en curso en noviembre de 2026. Este registro
-- existe solo para probar el contexto de evento del semáforo y la interfaz.
-- ============================================================================

insert into public.events (
  municipality_code,
  name,
  starts_at,
  ends_at,
  is_demo
)
select
  '20001',
  'Evento DEMO — Vía Justa (no real)',
  '2026-11-15 00:00:00-05'::timestamptz,
  '2026-11-20 23:59:59-05'::timestamptz,
  true
where not exists (
  select 1
  from public.events
  where municipality_code = '20001'
    and name = 'Evento DEMO — Vía Justa (no real)'
    and starts_at = '2026-11-15 00:00:00-05'::timestamptz
);
