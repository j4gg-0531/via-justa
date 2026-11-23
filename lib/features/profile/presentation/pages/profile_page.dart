import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/auth/presentation/state/password_management_providers.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_error_texts.dart';
import 'package:via_justa/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_document_dialog.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/businesses/presentation/widgets/my_businesses_sheet.dart';
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
    final selected = await showVjModalSheet<ProfileType>(
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
    final confirmed = await showVjConfirmDialog(
      context: context,
      icon: Icons.logout_rounded,
      tone: VjModalTone.destructive,
      title: 'profile.sign_out_dialog_title'.tr(),
      body: 'profile.sign_out_dialog_body'.tr(),
      cancelLabel: 'common.close'.tr(),
      confirmLabel: 'profile.sign_out_confirm_cta'.tr(),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(sessionControllerProvider).signOut();
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final updated = await showVjModalSheet<bool>(
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
    final confirmed = await showVjModalSheet<bool>(
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
    final initialName = ref.read(displayNameProvider);
    final saved = await showVjModalSheet<bool>(
      context: context,
      builder: (_) => _EditNameSheet(initialName: initialName),
    );
    if (saved == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'profile.name_updated'.tr() : 'auth.error.unknown'.tr(),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(profileTypeProvider);
    final authState = ref.watch(authControllerProvider);
    final locationLabel = ref.watch(selectedLocationLabelProvider);
    final showMyBusinesses = ref.watch(showMyBusinessesInProfileProvider);
    final myBusinessesCount = ref.watch(myBusinessesCountProvider);
    final textTheme = Theme.of(context).textTheme;
    Locale currentLocale;
    try {
      currentLocale = context.locale;
    } catch (_) {
      currentLocale =
          Localizations.maybeLocaleOf(context) ?? const Locale('es');
    }

    final cityName = locationLabel ?? 'home.default_city'.tr();
    final initials = _extractInitials(displayName);

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

    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'profile.title'.tr(),
                style: textTheme.headlineMedium?.copyWith(fontSize: 22),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),

              // Cabecera compacta de identidad (monograma Navy + datos + edición rápida)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandNavy.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: initials.isNotEmpty
                          ? Text(
                              initials,
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: textTheme.titleLarge?.copyWith(fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.email ?? 'profile.user_email'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        VjBadge(
                          label: '$profileName · $cityName',
                          variant: VjBadgeVariant.tonal,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'profile.edit_name_title'.tr(),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => _showEditNameDialog(context, ref),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Bloque agrupado 1: Preferencias en filas compactas
              VjCard(
                borderRadius: AppRadius.xl,
                elevated: true,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _CompactSettingRow(
                      icon: profileIcon,
                      label: 'profile.section_profile'.tr(),
                      value: profileName,
                      onTap: () => _showProfileSelectionDialog(context, ref),
                    ),
                    const Divider(height: 1, indent: 56),
                    _CompactSettingRow(
                      icon: Icons.location_on_outlined,
                      label: 'profile.section_location'.tr(),
                      value: cityName,
                      onTap: () => context.push(AppRoutes.departmentMap),
                    ),
                    if (showMyBusinesses) ...[
                      const Divider(height: 1, indent: 56),
                      _CompactSettingRow(
                        icon: Icons.storefront_outlined,
                        label: 'profile.section_my_businesses'.tr(),
                        value: myBusinessesCount > 0
                            ? '$myBusinessesCount'
                            : 'profile.my_businesses_register_hint'.tr(),
                        onTap: () {
                          if (myBusinessesCount > 0) {
                            showMyBusinessesSheet(context);
                          } else {
                            context.push(AppRoutes.businessRegister);
                          }
                        },
                      ),
                    ],
                    const Divider(height: 1, indent: 56),
                    _InlineLanguageRow(
                      label: 'profile.section_language'.tr(),
                      isSpanish: currentLocale.languageCode == 'es',
                      esLabel: 'profile.lang_es'.tr(),
                      enLabel: 'profile.lang_en'.tr(),
                      onSelectSpanish: () =>
                          _changeLocale(context, ref, const Locale('es')),
                      onSelectEnglish: () =>
                          _changeLocale(context, ref, const Locale('en')),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Bloque agrupado 2: Seguridad y Legal en filas compactas
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs + 2,
                ),
                child: Text(
                  'profile.section_security'.tr().toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              VjCard(
                borderRadius: AppRadius.xl,
                elevated: true,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _CompactSettingRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'profile.change_password_cta'.tr(),
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    const Divider(height: 1, indent: 56),
                    _CompactSettingRow(
                      icon: Icons.article_outlined,
                      label: 'profile.terms'.tr(),
                      onTap: () => showLegalDocumentDialog(
                        context,
                        ConsentDocType.termsAndConditions,
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _CompactSettingRow(
                      icon: Icons.shield_outlined,
                      label: 'profile.privacy'.tr(),
                      onTap: () => showLegalDocumentDialog(
                        context,
                        ConsentDocType.privacyPolicy,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Acción calmada de cierre de sesión
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: authState.isBusy
                      ? null
                      : () => _confirmSignOut(context, ref),
                  icon: const Icon(
                    Icons.logout,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  label: Text(
                    'profile.sign_out'.tr(),
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(48, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Eliminación definitiva de cuenta discreta + versión al pie
              Center(
                child: TextButton.icon(
                  onPressed: authState.isBusy
                      ? null
                      : () => _confirmDeleteAccount(
                          context,
                          ref,
                          isDemoMode: authState.usesDemoData,
                        ),
                  icon: authState.isBusy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: errorColor,
                          ),
                        )
                      : Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: errorColor,
                        ),
                  label: Text(
                    authState.isBusy
                        ? 'profile.delete_account_loading'.tr()
                        : 'profile.delete_account_cta'.tr(),
                    style: textTheme.labelMedium?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'profile.version'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extrae hasta dos iniciales limpias del nombre visible para el avatar.
String _extractInitials(String name) {
  final parts = name.trim().split(' ');
  final buffer = StringBuffer();
  for (final part in parts) {
    final clean = part.trim();
    if (clean.isEmpty) continue;
    buffer.write(clean[0].toUpperCase());
    if (buffer.length == 2) break;
  }
  return buffer.toString();
}

/// Hoja inferior para editar el nombre visible del usuario.
class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (ref.read(authControllerProvider).isBusy) return;
    final saved = await ref
        .read(authControllerProvider.notifier)
        .saveDisplayName(_nameController.text);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return VjModalSheet(
      icon: Icons.edit_outlined,
      title: 'profile.edit_name_title'.tr(),
      closeEnabled: !authState.isBusy,
      footer: VjModalActionRow(
        cancelLabel: 'common.close'.tr(),
        onCancel: authState.isBusy ? null : () => Navigator.of(context).pop(),
        confirmLabel: 'common.save'.tr(),
        onConfirm: authState.isBusy ? null : _save,
      ),
      child: VjTextField(
        label: 'auth.name'.tr(),
        hintText: 'profile.edit_name_hint'.tr(),
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) {},
        onSubmitted: (_) => _save(),
      ),
    );
  }
}

/// Hoja enriquecida de selección de tipo de perfil con confirmación explícita.
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
    return VjModalSheet(
      icon: Icons.badge_outlined,
      title: 'profile.dialog_profile_title'.tr(),
      subtitle: 'profile.section_profile_desc'.tr(),
      footer: VjModalActionRow(
        cancelLabel: 'common.close'.tr(),
        onCancel: () => Navigator.of(context).pop(),
        confirmLabel: 'common.save'.tr(),
        onConfirm: () => Navigator.of(context).pop(_selected.value),
      ),
      child: ValueListenableBuilder<ProfileType>(
        valueListenable: _selected,
        builder: (context, selectedType, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
      color: selected
          ? AppColors.primarySoft.withValues(alpha: 0.65)
          : AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? AppColors.primaryBorder : AppColors.border,
          width: selected ? 1.5 : 1,
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
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

    return VjModalSheet(
      icon: Icons.lock_outline_rounded,
      title: 'profile.change_password_title'.tr(),
      closeEnabled: !authState.isBusy,
      onClose: () => Navigator.of(context).pop(false),
      footer: VjModalActionRow(
        cancelLabel: 'common.close'.tr(),
        onCancel: authState.isBusy
            ? null
            : () => Navigator.of(context).pop(false),
        confirmLabel: 'common.save'.tr(),
        onConfirm: authState.isBusy ? null : _submit,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }
}

/// Hoja explícita de doble confirmación para eliminar la cuenta (`RF-06`).
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

    return VjModalSheet(
      icon: Icons.delete_forever_outlined,
      tone: VjModalTone.destructive,
      title: 'profile.delete_account_dialog_title'.tr(),
      onClose: () => Navigator.of(context).pop(false),
      footer: ValueListenableBuilder<bool>(
        valueListenable: _acknowledged,
        builder: (context, accepted, _) {
          return VjModalActionRow(
            cancelLabel: 'common.close'.tr(),
            onCancel: () => Navigator.of(context).pop(false),
            confirmLabel: 'profile.delete_account_confirm_cta'.tr(),
            onConfirm: accepted ? () => Navigator.of(context).pop(true) : null,
            confirmVariant: VjButtonVariant.destructive,
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: errorColor.withValues(alpha: 0.22)),
            ),
            child: Text(
              widget.isDemoMode
                  ? 'profile.delete_account_demo_body'.tr()
                  : 'profile.delete_account_dialog_body'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<bool>(
            valueListenable: _acknowledged,
            builder: (context, accepted, _) {
              return Material(
                color: AppColors.surfaceSubtle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: accepted ? errorColor : AppColors.border,
                    width: accepted ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  value: accepted,
                  onChanged: (value) => _acknowledged.value = value ?? false,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: errorColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  title: Text(
                    'profile.delete_account_confirm_check'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Fila compacta estilo Settings (1 sola línea en escala normal, adaptable a 2.0x).
class _CompactSettingRow extends StatelessWidget {
  const _CompactSettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stackValue = value != null && textScale >= 1.55;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: AppColors.brandNavy, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: stackValue
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value!,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (value != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  value!,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila compacta de idioma con conmutador segmentado en línea.
class _InlineLanguageRow extends StatelessWidget {
  const _InlineLanguageRow({
    required this.label,
    required this.isSpanish,
    required this.esLabel,
    required this.enLabel,
    required this.onSelectSpanish,
    required this.onSelectEnglish,
  });

  final String label;
  final bool isSpanish;
  final String esLabel;
  final String enLabel;
  final VoidCallback onSelectSpanish;
  final VoidCallback onSelectEnglish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    final switcher = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactLangChip(
            label: esLabel,
            selected: isSpanish,
            onTap: onSelectSpanish,
          ),
          const SizedBox(width: 2),
          _CompactLangChip(
            label: enLabel,
            selected: !isSpanish,
            onTap: onSelectEnglish,
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: textScale >= 1.25
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.language_rounded,
                          color: AppColors.brandNavy,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _CompactLangChip(
                        label: esLabel,
                        selected: isSpanish,
                        onTap: onSelectSpanish,
                      ),
                      _CompactLangChip(
                        label: enLabel,
                        selected: !isSpanish,
                        onTap: onSelectEnglish,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: AppColors.brandNavy,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  switcher,
                ],
              ),
      ),
    );
  }
}

class _CompactLangChip extends StatelessWidget {
  const _CompactLangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 38, minWidth: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: selected ? Border.all(color: AppColors.border) : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.brandNavy.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  widthFactor: 1.0,
                  child: Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: selected
                          ? AppColors.brandNavy
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
