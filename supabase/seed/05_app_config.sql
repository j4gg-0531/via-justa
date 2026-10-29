-- ============================================================================
-- Seed 05 · Configuración operativa del semáforo y cuotas de IA
-- ============================================================================
-- Estos valores viven en base de datos para poder ajustarlos sin publicar una
-- nueva versión de la app (diseñado para el cambio, §8 del plan).
-- ============================================================================

insert into public.app_config (key, value) values
  (
    'price_verdict_rules',
    '{
      "window_days": 60,
      "min_reports": 3,
      "threshold_green": 15.0,
      "threshold_yellow": 40.0,
      "underpriced_alert_threshold": -40.0,
      "recommended_cap_factor": 1.15,
      "daily_ai_limit_per_user": 5
    }'::jsonb
  )
on conflict (key) do update
  set value = excluded.value,
      updated_at = now();
