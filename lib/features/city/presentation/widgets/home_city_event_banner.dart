import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/city/domain/city_overview_rules.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';

/// Tira editorial compacta de una sola fila en `HomePage` para el evento oficial del municipio.
class HomeCityEventBanner extends ConsumerWidget {
  const HomeCityEventBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannerAsync = ref.watch(homeCityEventBannerProvider);
    final municipalityCode = ref.watch(activeMunicipalityCodeProvider);
    final localeCode = normalizeCityLocale(
      Localizations.localeOf(context).languageCode,
    );

    return bannerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (decision) {
        final event = decision.event;
        if (decision.mode == CityBannerMode.noActiveEvent || event == null) {
          return const SizedBox.shrink();
        }

        final isActive = decision.mode == CityBannerMode.activeEvent;
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: VjCard(
            borderRadius: AppRadius.xl,
            backgroundColor: isActive
                ? AppColors.primarySoft.withValues(alpha: 0.7)
                : AppColors.surface,
            borderColor: isActive ? AppColors.primaryBorder : AppColors.border,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            onTap: () {
              GoRouter.maybeOf(
                context,
              )?.push(AppRoutes.cityOverviewPath(municipalityCode));
            },
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandNavy, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.festival_rounded
                        : Icons.event_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          VjBadge(
                            label: isActive
                                ? 'city.event_status_active'.tr()
                                : 'city.event_status_upcoming'.tr(),
                            icon: isActive
                                ? Icons.event_available_outlined
                                : Icons.event_note_outlined,
                            variant: isActive
                                ? VjBadgeVariant.navy
                                : VjBadgeVariant.tonal,
                          ),
                          if (decision.isDemo)
                            VjBadge(
                              label: 'city.demo_badge'.tr(),
                              variant: VjBadgeVariant.neutral,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.name,
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        event.formattedDateRange(localeCode: localeCode),
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
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
