import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/theme/semantic_status_colors.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Tarjeta accesible del resultado del semáforo de precios (M07 y M20).
/// Inspirada en el mockup limpio: cabecera de contexto, tarjeta de semáforo en lenguaje humano,
/// bloque "Sugerencia" por reglas deterministas (nunca IA) y descargo orientativo.
class PriceVerdictCard extends StatelessWidget {
  const PriceVerdictCard({
    super.key,
    required this.verdict,
    this.category,
    this.zone,
    this.destinationZone,
  });

  final PriceVerdict verdict;
  final PriceCategory? category;
  final MunicipalityZone? zone;
  final MunicipalityZone? destinationZone;

  IconData _iconForCategory() {
    final groupKey = category?.groupKey;
    if (groupKey == 'transport' ||
        verdict.categoryId == 'transport_taxi_minimal') {
      return Icons.local_taxi_outlined;
    }
    if (groupKey == 'food' || verdict.categoryId == 'food_corrientazo') {
      return Icons.restaurant_outlined;
    }
    if (groupKey == 'lodging' ||
        verdict.categoryId == 'lodging_standard_night') {
      return Icons.hotel_outlined;
    }
    return Icons.local_laundry_service_outlined;
  }

  String _titleKeyForLevel(PriceVerdictLevel level) {
    switch (level) {
      case PriceVerdictLevel.green:
        return 'price_verdict.level_green_title';
      case PriceVerdictLevel.yellow:
        return 'price_verdict.level_yellow_title';
      case PriceVerdictLevel.red:
        return 'price_verdict.level_red_title';
      case PriceVerdictLevel.insufficient:
        return 'price_verdict.level_insufficient_title';
    }
  }

  String _subtitleKeyForLevel(PriceVerdictLevel level) {
    switch (level) {
      case PriceVerdictLevel.green:
        return 'price_verdict.level_green_subtitle';
      case PriceVerdictLevel.yellow:
        return 'price_verdict.level_yellow_subtitle';
      case PriceVerdictLevel.red:
        return 'price_verdict.level_red_subtitle';
      case PriceVerdictLevel.insufficient:
        return 'price_verdict.level_insufficient_subtitle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors =
        Theme.of(context).extension<SemanticStatusColors>() ??
            SemanticStatusColors.light();
    final style = semanticColors.styleForVerdict(verdict.level);

    String languageCode;
    try {
      languageCode = context.locale.languageCode;
    } catch (_) {
      languageCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    final categoryTitle =
        category?.localizedName(languageCode) ?? verdict.categoryId;
    final originZoneName =
        zone?.localizedName(languageCode) ?? verdict.zoneId;
    final destinationZoneName = destinationZone?.localizedName(languageCode) ??
        verdict.destinationZoneId;
    final headerTitle = buildVerdictHeaderTitle(
      categoryId: verdict.categoryId,
      categoryName: categoryTitle,
      originZoneName: originZoneName,
      destinationZoneName: destinationZoneName,
    );
    final suggestion = resolvePriceSuggestion(verdict);

    return Semantics(
      container: true,
      label: '${_titleKeyForLevel(verdict.level).tr()}. '
          '${_subtitleKeyForLevel(verdict.level).tr()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabecera limpia de contexto ("Taxi: Origen → Destino" o "Categoría · Zona" + "Evaluado ahora")
          VjCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    _iconForCategory(),
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'price_verdict.evaluated_now'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. Tarjeta principal del semáforo (Color + Ícono + Monto consultado + Explicación humana)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: style.border, width: 1.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(style.icon, color: style.foreground, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleKeyForLevel(verdict.level).tr(),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: style.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCop(verdict.submittedCop),
                            style: textTheme.headlineMedium?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _subtitleKeyForLevel(verdict.level).tr(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (verdict.isInsufficient)
                  _InsufficientSampleSection(verdict: verdict)
                else
                  _QuantifiedMetricsSection(
                    verdict: verdict,
                    accentColor: style.foreground,
                  ),

                // Contexto de evento activo real (solo cuando eventContext != null)
                if (verdict.eventContext != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _EventContextBanner(
                    eventContext: verdict.eventContext!,
                    palette: semanticColors.eventContext,
                  ),
                ],
              ],
            ),
          ),

          // 3. Alerta de precio sospechosamente bajo (desviación < -40%)
          if (verdict.lowPriceWarning && !verdict.isInsufficient) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'price_verdict.low_price_warning_title'.tr(),
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'price_verdict.low_price_warning_body'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 4. Bloque "Sugerencia" por reglas fijas (nunca "Sugerencia de la IA")
          if (suggestion != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              suggestion.titleKey.tr(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            VjCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      suggestion.bodyKey.tr(
                        namedArgs: {
                          'ref': suggestion.formattedReferenceCop,
                          'cap': suggestion.formattedRecommendedCapCop,
                        },
                      ),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Aviso orientativo obligatorio (nunca alega IA ni tarifa vinculante)
          const SizedBox(height: AppSpacing.md),
          VjCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.balance_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'price_verdict.orientative_disclaimer'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Métricas claras cuando la muestra de la zona o rango es suficiente (N >= 3):
/// Precio de referencia, diferencia porcentual y tamaño de muestra discreto.
class _QuantifiedMetricsSection extends StatelessWidget {
  const _QuantifiedMetricsSection({
    required this.verdict,
    required this.accentColor,
  });

  final PriceVerdict verdict;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              if (verdict.referenceCop != null)
                _MetricColumn(
                  label: 'price_verdict.reference_median_label'.tr(),
                  value: formatCop(verdict.referenceCop!),
                  valueColor: AppColors.primary,
                ),
              if (verdict.deviationPct != null)
                _MetricColumn(
                  label: 'price_verdict.deviation_label'.tr(),
                  value: formatDeviationPct(verdict.deviationPct!),
                  valueColor: accentColor,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'price_verdict.sample_size_label'.tr(
                  namedArgs: {
                    'n': verdict.n.toString(),
                    'days': verdict.windowDays.toString(),
                  },
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Estado neutro M20 cuando N < 3: sin color de semáforo ni umbral artificial.
class _InsufficientSampleSection extends StatelessWidget {
  const _InsufficientSampleSection({required this.verdict});

  final PriceVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'price_verdict.insufficient_sample_detail'.tr(
              namedArgs: {'n': verdict.n.toString()},
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'price_verdict.insufficient_no_threshold'.tr(),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Banner azul independiente para contexto de evento real activo (nunca usa verde/ámbar/rojo).
class _EventContextBanner extends StatelessWidget {
  const _EventContextBanner({
    required this.eventContext,
    required this.palette,
  });

  final PriceEventContext eventContext;
  final StatusVisualStyle palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(palette.icon, color: palette.foreground, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  eventContext.eventName,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    color: palette.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'price_verdict.event_context_detail'.tr(
              namedArgs: {
                'ref': formatCop(eventContext.eventReferenceCop),
                'dev': formatDeviationPct(eventContext.eventDeviationPct),
              },
            ),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
