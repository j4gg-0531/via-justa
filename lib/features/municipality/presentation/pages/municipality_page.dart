import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';
import 'package:via_justa/features/municipality/domain/city_landmark.dart';
import 'package:via_justa/features/municipality/domain/city_visual_identity.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_cultural_illustration.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_landmark_carousel.dart';

/// Pantallas 5 y 6 · Detalle de un municipio (piloto con galería fotográfica
/// editorial o municipio no piloto con ilustración regional y registro de interés).
class MunicipalityPage extends ConsumerWidget {
  const MunicipalityPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final municipality = ref.watch(municipalityByCodeProvider(code));

    return municipality.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _ErrorView(code: code),
      data: (municipality) {
        if (municipality == null) {
          return const _NotFoundView();
        }
        return municipality.isPilot
            ? _PilotView(municipality: municipality)
            : _NotPilotView(municipality: municipality);
      },
    );
  }
}

/// Estructura común de las vistas con municipio: atrás, contenido y acción fija.
class _MunicipalityScaffold extends StatelessWidget {
  const _MunicipalityScaffold({required this.child, required this.action});

  final Widget child;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: IconButton(
                tooltip: 'common.back'.tr(),
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.departmentMap);
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: child,
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla 5 (M14) · Municipio piloto con carrusel fotográfico de sitios
/// icónicos (CC), descripción concisa y acceso directo al inicio.
class _PilotView extends ConsumerWidget {
  const _PilotView({required this.municipality});

  final Municipality municipality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final departmentName = ref
        .watch(departmentByCodeProvider(municipality.departmentCode))
        ?.name;
    final landmarks = CityLandmarkCatalog.forMunicipality(municipality.code);
    final visualIdentity = CityVisualIdentityCatalog.forMunicipality(
      municipalityCode: municipality.code,
      departmentCode: municipality.departmentCode,
      isPilot: municipality.isPilot,
    );

    return _MunicipalityScaffold(
      action: VjButton(
        label: 'municipality.enter'.tr(),
        trailingIcon: Icons.arrow_forward,
        onPressed: () {
          ref.read(selectedMunicipalityProvider.notifier).select(municipality);
          ref
              .read(authControllerProvider.notifier)
              .saveCurrentMunicipality(municipality.code);
          context.go(AppRoutes.home);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (landmarks.isNotEmpty)
            CityLandmarkCarousel(landmarks: landmarks)
          else
            CityCulturalIllustrationBanner(
              identity: visualIdentity,
              cityName: municipality.name,
              departmentName: departmentName,
              isPilot: true,
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              VjBadge(
                label: 'municipality.pilot_available'.tr(),
                icon: Icons.check_circle_outline,
              ),
              if (departmentName != null)
                Text(
                  departmentName,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(municipality.name, style: textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(
            'municipality.valledupar_tagline'.tr(),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'municipality.valledupar_intro'.tr(),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: VjCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'municipality.pilot_includes_title'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _PilotFeatureChip(
                        icon: Icons.local_taxi_outlined,
                        label: 'municipality.pilot_feature_prices'.tr(),
                      ),
                      _PilotFeatureChip(
                        icon: Icons.description_outlined,
                        label: 'municipality.pilot_feature_contracts'.tr(),
                      ),
                      _PilotFeatureChip(
                        icon: Icons.location_city_outlined,
                        label: 'municipality.pilot_feature_guide'.tr(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _PilotFeatureChip extends StatelessWidget {
  const _PilotFeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla 6 (M15) · Municipio fuera del piloto: conserva la ilustración
/// regional por subregión del Cesar y permite registrar interés de apertura.
class _NotPilotView extends ConsumerWidget {
  const _NotPilotView({required this.municipality});

  final Municipality municipality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final departmentName = ref
        .watch(departmentByCodeProvider(municipality.departmentCode))
        ?.name;
    final interested = ref.watch(
      isMunicipalityInterestedProvider(municipality.code),
    );
    final visualIdentity = CityVisualIdentityCatalog.forMunicipality(
      municipalityCode: municipality.code,
      departmentCode: municipality.departmentCode,
      isPilot: municipality.isPilot,
    );

    return _MunicipalityScaffold(
      action: interested
          ? VjButton(
              label: 'municipality.notified'.tr(),
              leadingIcon: Icons.check,
              onPressed: null,
            )
          : VjButton(
              label: 'municipality.notify_me'.tr(),
              leadingIcon: Icons.notifications_none,
              onPressed: () => ref
                  .read(municipalityInterestProvider.notifier)
                  .register(municipality.code),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CityCulturalIllustrationBanner(
            identity: visualIdentity,
            cityName: municipality.name,
            departmentName: departmentName,
            isPilot: false,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 24,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  municipality.name,
                  style: textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          if (departmentName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(departmentName, style: textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.lg),
          VjCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'municipality.unverified_title'.tr(),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'municipality.unverified_body'.tr(),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Código DIVIPOLA desconocido: mensaje controlado, sin excepciones.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'municipality.not_found'.tr(),
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                VjButton(
                  label: 'common.back'.tr(),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.departmentMap);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error al cargar el municipio.
class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'municipality.load_error'.tr(),
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                VjButton(
                  label: 'common.retry'.tr(),
                  onPressed: () =>
                      ref.invalidate(municipalityByCodeProvider(code)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
