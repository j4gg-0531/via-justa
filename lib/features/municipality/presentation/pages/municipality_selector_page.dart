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
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';
import 'package:via_justa/features/municipality/domain/city_landmark.dart';
import 'package:via_justa/features/municipality/domain/city_visual_identity.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_cultural_illustration.dart';

/// Pantalla 4 (M13) · Selector de municipios con cabecera clara de alto
/// contraste, tarjeta piloto destacada en un toque y lista filtrable en vivo.
class MunicipalitySelectorPage extends ConsumerWidget {
  const MunicipalitySelectorPage({super.key, required this.departmentCode});

  final String departmentCode;

  void _openMunicipality(
    BuildContext context,
    WidgetRef ref,
    Municipality municipality,
  ) {
    ref.read(selectedMunicipalityProvider.notifier).select(municipality);
    FocusScope.of(context).unfocus();
    context.push(AppRoutes.municipalityPath(municipality.code));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final department = ref.watch(departmentByCodeProvider(departmentCode));
    final textTheme = Theme.of(context).textTheme;

    if (department == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('map.unavailable'.tr(), style: textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                VjButton(
                  label: 'common.back'.tr(),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final partitionedAsync = ref.watch(
      partitionedMunicipalitiesProvider(departmentCode),
    );
    final totalCount = ref.watch(
      departmentMunicipalityCountProvider(departmentCode),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: _CompactSelectorHeader(
              department: department,
              totalCount: totalCount,
              onQueryChanged: ref
                  .read(municipalityQueryProvider.notifier)
                  .setDebouncedQuery,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: partitionedAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Text(
                        'municipality.load_error'.tr(),
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      VjButton(
                        label: 'common.retry'.tr(),
                        onPressed: () => ref.invalidate(
                          municipalitiesByDepartmentProvider(departmentCode),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (partition) {
                  if (partition.isEmpty) {
                    return VjCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'municipality.no_results'.tr(),
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (partition.pilot.isNotEmpty) ...[
                        _SectionLabel(
                          label: 'municipality.available_now_section'.tr(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (var i = 0; i < partition.pilot.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.md),
                          _PilotMunicipalityCard(
                            municipality: partition.pilot[i],
                            onTap: () => _openMunicipality(
                              context,
                              ref,
                              partition.pilot[i],
                            ),
                          ),
                        ],
                        if (partition.upcoming.isNotEmpty)
                          const SizedBox(height: AppSpacing.xl),
                      ],
                      if (partition.upcoming.isNotEmpty) ...[
                        _SectionLabel(
                          label: 'municipality.other_municipalities_section'.tr(
                            namedArgs: {'count': '${partition.upcoming.length}'},
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        VjCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < partition.upcoming.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                _MunicipalityTile(
                                  municipality: partition.upcoming[i],
                                  onTap: () => _openMunicipality(
                                    context,
                                    ref,
                                    partition.upcoming[i],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSelectorHeader extends StatelessWidget {
  const _CompactSelectorHeader({
    required this.department,
    required this.totalCount,
    required this.onQueryChanged,
  });

  final Department department;
  final int? totalCount;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'common.back'.tr(),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.departmentMap);
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              department.name,
                              style: textTheme.headlineMedium,
                            ),
                            if (totalCount != null && totalCount! > 0)
                              VjBadge(
                                label: 'municipality.count_badge'.tr(
                                  namedArgs: {'count': '$totalCount'},
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'municipality.selector_subtitle'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              VjSearchField(
                hint: 'municipality.search_hint'.tr(),
                onChanged: onQueryChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _PilotMunicipalityCard extends StatelessWidget {
  const _PilotMunicipalityCard({
    required this.municipality,
    required this.onTap,
  });

  final Municipality municipality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cover = CityLandmarkCatalog.coverForMunicipality(municipality.code);
    final identity = CityVisualIdentityCatalog.forMunicipality(
      municipalityCode: municipality.code,
      departmentCode: municipality.departmentCode,
      isPilot: true,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portada fotográfica limpia con badge piloto en esquina superior
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null)
                      Image.asset(
                        cover.assetPath,
                        fit: BoxFit.cover,
                        semanticLabel: cover.titleKey.tr(),
                        errorBuilder: (context, error, stackTrace) =>
                            CustomPaint(
                              painter: CulturalLandscapePainter(
                                identity: identity,
                                showCenterpiece: false,
                              ),
                            ),
                      )
                    else
                      CustomPaint(
                        painter: CulturalLandscapePainter(
                          identity: identity,
                          showCenterpiece: false,
                        ),
                      ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              AppColors.textPrimary.withValues(alpha: 0.30),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(
                          'municipality.pilot_available'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Pie blanco de tamaño adaptable (cero desbordes a 2.0x)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                municipality.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'municipality.pilot_card_subtitle'.tr(),
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MunicipalityTile extends StatelessWidget {
  const _MunicipalityTile({required this.municipality, required this.onTap});

  final Municipality municipality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final identity = CityVisualIdentityCatalog.forMunicipality(
      municipalityCode: municipality.code,
      departmentCode: municipality.departmentCode,
      isPilot: municipality.isPilot,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                DepartmentCulturalEmblemBadge(
                  identity: identity,
                  size: 38,
                  highlight: municipality.isPilot,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(municipality.name, style: textTheme.titleMedium),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'common.coming_soon'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        identity.tagKey.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
