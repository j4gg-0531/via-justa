import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';

/// Pantalla 1 · Entrada. Solo interfaz: ambos botones llevan al onboarding.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _continue(BuildContext context) => context.push(AppRoutes.onboarding);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'app.name'.tr(),
                      style: text.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'login.tagline'.tr(),
                      style: text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    VjButton(
                      label: 'login.google'.tr(),
                      variant: VjButtonVariant.outlined,
                      onPressed: () => _continue(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text('login.or'.tr(), style: text.bodySmall),
                        ),
                        const Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    VjButton(
                      label: 'login.email'.tr(),
                      variant: VjButtonVariant.tonal,
                      leadingIcon: Icons.mail_outline,
                      onPressed: () => _continue(context),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.xl),
                    const _LegalText(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall!;
    final link = small.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: small,
        children: [
          TextSpan(text: 'login.legal_prefix'.tr()),
          TextSpan(text: 'login.legal_terms'.tr(), style: link),
          TextSpan(text: 'login.legal_and'.tr()),
          TextSpan(text: 'login.legal_privacy'.tr(), style: link),
          TextSpan(text: 'login.legal_suffix'.tr()),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}