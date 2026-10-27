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
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

/// Pantallas 5 y 6 · Detalle de un municipio (piloto o fuera del piloto).
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xl,
                top: AppSpacing.sm,
              ),
              child: IconButton(
                tooltip: 'common.back'.tr(),
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.map);
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla 5 · Municipio piloto con acceso al inicio.
class _PilotView extends ConsumerWidget {
  const _PilotView({required this.municipality});

  final Municipality municipality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final departmentName = Departments.byCode(municipality.departmentCode)
        ?.name;

    return _MunicipalityScaffold(
      action: VjButton(
        label: 'municipality.enter'.tr(),
        trailingIcon: Icons.arrow_forward,
        onPressed: () {
          ref.read(selectedMunicipalityProvider.notifier).select(municipality);
          context.go(AppRoutes.home);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO: reemplazar por foto propia o con licencia y atribución.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  color: AppColors.primarySoft,
                  child: const Center(
                    child: Icon(
                      Icons.location_city,
                      size: 56,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          VjBadge(
            label: 'municipality.pilot_available'.tr(),
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(municipality.name, style: textTheme.headlineMedium),
          if (departmentName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(departmentName, style: textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Pantalla 6 · Municipio fuera del piloto: solo registra el interés.
class _NotPilotView extends ConsumerWidget {
  const _NotPilotView({required this.municipality});

  final Municipality municipality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final departmentName = Departments.byCode(municipality.departmentCode)
        ?.name;
    final interested = ref
        .watch(municipalityInterestProvider)
        .contains(municipality.code);

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
          const Icon(Icons.info_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(municipality.name, style: textTheme.headlineMedium),
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
                      context.go(AppRoutes.map);
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
