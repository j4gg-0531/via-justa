import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
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

  void _showLegalDialog(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text('profile.legal_dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
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
                    Row(
                      children: [
                        Icon(profileIcon, color: AppColors.primary, size: 24),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            profileName,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showProfileSelectionDialog(context, ref),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text('home.change_city'.tr()),
                        ),
                      ],
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
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            cityName,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.departmentMap),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text('profile.change_city'.tr()),
                        ),
                      ],
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
                      onTap: () => _showLegalDialog(context, 'profile.terms'.tr()),
                    ),
                    const Divider(color: AppColors.border),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('profile.privacy'.tr()),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showLegalDialog(context, 'profile.privacy'.tr()),
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
                  onPressed: () {
                    ref.read(sessionControllerProvider).signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    'profile.sign_out'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
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
