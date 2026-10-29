import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/auth/presentation/state/register_form_provider.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_error_texts.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_text.dart';
import 'package:via_justa/features/auth/presentation/widgets/or_divider.dart';

/// Pantalla de creación de cuenta.
///
/// Al registrarse se guarda el perfil y la aceptación de términos y política de
/// privacidad en Supabase (ver `AuthController.signUp`).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!ref.read(registerFormProvider.notifier).submit()) return;

    final form = ref.read(registerFormProvider);
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: form.email,
          password: form.password,
          displayName: form.name,
        );
    if (!mounted) return;

    if (succeeded) {
      // El router redirige reactivamente al cambiar el estado de autenticación.
      return;
    }

    final message = authFailureText(ref.read(authControllerProvider).failure);
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('common.coming_soon'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerFormProvider);
    final notifier = ref.read(registerFormProvider.notifier);
    final authState = ref.watch(authControllerProvider);
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
                      Text(
                        'register.title'.tr(),
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      VjTextField(
                        label: 'auth.name'.tr(),
                        controller: _nameController,
                        onChanged: notifier.setName,
                        errorText: nameErrorText(state.nameError),
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                      const SizedBox(height: AppSpacing.md),
                      CheckboxListTile(
                        value: state.termsAccepted,
                        onChanged: (value) =>
                            notifier.setTermsAccepted(value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: LegalText(prefix: 'register.accept_prefix'.tr()),
                      ),
                      if (state.termsError)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'auth.error.terms_required'.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      VjButton(
                        label: 'register.submit'.tr(),
                        onPressed: authState.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const OrDivider(),
                      const SizedBox(height: AppSpacing.xl),
                      VjButton(
                        label: 'login.google'.tr(),
                        variant: VjButtonVariant.outlined,
                        onPressed: _showComingSoon,
                      ),
                      if (authState.usesDemoData) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Center(
                          child: Text(
                            'auth.demo_note'.tr(),
                            style: textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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