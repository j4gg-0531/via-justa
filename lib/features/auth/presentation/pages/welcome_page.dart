import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_text.dart';

/// Pantalla de bienvenida: punto de entrada al inicio de sesión o al registro.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
                      label: 'welcome.sign_in'.tr(),
                      onPressed: () => context.push(AppRoutes.login),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    VjButton(
                      label: 'welcome.create_account'.tr(),
                      variant: VjButtonVariant.outlined,
                      onPressed: () => context.push(AppRoutes.register),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.xl),
                    LegalText(prefix: 'login.legal_prefix'.tr()),
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
