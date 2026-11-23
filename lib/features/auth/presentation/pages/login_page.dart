import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/auth/presentation/state/login_form_provider.dart';
import 'package:via_justa/features/auth/presentation/state/password_management_providers.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_error_texts.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_failure_text.dart';

/// Pantalla de inicio de sesión.
///
/// Con Supabase configurado autentica contra el backend real; sin credenciales
/// compiladas funciona en modo DEMO (el aviso se muestra al pie).
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

  Future<void> _submit() async {
    if (!ref.read(loginFormProvider.notifier).submit()) return;

    final form = ref.read(loginFormProvider);
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: form.email, password: form.password);
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

  Future<void> _signInWithGoogle() async {
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted || succeeded) return;

    final message =
        authFailureText(ref.read(authControllerProvider).failure) ??
        'auth.error.unknown'.tr();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showForgotPasswordDialog() async {
    final initialEmail = _emailController.text.trim();
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('profile.password_updated'.tr())),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginFormProvider);
    final notifier = ref.read(loginFormProvider.notifier);
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
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: authState.isBusy
                              ? null
                              : _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text('auth.forgot_password'.tr()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      VjButton(
                        label: 'common.continue'.tr(),
                        onPressed: authState.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              'login.or'.tr(),
                              style: textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      VjButton(
                        label: 'login.google'.tr(),
                        variant: VjButtonVariant.outlined,
                        leadingIcon: Icons.account_circle_outlined,
                        onPressed: authState.isBusy ? null : _signInWithGoogle,
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

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail.isNotEmpty) {
      Future.microtask(() {
        if (!mounted) return;
        ref
            .read(forgotPasswordFormProvider.notifier)
            .setEmail(widget.initialEmail);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitStepOne() async {
    final notifier = ref.read(forgotPasswordFormProvider.notifier);
    notifier.setEmail(_emailController.text);
    final ok = await notifier.requestCode();
    if (!mounted) return;
    final form = ref.read(forgotPasswordFormProvider);
    if (!form.isEmailValid) return;

    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('auth.password_reset_sent'.tr())),
        );
      return;
    }

    final message =
        authFailureText(ref.read(authControllerProvider).failure) ??
        'auth.error.unknown'.tr();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitStepTwo() async {
    final notifier = ref.read(forgotPasswordFormProvider.notifier);
    notifier.setOtpCode(_otpController.text);
    notifier.setNewPassword(_newPasswordController.text);
    notifier.setConfirmPassword(_confirmPasswordController.text);
    final ok = await notifier.verifyOtpAndReset();
    if (!mounted) return;
    final form = ref.read(forgotPasswordFormProvider);
    if (!form.isStepTwoValid) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    final message =
        authFailureText(ref.read(authControllerProvider).failure) ??
        'auth.error.unknown'.tr();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(forgotPasswordFormProvider);
    final notifier = ref.read(forgotPasswordFormProvider.notifier);
    final authState = ref.watch(authControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      scrollable: true,
      title: Text('auth.forgot_password_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!form.codeSent) ...[
            Text(
              'auth.forgot_password_body'.tr(),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            VjTextField(
              label: 'auth.email'.tr(),
              controller: _emailController,
              onChanged: notifier.setEmail,
              errorText: emailErrorText(form.emailError),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitStepOne(),
            ),
          ] else ...[
            Text(
              'auth.forgot_password_code_body'.tr(),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            VjTextField(
              label: 'auth.otp_code_label'.tr(),
              controller: _otpController,
              onChanged: notifier.setOtpCode,
              errorText: otpCodeErrorText(form.otpCodeError),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            VjTextField(
              label: 'profile.change_password_new_label'.tr(),
              controller: _newPasswordController,
              onChanged: notifier.setNewPassword,
              errorText: passwordErrorText(form.newPasswordError),
              obscureText: form.obscureNewPassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                tooltip: form.obscureNewPassword
                    ? 'auth.show_password'.tr()
                    : 'auth.hide_password'.tr(),
                icon: Icon(
                  form.obscureNewPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: notifier.toggleObscureNewPassword,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VjTextField(
              label: 'profile.change_password_confirm_label'.tr(),
              controller: _confirmPasswordController,
              onChanged: notifier.setConfirmPassword,
              errorText: confirmPasswordErrorText(form.confirmPasswordError),
              obscureText: form.obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitStepTwo(),
              suffixIcon: IconButton(
                tooltip: form.obscureConfirmPassword
                    ? 'auth.show_password'.tr()
                    : 'auth.hide_password'.tr(),
                icon: Icon(
                  form.obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: notifier.toggleObscureConfirmPassword,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: authState.isBusy ? null : notifier.backToEmailStep,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 48),
                ),
                child: Text('auth.resend_code_cta'.tr()),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: authState.isBusy
              ? null
              : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text('common.close'.tr()),
        ),
        TextButton(
          onPressed: authState.isBusy
              ? null
              : (form.codeSent ? _submitStepTwo : _submitStepOne),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 48),
          ),
          child: Text(
            form.codeSent
                ? 'common.save'.tr()
                : 'auth.forgot_password_cta'.tr(),
          ),
        ),
      ],
    );
  }
}