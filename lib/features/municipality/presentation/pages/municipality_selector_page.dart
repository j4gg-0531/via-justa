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
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

/// Pantalla 4 · Selector de municipios de un departamento.
class MunicipalitySelectorPage extends ConsumerWidget {
  const MunicipalitySelectorPage({super.key, required this.departmentCode});

  final String departmentCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final department = Departments.byCode(departmentCode);
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

    final asyncMunicipalities = ref.watch(
      filteredMunicipalitiesProvider(departmentCode),
    );
    final hasQuery = ref.watch(municipalityQueryProvider).trim().isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: _HeaderWithSearch(
              department: department,
              onQueryChanged: ref
                  .read(municipalityQueryProvider.notifier)
                  .setQuery,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: hasQuery
                  ? asyncMunicipalities.when(
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
                                municipalitiesByDepartmentProvider(
                                  departmentCode,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      data: (filtered) {
                        if (filtered.isEmpty) {
                          return Padding(
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

                        return Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xl,
                            right: AppSpacing.xl,
                            bottom: AppSpacing.xl,
                          ),
                          child: VjCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < filtered.length; i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                  _MunicipalityTile(
                                    municipality: filtered[i],
                                    onTap: () {
                                      ref
                                          .read(
                                            selectedMunicipalityProvider
                                                .notifier,
                                          )
                                          .select(filtered[i]);
                                      FocusScope.of(context).unfocus();
                                      context.push(
                                        AppRoutes.municipalityPath(
                                          filtered[i].code,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const _SearchPrompt(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.travel_explore,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'municipality.search_prompt'.tr(),
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HeaderWithSearch extends StatelessWidget {
  const _HeaderWithSearch({
    required this.department,
    required this.onQueryChanged,
  });

  final Department department;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      top: AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'common.back'.tr(),
                        onPressed: () => context.pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600), // Dorado
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.wb_sunny,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      department.name,
                      style: textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'municipality.destination'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: 0,
          child: VjSearchField(
            hint: 'municipality.search_hint'.tr(),
            onChanged: onQueryChanged,
          ),
        ),
      ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(municipality.name, style: textTheme.titleMedium),
                ),
                if (municipality.isPilot)
                  VjBadge(label: 'municipality.pilot_badge'.tr()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
