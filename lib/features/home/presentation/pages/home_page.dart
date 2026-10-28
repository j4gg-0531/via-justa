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
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

/// Pantalla 4 · Inicio adaptado al perfil activo (M04 Instalación, M05 Visitante, M02 adaptado Residente).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _showComingSoonDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileTypeProvider);
    final locationLabel = ref.watch(selectedLocationLabelProvider);
    final displayName = ref.watch(displayNameProvider);
    final textTheme = Theme.of(context).textTheme;

    final cityName = locationLabel ?? 'home.default_city'.tr();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Cabecera institucional con saludo y ubicación
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home.greeting'.tr(
                            namedArgs: {'name': displayName},
                          ),
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              cityName,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.departmentMap),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: Text('home.change_city'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Insignia del perfil activo
              _ProfileBadge(profile: profile),

              const SizedBox(height: AppSpacing.xl),

              // Vista adaptada al perfil seleccionado
              if (profile == ProfileType.settler)
                _SettlerHomeView(onShowDialog: _showComingSoonDialog)
              else if (profile == ProfileType.resident)
                _ResidentHomeView(onShowDialog: _showComingSoonDialog)
              else
                _VisitorHomeView(onShowDialog: _showComingSoonDialog),

              const SizedBox(height: AppSpacing.xl),

              // Sección de herramientas principales (común a todos los perfiles)
              Text(
                'home.tools_title'.tr(),
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'home.tools_subtitle'.tr(),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),

              _QuickActionCard(
                icon: Icons.document_scanner_outlined,
                title: 'home.scan_action_title'.tr(),
                subtitle: 'home.scan_action_desc'.tr(),
                onTap: () => context.go(AppRoutes.scan),
              ),
              const SizedBox(height: AppSpacing.md),
              _QuickActionCard(
                icon: Icons.map_outlined,
                title: 'home.map_action_title'.tr(),
                subtitle: 'home.map_action_desc'.tr(),
                onTap: () => context.go(AppRoutes.map),
              ),
              const SizedBox(height: AppSpacing.md),
              _QuickActionCard(
                icon: Icons.storefront_outlined,
                title: 'home.businesses_action_title'.tr(),
                subtitle: 'home.businesses_action_desc'.tr(),
                onTap: () => context.go(AppRoutes.businesses),
              ),
              const SizedBox(height: AppSpacing.md),
              _QuickActionCard(
                icon: Icons.rate_review_outlined,
                title: 'home.contribute_action_title'.tr(),
                subtitle: 'home.contribute_action_desc'.tr(),
                badge: 'common.demo_badge'.tr(),
                onTap: () => _showComingSoonDialog(
                  context,
                  title: 'home.contribute_dialog_title'.tr(),
                  body: 'home.contribute_dialog_body'.tr(),
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

/// Píldora del perfil seleccionado
class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.profile});

  final ProfileType? profile;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;

    switch (profile) {
      case ProfileType.settler:
        label = 'home.profile_tag_settler'.tr();
        icon = Icons.home_work_outlined;
        break;
      case ProfileType.resident:
        label = 'home.profile_tag_resident'.tr();
        icon = Icons.storefront_outlined;
        break;
      case ProfileType.visitor:
      default:
        label = 'home.profile_tag_visitor'.tr();
        icon = Icons.luggage_outlined;
        break;
    }

    return VjBadge(label: label, icon: icon);
  }
}

/// M05: Inicio para Visitante / Turista
class _VisitorHomeView extends StatelessWidget {
  const _VisitorHomeView({required this.onShowDialog});

  final void Function(
    BuildContext, {
    required String title,
    required String body,
  }) onShowDialog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.festival,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'home.visitor_banner_title'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              VjBadge(
                label: 'home.visitor_banner_badge'.tr(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'home.visitor_banner_desc'.tr(),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          VjButton(
            label: 'home.scan_action_title'.tr(),
            trailingIcon: Icons.document_scanner,
            onPressed: () => context.go(AppRoutes.scan),
          ),
        ],
      ),
    );
  }
}

/// M04: Inicio para Instalación / Migrante
class _SettlerHomeView extends StatelessWidget {
  const _SettlerHomeView({required this.onShowDialog});

  final void Function(
    BuildContext, {
    required String title,
    required String body,
  }) onShowDialog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'home.settler_card_title'.tr(),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  VjBadge(label: 'home.settler_card_badge'.tr()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'home.settler_card_desc'.tr(),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              VjButton(
                label: 'home.scan_action_title'.tr(),
                trailingIcon: Icons.arrow_forward,
                onPressed: () => context.go(AppRoutes.scan),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Tarjetas de trámites con insignia Próximamente
        Row(
          children: [
            Expanded(
              child: VjCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () => onShowDialog(
                  context,
                  title: 'home.procedures_title'.tr(),
                  body: 'home.feature_dialog_body'.tr(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'home.procedures_title'.tr(),
                      style: textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    VjBadge(label: 'common.coming_soon'.tr()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: VjCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () => onShowDialog(
                  context,
                  title: 'home.documents_title'.tr(),
                  body: 'home.feature_dialog_body'.tr(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.folder_shared_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'home.documents_title'.tr(),
                      style: textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    VjBadge(label: 'common.coming_soon'.tr()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// M02 adaptado: Inicio para Local / Residente
class _ResidentHomeView extends StatelessWidget {
  const _ResidentHomeView({required this.onShowDialog});

  final void Function(
    BuildContext, {
    required String title,
    required String body,
  }) onShowDialog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'home.resident_card_title'.tr(),
                  style: textTheme.titleMedium,
                ),
              ),
              VjBadge(label: 'home.resident_card_badge'.tr()),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'home.resident_card_desc'.tr(),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          VjButton(
            label: 'businesses.register_action'.tr(),
            trailingIcon: Icons.storefront,
            onPressed: () => onShowDialog(
              context,
              title: 'businesses.register_dialog_title'.tr(),
              body: 'businesses.register_dialog_body'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de acceso rápido a una herramienta
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      VjBadge(label: badge!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
