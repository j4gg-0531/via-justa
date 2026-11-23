import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/theme/semantic_status_colors.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_semaphore_panel.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Vista unificada del análisis orientativo de contratos (`VJ-14`).
/// Comparte la cabecera "Semáforo Vertical Puro" (`VjSemaphorePanel`) con la vista de precios.
class ContractAnalysisResultView extends StatelessWidget {
  const ContractAnalysisResultView({
    super.key,
    required this.result,
  });

  final ContractAnalysisResult result;

  VjSemaphoreLight _lightForLevel(ContractAnalysisLevel level) {
    switch (level) {
      case ContractAnalysisLevel.green:
        return VjSemaphoreLight.green;
      case ContractAnalysisLevel.yellow:
        return VjSemaphoreLight.amber;
      case ContractAnalysisLevel.red:
        return VjSemaphoreLight.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors =
        Theme.of(context).extension<SemanticStatusColors>() ??
        SemanticStatusColors.light();
    final levelStyle = semanticColors.styleForContractLevel(result.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Banner obligatorio de demostración cuando aplica
        if (result.isDemo) ...[
          VjCard(
            backgroundColor: AppColors.primarySoft,
            borderColor: AppColors.primaryBorder,
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

        // 2. Semáforo Vertical Puro (S3) gemelo al semáforo de precios
        VjSemaphorePanel(
          activeLight: _lightForLevel(result.level),
          categoryTag: 'contract_analysis.result_title'.tr(),
          statusLabel: result.level.translationKey.tr(),
          statusIcon: levelStyle.icon,
          headline: 'contract_analysis.clauses_title'.tr(
            namedArgs: {'count': '${result.clauses.length}'},
          ),
          subMetric: 'contract_analysis.key_points_title'.tr(
            namedArgs: {'count': '${result.keyPoints.length}'},
          ),
          accentColor: levelStyle.foreground,
          badgeBackground: levelStyle.background,
          badgeForeground: levelStyle.foreground,
          trailingDetail: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'contract_analysis.general_recommendation_title'.tr(),
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: 2),
              Text(
                result.generalRecommendation,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // 3. Puntos clave del contrato
        if (result.keyPoints.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            borderRadius: AppRadius.xl,
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
                for (var i = 0; i < result.keyPoints.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.keyPoints[i].title,
                                style: textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                result.keyPoints[i].detail,
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
                  if (i < result.keyPoints.length - 1)
                    const Divider(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],

        // 4. Cláusulas analizadas ("Qué dice vs. Qué implica" con acentos laterales)
        if (result.clauses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < result.clauses.length; i++) ...[
            _ClauseComparisonCard(clause: result.clauses[i]),
            if (i < result.clauses.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],

        // 5. Descargo / aviso orientativo legal
        const SizedBox(height: AppSpacing.md),
        VjCard(
          elevated: false,
          backgroundColor: AppColors.surfaceSubtle,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'contract_analysis.disclaimer_title'.tr(),
                      style: textTheme.labelMedium?.copyWith(
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

class _ClauseComparisonCard extends StatelessWidget {
  const _ClauseComparisonCard({required this.clause});

  final ContractAnalyzedClause clause;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Qué dice el contrato (borde lateral pizarra)
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.border, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.clause_excerpt_label'.tr(),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '“${clause.excerpt}”',
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Qué implica / riesgo detectado (borde lateral azul)
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.clause_issue_label'.tr(),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.semaphoreAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clause.issue,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          if (clause.legalReference != null &&
              clause.legalReference!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Wrap(
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
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    clause.legalReference!,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.clause_recommendation_label'.tr(),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clause.recommendation,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
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
