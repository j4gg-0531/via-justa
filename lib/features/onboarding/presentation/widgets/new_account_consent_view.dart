import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_google_mark.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_text.dart';

/// Confirmación explícita cuando un inicio de sesión con Google corresponde a
/// una cuenta inexistente o previamente eliminada y requiere aceptar Habeas Data.
class NewAccountConsentView extends StatelessWidget {
  const NewAccountConsentView({
    super.key,
    required this.displayName,
    required this.email,
    required this.isBusy,
    required this.onAccept,
    required this.onCancel,
  });

  final String displayName;
  final String? email;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasEmail = email != null && email!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                VjBadge(
                  label: 'onboarding.google_consent.badge'.tr(),
                  icon: Icons.person_add_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'onboarding.google_consent.title'.tr(),
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  hasEmail
                      ? 'onboarding.google_consent.body_with_email'.tr(
                          namedArgs: {'email': email!.trim(), 'name': displayName},
                        )
                      : 'onboarding.google_consent.body_generic'.tr(
                          namedArgs: {'name': displayName},
                        ),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                VjCard(
                  borderRadius: AppRadius.xl,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: VjGoogleMark(size: 20),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: textTheme.titleMedium),
                                if (hasEmail) ...[
                                  const SizedBox(height: 2),
                                  Text(email!.trim(), style: textTheme.bodySmall),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      LegalText(
                        prefix: 'onboarding.google_consent.accept_prefix'.tr(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        VjButton(
          label: 'onboarding.google_consent.accept_cta'.tr(),
          leadingIcon: Icons.check_circle_outline,
          onPressed: isBusy ? null : onAccept,
        ),
        const SizedBox(height: AppSpacing.md),
        VjButton(
          label: 'onboarding.google_consent.cancel_cta'.tr(),
          variant: VjButtonVariant.outlined,
          onPressed: isBusy ? null : onCancel,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
