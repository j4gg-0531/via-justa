import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';
import 'package:via_justa/features/city/presentation/widgets/home_city_event_banner.dart';
import 'package:via_justa/features/home/domain/settler_installation_guide.dart';
import 'package:via_justa/features/home/presentation/state/settler_checklist_provider.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';
import 'package:via_justa/features/scan/domain/scan_mode.dart';
import 'package:via_justa/features/scan/presentation/state/scan_providers.dart';

/// Pantalla 4 · Inicio Bento adaptativo al perfil activo (`Visitante`, `Instalación`, `Local`).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _showContributeFallbackDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showVjConfirmDialog(
      context: context,
      icon: Icons.info_outline_rounded,
      title: title,
      body: body,
      confirmLabel: 'common.close'.tr(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileTypeProvider);
    final locationLabel = ref.watch(selectedLocationLabelProvider);
    final municipalityCode = ref.watch(activeMunicipalityCodeProvider);
    final textTheme = Theme.of(context).textTheme;
    final cityName = locationLabel ?? 'home.default_city'.tr();

    // Cuadrícula simétrica de 4 accesos rápidos (2x2 sin celdas huérfanas)
    final tiles = <_BentoTileData>[
      if (profile == ProfileType.resident)
        _BentoTileData(
          icon: Icons.document_scanner_outlined,
          title: 'home.scan_action_title'.tr(),
          subtitle: 'home.scan_action_desc'.tr(),
          highlighted: true,
          onTap: () => GoRouter.maybeOf(context)?.go(AppRoutes.scan),
        ),
      _BentoTileData(
        icon: Icons.map_outlined,
        title: 'home.map_action_title'.tr(),
        subtitle: 'home.map_action_desc'.tr(),
        highlighted: profile != ProfileType.resident,
        onTap: () => GoRouter.maybeOf(context)?.go(AppRoutes.map),
      ),
      _BentoTileData(
        icon: Icons.storefront_outlined,
        title: 'home.businesses_action_title'.tr(),
        subtitle: 'home.businesses_action_desc'.tr(),
        onTap: () => GoRouter.maybeOf(context)?.go(AppRoutes.businesses),
      ),
      if (profile != ProfileType.resident)
        _BentoTileData(
          icon: Icons.location_city_outlined,
          title: 'home.city_guide_action_title'.tr(),
          subtitle: 'home.city_guide_action_desc'.tr(),
          onTap: () {
            GoRouter.maybeOf(
              context,
            )?.push(AppRoutes.cityOverviewPath(municipalityCode));
          },
        ),
      _BentoTileData(
        icon: Icons.rate_review_outlined,
        title: 'home.contribute_action_title'.tr(),
        subtitle: 'home.contribute_action_desc'.tr(),
        onTap: () {
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            router.push(AppRoutes.priceContribute);
          } else {
            _showContributeFallbackDialog(
              context,
              title: 'home.contribute_dialog_title'.tr(),
              body: 'home.contribute_dialog_body'.tr(),
            );
          }
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // Barra superior compacta: píldora de ciudad + insignia de perfil activo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: 'home.change_city'.tr(),
                        child: Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            onTap: () => GoRouter.maybeOf(
                              context,
                            )?.push(AppRoutes.departmentMap),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        cityName,
                                        style: textTheme.labelMedium?.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ProfileBadge(profile: profile),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // 1. Tarjeta Hero Navy principal adaptada al perfil
              if (profile == ProfileType.settler)
                const _SettlerHomeView()
              else if (profile == ProfileType.resident)
                const _ResidentHomeView()
              else
                const _VisitorHomeView(),

              const SizedBox(height: AppSpacing.lg),

              // 2. Cuadrícula Bento 2x2 visible de inmediato (sin bloque gigante encima)
              Text(
                'home.tools_title'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              _BentoActionGrid(tiles: tiles),

              // 3. Tira compacta de evento oficial y guía cultural debajo del grid
              const HomeCityEventBanner(),

              if (profile == ProfileType.resident) ...[
                const SizedBox(height: AppSpacing.md),
                _CityGuideCompactStrip(
                  cityName: ref.watch(activeCityNameProvider),
                  onTap: () => GoRouter.maybeOf(
                    context,
                  )?.push(AppRoutes.cityOverviewPath(municipalityCode)),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Píldora del perfil seleccionado.
class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.profile});

  final ProfileType? profile;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (profile) {
      ProfileType.settler => (
          'home.profile_tag_settler'.tr(),
          Icons.home_work_outlined,
        ),
      ProfileType.resident => (
          'home.profile_tag_resident'.tr(),
          Icons.storefront_outlined,
        ),
      _ => ('home.profile_tag_visitor'.tr(), Icons.luggage_outlined),
    };

    return VjBadge(
      label: label,
      icon: icon,
      variant: VjBadgeVariant.neutral,
    );
  }
}

/// Tarjeta Hero oscura (#0F172A) compartida entre perfiles para una jerarquía limpia.
class _HomeHeroBannerCard extends StatelessWidget {
  const _HomeHeroBannerCard({
    required this.icon,
    required this.badgeLabel,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.onPressed,
  });

  final IconData icon;
  final String badgeLabel;
  final String title;
  final String description;
  final String ctaLabel;
  final IconData ctaIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.brandNavy,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.brandNavy,
              AppColors.brandNavySurface,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.36),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm + 2,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              badgeLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(icon, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  VjButton(
                    label: ctaLabel,
                    trailingIcon: ctaIcon,
                    onPressed: onPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M05: Inicio para Visitante / Turista.
class _VisitorHomeView extends ConsumerWidget {
  const _VisitorHomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemoMode = ref.watch(isDemoModeProvider);

    return _HomeHeroBannerCard(
      icon: Icons.verified_user_outlined,
      badgeLabel: isDemoMode
          ? 'home.visitor_banner_badge'.tr()
          : 'home.visitor_banner_live_badge'.tr(),
      title: 'home.visitor_banner_title'.tr(),
      description: 'home.visitor_banner_desc'.tr(),
      ctaLabel: 'home.scan_action_title'.tr(),
      ctaIcon: Icons.document_scanner_rounded,
      onPressed: () => GoRouter.maybeOf(context)?.go(AppRoutes.scan),
    );
  }
}

/// M04: Inicio para Instalación / Migrante (con acceso directo funcional a contratos y guía).
class _SettlerHomeView extends ConsumerWidget {
  const _SettlerHomeView();

  void _showSettlerGuideDialog(BuildContext context, String municipalityCode) {
    showVjModalSheet<void>(
      context: context,
      builder: (_) =>
          _SettlerInstallationGuideDialog(municipalityCode: municipalityCode),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final checklist = ref.watch(settlerChecklistProvider);
    final municipalityCode = ref.watch(activeMunicipalityCodeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeHeroBannerCard(
          icon: Icons.description_outlined,
          badgeLabel: 'home.settler_card_badge'.tr(),
          title: 'home.settler_card_title'.tr(),
          description: 'home.settler_card_desc'.tr(),
          ctaLabel: 'home.scan_action_title'.tr(),
          ctaIcon: Icons.arrow_forward_rounded,
          onPressed: () {
            ref.read(scanModeProvider.notifier).selectMode(ScanMode.contract);
            GoRouter.maybeOf(context)?.go(AppRoutes.scan);
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // Tarjetas de ruta de trámites interactiva y documentos contractuales
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: VjCard(
                  borderRadius: AppRadius.xl,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () =>
                      _showSettlerGuideDialog(context, municipalityCode),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.checklist_rtl_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'home.procedures_title'.tr(),
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      VjBadge(
                        label: 'home.settler_guide_progress'.tr(
                          namedArgs: {
                            'done': '${checklist.completedCount}',
                            'total': '${checklist.totalCount}',
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: VjCard(
                  borderRadius: AppRadius.xl,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () {
                    ref
                        .read(scanModeProvider.notifier)
                        .selectMode(ScanMode.contract);
                    GoRouter.maybeOf(context)?.go(AppRoutes.scan);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.folder_open_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'home.documents_title'.tr(),
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      VjBadge(
                        label: 'scan.tab_contract'.tr(),
                        variant: VjBadgeVariant.neutral,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Diálogo interactivo con la ruta y checklist de instalación en Valledupar (`ProfileType.settler`).
class _SettlerInstallationGuideDialog extends ConsumerWidget {
  const _SettlerInstallationGuideDialog({required this.municipalityCode});

  final String municipalityCode;

  void _openStepTool(
    BuildContext context,
    WidgetRef ref,
    SettlerInstallationTopic topic,
  ) {
    Navigator.of(context).pop();
    final router = GoRouter.maybeOf(context);
    if (router == null) return;

    switch (topic) {
      case SettlerInstallationTopic.leaseContract:
        ref.read(scanModeProvider.notifier).selectMode(ScanMode.contract);
        router.go(AppRoutes.scan);
        break;
      case SettlerInstallationTopic.civicGuidance:
        router.push(AppRoutes.cityOverviewPath(municipalityCode));
        break;
      case SettlerInstallationTopic.referenceFares:
        router.go(AppRoutes.map);
        break;
      case SettlerInstallationTopic.localDirectory:
        router.go(AppRoutes.businesses);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklist = ref.watch(settlerChecklistProvider);
    final notifier = ref.read(settlerChecklistProvider.notifier);

    return VjModalSheet(
      icon: Icons.checklist_rounded,
      title: 'home.settler_guide_title'.tr(),
      subtitle: 'home.settler_guide_subtitle'.tr(),
      headerBadge: VjBadge(
        label: 'home.settler_guide_progress'.tr(
          namedArgs: {
            'done': '${checklist.completedCount}',
            'total': '${checklist.totalCount}',
          },
        ),
      ),
      headerProgress: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: LinearProgressIndicator(
          value: checklist.progress,
          minHeight: 6,
          backgroundColor: AppColors.surfaceSubtle,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
      maxHeightFactor: 0.88,
      footer: VjButton(
        label: 'common.close'.tr(),
        variant: VjButtonVariant.navy,
        minHeight: 48,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kSettlerInstallationSteps.length; i++) ...[
            _SettlerStepCard(
              step: kSettlerInstallationSteps[i],
              completed: checklist.isCompleted(kSettlerInstallationSteps[i].id),
              onToggle: () => notifier.toggle(kSettlerInstallationSteps[i].id),
              onActionTap: () => _openStepTool(
                context,
                ref,
                kSettlerInstallationSteps[i].topic,
              ),
            ),
            if (i < kSettlerInstallationSteps.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SettlerStepCard extends StatelessWidget {
  const _SettlerStepCard({
    required this.step,
    required this.completed,
    required this.onToggle,
    required this.onActionTap,
  });

  final SettlerInstallationStep step;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: completed ? AppColors.primarySoft : AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: completed ? AppColors.primaryBorder : AppColors.border,
          width: completed ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      completed
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: completed ? AppColors.primary : AppColors.textMuted,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        step.titleKey.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              step.descriptionKey.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onActionTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(step.ctaKey.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M02 adaptado: Inicio para Local / Residente.
class _ResidentHomeView extends StatelessWidget {
  const _ResidentHomeView();

  @override
  Widget build(BuildContext context) {
    return _HomeHeroBannerCard(
      icon: Icons.storefront_rounded,
      badgeLabel: 'home.resident_card_badge'.tr(),
      title: 'home.resident_card_title'.tr(),
      description: 'home.resident_card_desc'.tr(),
      ctaLabel: 'businesses.register_action'.tr(),
      ctaIcon: Icons.storefront_outlined,
      onPressed: () =>
          GoRouter.maybeOf(context)?.push(AppRoutes.businessRegister),
    );
  }
}

class _BentoTileData {
  const _BentoTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;
}

/// Cuadrícula Bento 2xN responsiva (pasa a columna simple en escalas extremas para evitar overflows).
class _BentoActionGrid extends StatelessWidget {
  const _BentoActionGrid({required this.tiles});

  final List<_BentoTileData> tiles;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn =
            constraints.maxWidth < 300 || textScale >= 1.65;

        if (useSingleColumn) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                _BentoActionCard(tile: tiles[i], compact: false),
                if (i < tiles.length - 1) const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += 2) {
          final first = tiles[i];
          final second = i + 1 < tiles.length ? tiles[i + 1] : null;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _BentoActionCard(tile: first, compact: true),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: second != null
                        ? _BentoActionCard(tile: second, compact: true)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
          if (i + 2 < tiles.length) {
            rows.add(const SizedBox(height: AppSpacing.md));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _BentoActionCard extends StatelessWidget {
  const _BentoActionCard({
    required this.tile,
    required this.compact,
  });

  final _BentoTileData tile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tile.highlighted
            ? AppColors.primarySoft
            : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        tile.icon,
        color: tile.highlighted ? AppColors.primary : AppColors.textPrimary,
        size: 20,
      ),
    );

    return VjCard(
      borderRadius: AppRadius.xl,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: tile.onTap,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    iconBox,
                    const Spacer(),
                    const Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Text(
                  tile.title,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tile.subtitle,
                  style: textTheme.bodySmall?.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Row(
              children: [
                iconBox,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tile.title, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        tile.subtitle,
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
    );
  }
}

/// Tira compacta de acceso a Ciudad y Cultura cuando el perfil usa el grid 2x2 para otras acciones.
class _CityGuideCompactStrip extends StatelessWidget {
  const _CityGuideCompactStrip({
    required this.cityName,
    required this.onTap,
  });

  final String cityName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: AppColors.brandNavy,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.city_guide_action_title'.tr(),
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  cityName,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
