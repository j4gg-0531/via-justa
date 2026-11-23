import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';

/// Muestra el texto completo y versionado de Términos o Política de Privacidad (`Ley 1581`).
Future<void> showLegalDocumentDialog(
  BuildContext context,
  ConsentDocType document,
) {
  final isTerms = document == ConsentDocType.termsAndConditions;
  final titleKey = isTerms ? 'legal.terms_title' : 'legal.privacy_title';
  final bodyKey = isTerms ? 'legal.terms_body' : 'legal.privacy_body';

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final textTheme = Theme.of(dialogContext).textTheme;
      final clauses = splitLegalDocumentClauses(bodyKey.tr());
      return AlertDialog(
        scrollable: true,
        title: Text(titleKey.tr()),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            VjBadge(
              label: 'legal.version_label'.tr(
                namedArgs: {'version': consentDocumentVersion},
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < clauses.length; i++) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(clauses[i], style: textTheme.bodyMedium),
              ),
              if (i < clauses.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text('common.close'.tr()),
          ),
        ],
      );
    },
  );
}
