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
import 'package:via_justa/features/city/domain/city_overview_rules.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';

/// Banner en `HomePage` que muestra el evento oficial del municipio activo
/// según su ventana temporal real (`get_city_events_status`).
///
/// En carga, fallo o ausencia de eventos vigentes o próximos se contrae
/// limpiamente sin bloquear la pantalla ni presentar eventos inactivos como
/// si estuvieran en curso.
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
        final description = event.descriptionForLocale(localeCode);
        final isDescriptionFallback =
            event.isDescriptionFallbackForLocale(localeCode);

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VjBadge(
                  label: isActive
                      ? 'city.event_status_active'.tr()
                      : 'city.event_status_upcoming'.tr(),
                  icon: isActive
                      ? Icons.event_available_outlined
                      : Icons.event_note_outlined,
                ),
                if (decision.isDemo)
                  VjBadge(
                    label: 'city.demo_badge'.tr(),
                    icon: Icons.science_outlined,
                  ),
                if (isDescriptionFallback)
                  VjBadge(
                    label: 'city.item_fallback_badge'.tr(),
                    icon: Icons.translate_outlined,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isActive
                  ? 'city.event_banner_active_title'.tr()
                  : 'city.event_banner_upcoming_title'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              event.name,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    event.formattedDateRange(localeCode: localeCode),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (event.venue != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      event.venue!,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(description, style: textTheme.bodyMedium),
            ],
            if (!isActive) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'city.event_not_active_note'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            VjButton(
              label: 'city.event_banner_cta'.tr(),
              variant: isActive ? VjButtonVariant.primary : VjButtonVariant.tonal,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {
                GoRouter.maybeOf(
                  context,
                )?.push(AppRoutes.cityOverviewPath(municipalityCode));
              },
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: isActive
              ? Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: content,
                )
              : VjCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: content,
                ),
        );
      },
    );
  }
}
