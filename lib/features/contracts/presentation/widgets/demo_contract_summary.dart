import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis.dart';

/// Resumen demostrativo de análisis de contrato con dos puntos de ejemplo (ES/EN)
/// y etiqueta visible «Demostración; no se analizó ningún documento».
class DemoContractSummary extends StatelessWidget {
  const DemoContractSummary({
    super.key,
    required this.analysis,
    required this.onComingSoonTap,
  });

  final ContractAnalysis analysis;
  final VoidCallback onComingSoonTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    String languageCode;
    try {
      languageCode = context.locale.languageCode;
    } catch (_) {
      languageCode =
          Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta obligatoria: «Demostración; no se analizó ningún documento»
        Semantics(
          container: true,
          child: Container(
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
                        'scan.contract_no_document_badge'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'scan.contract_no_document_note'.tr(),
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
        ),

        const SizedBox(height: AppSpacing.lg),

        // Encabezado del caso de ejemplo
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
                  const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  Text(
                    analysis.localizedContractType(languageCode),
                    style: textTheme.titleMedium,
                  ),
                  VjBadge(label: 'common.demo_badge'.tr()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'scan.contract_description'.tr(),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),

              // Los dos puntos de ejemplo en ES/EN
              for (final point in analysis.points) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ContractPointTile(
                    point: point,
                    languageCode: languageCode,
                  ),
                ),
              ],

              Text(
                'scan.contract_legal_disclaimer'.tr(),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Acciones de archivo/foto marcadas como Próximamente (sin solicitar permisos Android)
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'scan.contract_capture_title'.tr(),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  VjBadge(label: 'common.coming_soon'.tr()),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'scan.contract_capture_subtitle'.tr(),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: onComingSoonTap,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(
                      '${'scan.action_photo'.tr()} (${'common.coming_soon'.tr()})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onComingSoonTap,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: Text(
                      '${'scan.action_gallery'.tr()} (${'common.coming_soon'.tr()})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContractPointTile extends StatelessWidget {
  const _ContractPointTile({
    required this.point,
    required this.languageCode,
  });

  final ContractClausePoint point;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isReview =
        point.attention == ContractClauseAttention.reviewRequired;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isReview ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReview
                ? Icons.find_in_page_outlined
                : Icons.verified_user_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.localizedTitle(languageCode),
                  style: textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  point.localizedExplanation(languageCode),
                  style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
