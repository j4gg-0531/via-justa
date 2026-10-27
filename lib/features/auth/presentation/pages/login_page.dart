import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/auth/presentation/state/login_form_provider.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_error_texts.dart';
import 'package:via_justa/features/auth/presentation/widgets/or_divider.dart';

/// Pantalla de inicio de sesión (interfaz de ejemplo con validación local).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = ref.read(loginFormProvider.notifier).submit();
    if (!isValid) return;

    context.push(AppRoutes.onboarding);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('common.coming_soon'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginFormProvider);
    final notifier = ref.read(loginFormProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'common.back'.tr(),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Text('login.title'.tr(), style: textTheme.headlineMedium),
                      const SizedBox(height: AppSpacing.xl),
                      VjTextField(
                        label: 'auth.email'.tr(),
                        controller: _emailController,
                        onChanged: notifier.setEmail,
                        errorText: emailErrorText(state.emailError),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      VjTextField(
                        label: 'auth.password'.tr(),
                        controller: _passwordController,
                        onChanged: notifier.setPassword,
                        errorText: passwordErrorText(state.passwordError),
                        obscureText: state.obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          tooltip: state.obscurePassword
                              ? 'auth.show_password'.tr()
                              : 'auth.hide_password'.tr(),
                          icon: Icon(
                            state.obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: notifier.toggleObscurePassword,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showComingSoon,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          child: Text('auth.forgot_password'.tr()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      VjButton(
                        label: 'common.continue'.tr(),
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const OrDivider(),
                      const SizedBox(height: AppSpacing.xl),
                      VjButton(
                        label: 'login.google'.tr(),
                        variant: VjButtonVariant.outlined,
                        onPressed: () => context.push(AppRoutes.onboarding),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: Text(
                          'auth.demo_note'.tr(),
                          style: textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
