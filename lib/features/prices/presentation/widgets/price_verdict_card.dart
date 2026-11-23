import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/theme/semantic_status_colors.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_semaphore_panel.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Tarjeta accesible del resultado del semáforo de precios (M07 y M20).
/// Comparte la identidad visual "Semáforo Vertical Puro" con el análisis de contratos.
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

  VjSemaphoreLight _lightForLevel(PriceVerdictLevel level) {
    switch (level) {
      case PriceVerdictLevel.green:
        return VjSemaphoreLight.green;
      case PriceVerdictLevel.yellow:
        return VjSemaphoreLight.amber;
      case PriceVerdictLevel.red:
        return VjSemaphoreLight.red;
      case PriceVerdictLevel.insufficient:
        return VjSemaphoreLight.neutral;
    }
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
    final originZoneName = zone?.localizedName(languageCode) ?? verdict.zoneId;
    final destinationZoneName =
        destinationZone?.localizedName(languageCode) ??
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
      label:
          '${_titleKeyForLevel(verdict.level).tr()}. '
          '${_subtitleKeyForLevel(verdict.level).tr()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Semáforo Vertical Puro (S3) unificado
          VjSemaphorePanel(
            activeLight: _lightForLevel(verdict.level),
            categoryTag: headerTitle,
            statusLabel: _titleKeyForLevel(verdict.level).tr(),
            statusIcon: style.icon,
            headline: formatCop(verdict.submittedCop),
            subMetric: 'price_verdict.evaluated_now'.tr(),
            accentColor: style.foreground,
            badgeBackground: style.background,
            badgeForeground: style.foreground,
            trailingDetail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _subtitleKeyForLevel(verdict.level).tr(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. Métricas comparativas o estado neutro M20
          if (verdict.isInsufficient)
            _InsufficientSampleSection(verdict: verdict)
          else
            _QuantifiedMetricsSection(
              verdict: verdict,
              accentColor: style.foreground,
            ),

          // 3. Contexto de evento activo real en azul institucional independiente
          if (verdict.eventContext != null) ...[
            const SizedBox(height: AppSpacing.md),
            _EventContextBanner(
              eventContext: verdict.eventContext!,
              palette: semanticColors.eventContext,
            ),
          ],

          // 4. Alerta de precio sospechosamente bajo (desviación < -40%)
          if (verdict.lowPriceWarning && !verdict.isInsufficient) ...[
            const SizedBox(height: AppSpacing.md),
            VjCard(
              borderColor: AppColors.primaryBorder,
              backgroundColor: AppColors.primarySoft,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'price_verdict.low_price_warning_title'.tr(),
                          style: textTheme.titleSmall?.copyWith(
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

          // 5. Bloque "Sugerencia" por reglas deterministas
          if (suggestion != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              suggestion.titleKey.tr(),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            VjCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 6. Aviso orientativo obligatorio
          const SizedBox(height: AppSpacing.md),
          VjCard(
            elevated: false,
            backgroundColor: AppColors.surfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.balance_outlined,
                  color: AppColors.textSecondary,
                  size: 18,
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

/// Métricas claras cuando la muestra es suficiente (`N >= 3`).
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

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xl,
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
          const SizedBox(height: AppSpacing.md),
          const Divider(),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estado neutro M20 cuando `N < 3`.
class _InsufficientSampleSection extends StatelessWidget {
  const _InsufficientSampleSection({required this.verdict});

  final PriceVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
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

/// Banner azul independiente para contexto de evento real activo.
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

    return VjCard(
      backgroundColor: palette.background,
      borderColor: palette.border.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpacing.md),
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
                  style: textTheme.titleSmall?.copyWith(
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
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
