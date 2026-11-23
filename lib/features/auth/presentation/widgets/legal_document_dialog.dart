import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';

/// Muestra el texto completo y versionado de Términos o Política de Privacidad (`Ley 1581`).
Future<void> showLegalDocumentDialog(
  BuildContext context,
  ConsentDocType document,
) {
  final isTerms = document == ConsentDocType.termsAndConditions;
  final titleKey = isTerms ? 'legal.terms_title' : 'legal.privacy_title';
  final bodyKey = isTerms ? 'legal.terms_body' : 'legal.privacy_body';

  return showVjModalSheet<void>(
    context: context,
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
      final clauses = splitLegalDocumentClauses(bodyKey.tr());
      return VjModalSheet(
        icon: isTerms ? Icons.article_outlined : Icons.shield_outlined,
        title: titleKey.tr(),
        headerBadge: VjBadge(
          label: 'legal.version_label'.tr(
            namedArgs: {'version': consentDocumentVersion},
          ),
        ),
        maxHeightFactor: 0.88,
        footer: VjButton(
          label: 'common.close'.tr(),
          variant: VjButtonVariant.navy,
          minHeight: 48,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < clauses.length; i++) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md + 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  clauses[i],
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.48,
                  ),
                ),
              ),
              if (i < clauses.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      );
    },
  );
}
