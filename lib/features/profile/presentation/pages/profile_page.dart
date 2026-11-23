import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('profile.dialog_profile_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.luggage_outlined, color: AppColors.primary),
              title: Text('onboarding.visitor.title'.tr()),
              onTap: () {
                _selectProfile(ref, dialogContext, ProfileType.visitor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_work_outlined, color: AppColors.primary),
              title: Text('onboarding.settler.title'.tr()),
              onTap: () {
                _selectProfile(ref, dialogContext, ProfileType.settler);
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
              title: Text('onboarding.resident.title'.tr()),
              onTap: () {
                _selectProfile(ref, dialogContext, ProfileType.resident);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Selecciona el perfil en local y lo persiste cuando el backend lo admite.
  ///
  /// `resident` sigue PROPUESTA (D11): se conserva en memoria y se avisa que
  /// todavía no se guarda en el servidor.
  Future<void> _selectProfile(
    WidgetRef ref,
    BuildContext dialogContext,
    ProfileType type,
  ) async {
    ref.read(profileTypeProvider.notifier).select(type);
    final persisted = await ref
        .read(authControllerProvider.notifier)
        .persistProfileType(type);
    if (!dialogContext.mounted) return;

    final messenger = ScaffoldMessenger.of(dialogContext);
    Navigator.of(dialogContext).pop();
    if (!persisted) {
      messenger.showSnackBar(
        SnackBar(content: Text('auth.error.profile_type_pending'.tr())),
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
                      actionLabel: 'home.change_city'.tr(),
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
                      : () {
                          ref.read(sessionControllerProvider).signOut();
                        },
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
