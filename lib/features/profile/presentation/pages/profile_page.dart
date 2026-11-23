import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/auth/presentation/state/password_management_providers.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_error_texts.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_document_dialog.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

/// Pantalla 17 (M17) · Perfil de usuario, ajustes de idioma, cambio de perfil y ubicación.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _showProfileSelectionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(profileTypeProvider) ?? ProfileType.visitor;
    final selected = await showDialog<ProfileType>(
      context: context,
      builder: (_) => _ProfileTypeSelectionDialog(initialType: current),
    );
    if (selected == null || !context.mounted) return;
    await _selectProfile(ref, context, selected);
  }

  /// Selecciona el perfil en local y lo persiste cuando el backend lo admite.
  ///
  /// `resident` sigue PROPUESTA (D11): se conserva en memoria y se avisa que
  /// todavía no se guarda en el servidor.
  Future<void> _selectProfile(
    WidgetRef ref,
    BuildContext context,
    ProfileType type,
  ) async {
    ref.read(profileTypeProvider.notifier).select(type);
    final persisted = await ref
        .read(authControllerProvider.notifier)
        .persistProfileType(type);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            persisted
                ? 'profile.profile_updated'.tr()
                : 'auth.error.profile_type_pending'.tr(),
          ),
        ),
      );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('profile.sign_out_dialog_title'.tr()),
        content: Text('profile.sign_out_dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text('common.close'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
              minimumSize: const Size(48, 48),
            ),
            child: Text('profile.sign_out_confirm_cta'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(sessionControllerProvider).signOut();
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('profile.password_updated'.tr())),
        );
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref, {
    required bool isDemoMode,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(isDemoMode: isDemoMode),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await ref.read(sessionControllerProvider).deleteAccount();
    if (!context.mounted) return;

    if (!deleted) {
      final message =
          authFailureText(ref.read(authControllerProvider).failure) ??
          'auth.error.unknown'.tr();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _changeLocale(BuildContext context, WidgetRef ref, Locale newLocale) {
    try {
      context.setLocale(newLocale);
    } catch (_) {}
    ref.read(authControllerProvider.notifier).saveLanguage(
      newLocale.languageCode,
    );
  }

  /// Permite editar el nombre visible y lo guarda en `public.profiles`.
  Future<void> _showEditNameDialog(BuildContext context, WidgetRef ref) async {
    var value = ref.read(displayNameProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('profile.edit_name_title'.tr()),
        content: TextFormField(
          initialValue: value,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'auth.name'.tr(),
            hintText: 'profile.edit_name_hint'.tr(),
          ),
          onChanged: (next) => value = next,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(dialogContext);
              final saved = await ref
                  .read(authControllerProvider.notifier)
                  .saveDisplayName(value);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    saved
                        ? 'profile.name_updated'.tr()
                        : 'auth.error.unknown'.tr(),
                  ),
                ),
              );
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(profileTypeProvider);
    final authState = ref.watch(authControllerProvider);
    final locationLabel = ref.watch(selectedLocationLabelProvider);
    final textTheme = Theme.of(context).textTheme;
    Locale currentLocale;
    try {
      currentLocale = context.locale;
    } catch (_) {
      currentLocale =
          Localizations.maybeLocaleOf(context) ?? const Locale('es');
    }

    final cityName = locationLabel ?? 'home.default_city'.tr();

    final String profileName;
    final IconData profileIcon;
    switch (profile) {
      case ProfileType.settler:
        profileName = 'onboarding.settler.title'.tr();
        profileIcon = Icons.home_work_outlined;
        break;
      case ProfileType.resident:
        profileName = 'onboarding.resident.title'.tr();
        profileIcon = Icons.storefront_outlined;
        break;
      case ProfileType.visitor:
      default:
        profileName = 'onboarding.visitor.title'.tr();
        profileIcon = Icons.luggage_outlined;
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Título y descripción
              Text(
                'profile.title'.tr(),
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'profile.subtitle'.tr(),
                style: textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Tarjeta de información del usuario
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primarySoft,
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authState.email ?? 'profile.user_email'.tr(),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'profile.edit_name_title'.tr(),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _showEditNameDialog(context, ref),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sección: Tipo de perfil
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.section_profile'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'profile.section_profile_desc'.tr(),
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProfileSettingValueRow(
                      icon: profileIcon,
                      value: profileName,
                      actionLabel: 'profile.change_profile'.tr(),
                      onActionPressed: () =>
                          _showProfileSelectionDialog(context, ref),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sección: Ubicación activa
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.section_location'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'profile.section_location_desc'.tr(),
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProfileSettingValueRow(
                      icon: Icons.location_on,
                      value: cityName,
                      actionLabel: 'profile.change_city'.tr(),
                      onActionPressed: () =>
                          context.push(AppRoutes.departmentMap),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sección: Idioma
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.section_language'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _changeLocale(context, ref, const Locale('es'));
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: currentLocale.languageCode == 'es'
                                  ? AppColors.primarySoft
                                  : AppColors.surface,
                              side: BorderSide(
                                color: currentLocale.languageCode == 'es'
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: currentLocale.languageCode == 'es' ? 2 : 1,
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(
                              'profile.lang_es'.tr(),
                              style: TextStyle(
                                color: currentLocale.languageCode == 'es'
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: currentLocale.languageCode == 'es'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _changeLocale(context, ref, const Locale('en'));
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: currentLocale.languageCode == 'en'
                                  ? AppColors.primarySoft
                                  : AppColors.surface,
                              side: BorderSide(
                                color: currentLocale.languageCode == 'en'
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: currentLocale.languageCode == 'en' ? 2 : 1,
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(
                              'profile.lang_en'.tr(),
                              style: TextStyle(
                                color: currentLocale.languageCode == 'en'
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: currentLocale.languageCode == 'en'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sección: Seguridad de la cuenta (Cambio de contraseña)
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.section_security'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'profile.section_security_desc'.tr(),
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProfileSettingValueRow(
                      icon: Icons.lock_outline,
                      value: '••••••••',
                      actionLabel: 'profile.change_password_cta'.tr(),
                      onActionPressed: () =>
                          _showChangePasswordDialog(context, ref),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sección: Acerca de y legal
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.section_about'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('profile.terms'.tr()),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showLegalDocumentDialog(
                        context,
                        ConsentDocType.termsAndConditions,
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('profile.privacy'.tr()),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showLegalDocumentDialog(
                        context,
                        ConsentDocType.privacyPolicy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Text(
                        'profile.version'.tr(),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Botón: Cerrar sesión
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: authState.isBusy
                      ? null
                      : () => _confirmSignOut(context, ref),
                  icon: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    'profile.sign_out'.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sección: Eliminación definitiva de cuenta (RF-06 / Ley 1581)
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.delete_account_section_title'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'profile.delete_account_section_desc'.tr(),
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authState.isBusy
                            ? null
                            : () => _confirmDeleteAccount(
                                context,
                                ref,
                                isDemoMode: authState.usesDemoData,
                              ),
                        icon: authState.isBusy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              )
                            : Icon(
                                Icons.delete_forever_outlined,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        label: Text(
                          authState.isBusy
                              ? 'profile.delete_account_loading'.tr()
                              : 'profile.delete_account_cta'.tr(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo enriquecido de selección de tipo de perfil con confirmación explícita.
class _ProfileTypeSelectionDialog extends StatefulWidget {
  const _ProfileTypeSelectionDialog({required this.initialType});

  final ProfileType initialType;

  @override
  State<_ProfileTypeSelectionDialog> createState() =>
      _ProfileTypeSelectionDialogState();
}

class _ProfileTypeSelectionDialogState
    extends State<_ProfileTypeSelectionDialog> {
  late final ValueNotifier<ProfileType> _selected = ValueNotifier<ProfileType>(
    widget.initialType,
  );

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      scrollable: true,
      title: Text('profile.dialog_profile_title'.tr()),
      content: ValueListenableBuilder<ProfileType>(
        valueListenable: _selected,
        builder: (context, selectedType, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'profile.section_profile_desc'.tr(),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileTypeOptionCard(
                icon: Icons.luggage_outlined,
                title: 'onboarding.visitor.title'.tr(),
                description: 'onboarding.visitor.description'.tr(),
                selected: selectedType == ProfileType.visitor,
                onTap: () => _selected.value = ProfileType.visitor,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileTypeOptionCard(
                icon: Icons.home_work_outlined,
                title: 'onboarding.settler.title'.tr(),
                description: 'onboarding.settler.description'.tr(),
                selected: selectedType == ProfileType.settler,
                onTap: () => _selected.value = ProfileType.settler,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileTypeOptionCard(
                icon: Icons.storefront_outlined,
                title: 'onboarding.resident.title'.tr(),
                description: 'onboarding.resident.description'.tr(),
                selected: selectedType == ProfileType.resident,
                onTap: () => _selected.value = ProfileType.resident,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text('common.close'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected.value),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 48),
          ),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}

class _ProfileTypeOptionCard extends StatelessWidget {
  const _ProfileTypeOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo para actualizar la contraseña de acceso desde el perfil.
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(changePasswordFormProvider.notifier);
    notifier.setCurrentPassword(_currentPasswordController.text);
    notifier.setNewPassword(_newPasswordController.text);
    notifier.setConfirmPassword(_confirmPasswordController.text);
    final ok = await notifier.submit();
    if (!mounted) return;
    final form = ref.read(changePasswordFormProvider);
    if (!form.isValid) return;

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
    final form = ref.watch(changePasswordFormProvider);
    final notifier = ref.read(changePasswordFormProvider.notifier);
    final authState = ref.watch(authControllerProvider);

    return AlertDialog(
      scrollable: true,
      title: Text('profile.change_password_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VjTextField(
            label: 'profile.change_password_current_label'.tr(),
            controller: _currentPasswordController,
            onChanged: notifier.setCurrentPassword,
            errorText: passwordErrorText(form.currentPasswordError),
            obscureText: form.obscureCurrentPassword,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              tooltip: form.obscureCurrentPassword
                  ? 'auth.show_password'.tr()
                  : 'auth.hide_password'.tr(),
              icon: Icon(
                form.obscureCurrentPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: notifier.toggleObscureCurrentPassword,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
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
            onSubmitted: (_) => _submit(),
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
          onPressed: authState.isBusy ? null : _submit,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 48),
          ),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Diálogo explícito de doble confirmación para eliminar la cuenta (`RF-06`).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.isDemoMode});

  final bool isDemoMode;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final ValueNotifier<bool> _acknowledged = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _acknowledged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;

    return AlertDialog(
      scrollable: true,
      title: Text('profile.delete_account_dialog_title'.tr()),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isDemoMode
                ? 'profile.delete_account_demo_body'.tr()
                : 'profile.delete_account_dialog_body'.tr(),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<bool>(
            valueListenable: _acknowledged,
            builder: (context, accepted, _) {
              return CheckboxListTile(
                value: accepted,
                onChanged: (value) => _acknowledged.value = value ?? false,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'profile.delete_account_confirm_check'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text('common.close'.tr()),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _acknowledged,
          builder: (context, accepted, _) {
            return TextButton(
              onPressed: accepted ? () => Navigator.of(context).pop(true) : null,
              style: TextButton.styleFrom(
                foregroundColor: errorColor,
                minimumSize: const Size(48, 48),
              ),
              child: Text('profile.delete_account_confirm_cta'.tr()),
            );
          },
        ),
      ],
    );
  }
}

/// Fila adaptable para mostrar un valor de ajuste con su acción sin desbordes en texto grande.
class _ProfileSettingValueRow extends StatelessWidget {
  const _ProfileSettingValueRow({
    required this.icon,
    required this.value,
    required this.actionLabel,
    required this.onActionPressed,
  });

  final IconData icon;
  final String value;
  final String actionLabel;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      value,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
