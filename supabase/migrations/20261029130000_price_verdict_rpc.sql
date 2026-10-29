-- ============================================================================
-- Vía Justa MVP · Migración 0007 · Función SQL del Semáforo de Precios (VJ-10)
-- ============================================================================
-- Crea:
--   * public.calculate_price_verdict(p_category_id, p_municipality_code,
--     p_zone_id, p_amount_cop): única fuente de verdad estadística del
--     semáforo de precios por zona del municipio.
--   * public.evaluate_price_verdict(...): alias compatible con D15.
--
-- Regla de negocio (§5.3 del Plan Original y §3 de docs/contrato-datos-v1.md):
--   1. Requiere llamador autenticado (auth.uid() IS NOT NULL).
--   2. Valida p_amount_cop > 0 (y <= 100.000.000 COP) y la existencia de
--      categoría, municipio y zona.
--   3. Lee los parámetros dinámicos desde `public.app_config`
--      (`price_verdict_rules`: window_days=60, min_reports=3,
--      threshold_green=15.0, threshold_yellow=40.0,
--      underpriced_alert_threshold=-40.0, recommended_cap_factor=1.15).
--   4. Filtra `public.price_reports` por misma categoría, municipio y zona,
--      visibles (`is_hidden = false`), no demo (`is_demo = false`) y dentro
--      de la ventana temporal (`created_at >= now() - interval '60 days'`).
--   5. Si N < min_reports (3) -> devuelve `level = 'insufficient'` sin color
--      ni comparación de mediana.
--   6. Calcula la mediana exacta con `percentile_cont(0.5) within group
--      (order by amount_cop)` en precisión `numeric`.
--   7. Verifica si existe un evento activo no-demo en el municipio
--      (`now() between starts_at and ends_at and is_demo = false`). Si existe
--      y hay >= min_reports reportes elegibles dentro de la ventana del evento,
--      calcula la mediana del evento (`event_reference_cop`) y prioriza esa
--      referencia para el nivel mostrado, entregando ambas comparaciones.
--   8. Compara la desviación porcentual SIN redondear:
--        desv <= 15.0000 -> 'green'
--        desv <= 40.0000 -> 'yellow'
--        desv >  40.0000 -> 'red'
--        desv < -40.0000 -> `underpriced_alert = true` (sigue siendo 'green').
--   9. Calcula `recommended_cap_cop = round(referencia_vigente * 1.15)`.
-- ============================================================================

create or replace function public.calculate_price_verdict(
  p_category_id varchar,
  p_municipality_code varchar,
  p_zone_id varchar,
  p_amount_cop integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := auth.uid();
  v_rules jsonb;
  v_window_days integer := 60;
  v_min_reports integer := 3;
  v_threshold_green numeric := 15.0;
  v_threshold_yellow numeric := 40.0;
  v_underpriced_threshold numeric := -40.0;
  v_cap_factor numeric := 1.15;

  v_sample_count integer := 0;
  v_baseline_median numeric;
  v_baseline_deviation numeric;

  v_event_id uuid;
  v_event_name varchar(150);
  v_event_starts timestamptz;
  v_event_ends timestamptz;
  v_event_is_demo boolean;
  v_event_sample_count integer := 0;
  v_event_median numeric;
  v_event_deviation numeric;
  v_use_event_reference boolean := false;

  v_effective_median numeric;
  v_effective_deviation numeric;
  v_level text;
  v_underpriced_alert boolean := false;
  v_recommended_cap integer;
  v_event_details jsonb := null;
begin
  -- 1. Autorización: requiere sesión autenticada
  if v_caller_id is null then
    raise exception 'AUTH_REQUIRED: authentication is required to evaluate prices'
      using errcode = '42501';
  end if;

  -- 2. Validación de monto en COP
  if p_amount_cop is null or p_amount_cop <= 0 or p_amount_cop > 100000000 then
    raise exception 'INVALID_AMOUNT_COP: amount_cop must be between 1 and 100000000 COP'
      using errcode = '22023';
  end if;

  -- 3. Validación de catálogo (categoría activa y zona perteneciente al municipio)
  if p_category_id is null or not exists (
    select 1
    from public.price_categories c
    where c.id = p_category_id
      and c.is_active = true
  ) then
    raise exception 'INVALID_CATEGORY: category % does not exist or is inactive', p_category_id
      using errcode = '22023';
  end if;

  if p_municipality_code is null or p_zone_id is null or not exists (
    select 1
    from public.municipality_zones z
    where z.id = p_zone_id
      and z.municipality_code = p_municipality_code
      and z.is_active = true
  ) then
    raise exception 'INVALID_ZONE_OR_MUNICIPALITY: zone % does not belong to municipality %', p_zone_id, p_municipality_code
      using errcode = '22023';
  end if;

  -- 4. Lectura de parámetros dinámicos desde public.app_config
  select ac.value
  into v_rules
  from public.app_config ac
  where ac.key = 'price_verdict_rules';

  if v_rules is not null then
    v_window_days := coalesce((v_rules ->> 'window_days')::integer, v_window_days);
    v_min_reports := coalesce((v_rules ->> 'min_reports')::integer, v_min_reports);
    v_threshold_green := coalesce((v_rules ->> 'threshold_green')::numeric, v_threshold_green);
    v_threshold_yellow := coalesce((v_rules ->> 'threshold_yellow')::numeric, v_threshold_yellow);
    v_underpriced_threshold := coalesce((v_rules ->> 'underpriced_alert_threshold')::numeric, v_underpriced_threshold);
    v_cap_factor := coalesce((v_rules ->> 'recommended_cap_factor')::numeric, v_cap_factor);
  end if;

  -- 5. Conteo y mediana (percentile_cont(0.5)) de reportes elegibles en la ventana de 60 días
  select
    count(*)::integer,
    (percentile_cont(0.5) within group (order by r.amount_cop))::numeric
  into
    v_sample_count,
    v_baseline_median
  from public.price_reports r
  where r.municipality_code = p_municipality_code
    and r.zone_id = p_zone_id
    and r.category_id = p_category_id
    and r.is_hidden = false
    and r.is_demo = false
    and r.created_at >= (now() - make_interval(days => v_window_days));

  -- 6. Muestra insuficiente (N < 3 o mediana inválida): sin color ni umbrales
  if v_sample_count < v_min_reports or v_baseline_median is null or v_baseline_median <= 0 then
    return jsonb_build_object(
      'rule_version', 'v1.0',
      'level', 'insufficient',
      'category_id', p_category_id,
      'municipality_code', p_municipality_code,
      'zone_id', p_zone_id,
      'amount_cop', p_amount_cop,
      'reference_cop', null,
      'baseline_reference_cop', null,
      'deviation_percent', null,
      'baseline_deviation_percent', null,
      'sample_count', v_sample_count,
      'underpriced_alert', false,
      'recommended_cap_cop', null,
      'window_days', v_window_days,
      'is_event_context', false,
      'event_details', null,
      'is_demo', false
    );
  end if;

  v_baseline_deviation := ((p_amount_cop::numeric - v_baseline_median) / v_baseline_median) * 100.0;

  -- 7. Evaluación de evento activo (excluyendo eventos marcados como is_demo = true)
  -- Si hay solapamiento, se selecciona determinísticamente el de inicio más reciente.
  select
    e.id,
    e.name,
    e.starts_at,
    e.ends_at,
    e.is_demo
  into
    v_event_id,
    v_event_name,
    v_event_starts,
    v_event_ends,
    v_event_is_demo
  from public.events e
  where e.municipality_code = p_municipality_code
    and e.is_demo = false
    and now() >= e.starts_at
    and now() <= e.ends_at
  order by e.starts_at desc, e.id asc
  limit 1;

  if v_event_id is not null then
    select
      count(*)::integer,
      (percentile_cont(0.5) within group (order by r.amount_cop))::numeric
    into
      v_event_sample_count,
      v_event_median
    from public.price_reports r
    where r.municipality_code = p_municipality_code
      and r.zone_id = p_zone_id
      and r.category_id = p_category_id
      and r.is_hidden = false
      and r.is_demo = false
      and r.created_at >= v_event_starts
      and r.created_at <= v_event_ends;

    if v_event_sample_count >= v_min_reports and v_event_median is not null and v_event_median > 0 then
      v_use_event_reference := true;
      v_event_deviation := ((p_amount_cop::numeric - v_event_median) / v_event_median) * 100.0;
      v_event_details := jsonb_build_object(
        'event_name', v_event_name,
        'event_reference_cop', round(v_event_median)::integer,
        'event_deviation_pct', round(v_event_deviation, 2),
        'event_sample_count', v_event_sample_count,
        'is_demo', false
      );
    end if;
  end if;

  -- 8. Selección de referencia vigente (evento si cumple >= 3 reportes; si no, base de 60 días)
  if v_use_event_reference then
    v_effective_median := v_event_median;
    v_effective_deviation := v_event_deviation;
  else
    v_effective_median := v_baseline_median;
    v_effective_deviation := v_baseline_deviation;
  end if;

  -- 9. Clasificación del nivel usando la desviación exacta SIN redondear
  if v_effective_deviation <= v_threshold_green then
    v_level := 'green';
  elsif v_effective_deviation <= v_threshold_yellow then
    v_level := 'yellow';
  else
    v_level := 'red';
  end if;

  -- Alerta de precio bajo: estrictamente menor que -40% (-40.0000% exacto NO dispara alerta)
  v_underpriced_alert := (v_effective_deviation < v_underpriced_threshold);

  -- Tope recomendado: referencia vigente * 1.15
  v_recommended_cap := round(v_effective_median * v_cap_factor)::integer;

  return jsonb_build_object(
    'rule_version', 'v1.0',
    'level', v_level,
    'category_id', p_category_id,
    'municipality_code', p_municipality_code,
    'zone_id', p_zone_id,
    'amount_cop', p_amount_cop,
    'reference_cop', round(v_effective_median)::integer,
    'baseline_reference_cop', round(v_baseline_median)::integer,
    'deviation_percent', round(v_effective_deviation, 2),
    'baseline_deviation_percent', round(v_baseline_deviation, 2),
    'sample_count', v_sample_count,
    'underpriced_alert', v_underpriced_alert,
    'recommended_cap_cop', v_recommended_cap,
    'window_days', v_window_days,
    'is_event_context', v_use_event_reference,
    'event_details', v_event_details,
    'is_demo', false
  );
end;
$$;

comment on function public.calculate_price_verdict(varchar, varchar, varchar, integer) is
  'Única fuente de verdad del semáforo de precios por zona (VJ-10). Calcula mediana (percentile_cont 0.5), umbrales 15%/40%, N>=3, ventana 60d y contexto de evento.';

-- Alias compatible con la mención en D15 (`evaluate_price_verdict`)
create or replace function public.evaluate_price_verdict(
  p_category_id varchar,
  p_municipality_code varchar,
  p_zone_id varchar,
  p_amount_cop integer
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select public.calculate_price_verdict(
    p_category_id,
    p_municipality_code,
    p_zone_id,
    p_amount_cop
  );
$$;

-- Control estricto de privilegios: solo usuarios autenticados pueden invocar la RPC
revoke all on function public.calculate_price_verdict(varchar, varchar, varchar, integer) from public, anon;
grant execute on function public.calculate_price_verdict(varchar, varchar, varchar, integer) to authenticated;

revoke all on function public.evaluate_price_verdict(varchar, varchar, varchar, integer) from public, anon;
grant execute on function public.evaluate_price_verdict(varchar, varchar, varchar, integer) to authenticated;
