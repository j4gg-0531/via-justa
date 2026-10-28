import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/theme/semantic_status_colors.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Tarjeta accesible del semáforo de precios por zona del municipio (M07 y M20).
/// Combina color de SemanticStatusColors + ícono + etiqueta localizada + zona evaluada + tamaño de muestra N + aviso orientativo.
class PriceVerdictCard extends StatelessWidget {
  const PriceVerdictCard({
    super.key,
    required this.verdict,
    this.category,
    this.zone,
  });

  final PriceVerdict verdict;
  final PriceCategory? category;
  final MunicipalityZone? zone;

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
      languageCode =
          Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    final categoryTitle =
        category?.localizedName(languageCode) ?? verdict.categoryId;
    final categoryUnit = category?.localizedUnit(languageCode);
    final zoneTitle =
        zone?.localizedFullLabel(languageCode) ?? verdict.zoneId;

    return Semantics(
      container: true,
      label: '${_titleKeyForLevel(verdict.level).tr()}. '
          '${_subtitleKeyForLevel(verdict.level).tr()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Encabezado principal del veredicto (Color + Ícono + Texto + Insignia DEMO)
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, color: style.foreground, size: 28),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            _titleKeyForLevel(verdict.level).tr(),
                            style: textTheme.headlineMedium?.copyWith(
                              fontSize: 20,
                              color: style.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (verdict.isDemo)
                      VjBadge(
                        label: 'price_verdict.demo_orientative_badge'.tr(),
                        icon: Icons.science_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _subtitleKeyForLevel(verdict.level).tr(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.md),

                // Categoría evaluada
                Text(
                  categoryTitle,
                  style: textTheme.titleMedium,
                ),
                if (categoryUnit != null && categoryUnit.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    categoryUnit,
                    style: textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),

                // Zona del municipio evaluada
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '${'price_verdict.evaluated_zone_label'.tr()}: $zoneTitle',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Monto consultado vs Referencia zonal (mediana)
                if (verdict.isInsufficient)
                  _InsufficientSampleSection(verdict: verdict)
                else
                  _QuantifiedMetricsSection(
                    verdict: verdict,
                    accentColor: style.foreground,
                  ),
              ],
            ),
          ),

          // 2. Alerta de precio sospechosamente bajo (desviación < -40%)
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

          // 3. Contexto de evento activo (Color azul independiente, nunca semáforo)
          if (verdict.eventContext != null) ...[
            const SizedBox(height: AppSpacing.md),
            _EventContextBanner(
              eventContext: verdict.eventContext!,
              palette: semanticColors.eventContext,
            ),
          ],

          // 4. Aviso orientativo obligatorio (nunca alega IA ni tarifa vinculante)
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

/// Métricas cuantitativas cuando la muestra de la zona es suficiente (N >= 3):
/// Referencia de zona (mediana), desviación porcentual, muestra N y tope sugerido.
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
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            _MetricColumn(
              label: 'price_verdict.submitted_label'.tr(),
              value: formatCop(verdict.submittedCop),
              valueColor: AppColors.textPrimary,
            ),
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
        const SizedBox(height: AppSpacing.md),
        if (verdict.recommendedCapCop != null)
          Container(
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
                  'price_verdict.recommended_cap_label'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCop(verdict.recommendedCapCop!),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 18,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Estado neutro M20 cuando N < 3 en la zona: sin color de semáforo ni umbral artificial.
class _InsufficientSampleSection extends StatelessWidget {
  const _InsufficientSampleSection({required this.verdict});

  final PriceVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricColumn(
          label: 'price_verdict.submitted_label'.tr(),
          value: formatCop(verdict.submittedCop),
          valueColor: AppColors.textPrimary,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
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
        ),
      ],
    );
  }
}

/// Banner azul independiente para contexto de evento (nunca usa verde/ámbar/rojo).
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
            fontSize: 18,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
