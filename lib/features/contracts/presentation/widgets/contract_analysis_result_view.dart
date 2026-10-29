import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/theme/semantic_status_colors.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Vista de visualización estructurada del resultado de análisis de contratos (`VJ-14`).
///
/// Componentes:
/// 1. Banner de demostración visible si [result.isDemo] es `true`.
/// 2. Semáforo visual del contrato: nivel con color + icono + texto mediante [SemanticStatusColors].
/// 3. Recomendación general en lenguaje claro.
/// 4. Puntos clave identificados en el contrato.
/// 5. Cláusulas observadas (cita textual, riesgo y recomendación; referencia legal solo si no es nula).
/// 6. Aviso orientativo y descargo de responsabilidad legal.
class ContractAnalysisResultView extends StatelessWidget {
  const ContractAnalysisResultView({
    super.key,
    required this.result,
  });

  /// Resultado inmutable validado por el dominio.
  final ContractAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = Theme.of(context).extension<SemanticStatusColors>() ??
        SemanticStatusColors.light();
    final levelStyle = semanticColors.styleForContractLevel(result.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Banner obligatorio de simulación / demostración mientras sea demo
        if (result.isDemo) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
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
                        'contract_analysis.demo_banner_title'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'contract_analysis.demo_banner_desc'.tr(),
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
          const SizedBox(height: AppSpacing.md),
        ],

        // 2. Semáforo visual: Nivel de riesgo + Recomendación general
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'contract_analysis.result_title'.tr(),
                    style: textTheme.titleMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: levelStyle.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: levelStyle.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          levelStyle.icon,
                          color: levelStyle.foreground,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            result.level.translationKey.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              color: levelStyle.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'contract_analysis.general_recommendation_title'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                result.generalRecommendation,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // 3. Puntos clave del contrato
        if (result.keyPoints.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.key_points_title'.tr(
                    namedArgs: {'count': '${result.keyPoints.length}'},
                  ),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final point in result.keyPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point.title,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                point.detail,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 4. Cláusulas analizadas (sin mostrar legal_reference si es null)
        if (result.clauses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.clauses_title'.tr(
                    namedArgs: {'count': '${result.clauses.length}'},
                  ),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final clause in result.clauses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'contract_analysis.clause_excerpt_label'.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '“${clause.excerpt}”',
                            style: textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'contract_analysis.clause_issue_label'.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.semaphoreAmber,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clause.issue,
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Regla de integridad legal: Solo se muestra si NO es nula ni vacía
                          if (clause.legalReference != null &&
                              clause.legalReference!.trim().isNotEmpty) ...[
                            Wrap(
                              spacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(
                                  Icons.gavel_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                Text(
                                  'contract_analysis.clause_legal_ref_label'.tr(),
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  clause.legalReference!,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],

                          Text(
                            'contract_analysis.clause_recommendation_label'.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clause.recommendation,
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 5. Descargo / aviso orientativo legal
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'contract_analysis.disclaimer_title'.tr(),
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.disclaimer.isNotEmpty
                          ? result.disclaimer
                          : 'contract_analysis.disclaimer_body'.tr(),
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
      ],
    );
  }
}
