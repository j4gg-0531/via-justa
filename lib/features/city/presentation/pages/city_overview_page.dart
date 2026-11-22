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
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';
import 'package:via_justa/features/city/presentation/widgets/city_editorial_photo_hero.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';
import 'package:via_justa/features/municipality/domain/city_landmark.dart';
import 'package:via_justa/features/municipality/domain/city_visual_identity.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_cultural_illustration.dart';

/// Vista de ciudad verificada (`VJ-15`): muestra identidad cultural bilingüe
/// (`es`/`en`), fuentes institucionales auditables y eventos oficiales.
class CityOverviewPage extends ConsumerWidget {
  const CityOverviewPage({super.key, required this.municipalityCode});

  final String municipalityCode;

  void _navigateBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(AppRoutes.home);
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openSourceUrl(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    final launched = await ref
        .read(cityExternalLauncherProvider)
        .launchExternalUri(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('city.source_open_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = normalizeCityLocale(
      Localizations.localeOf(context).languageCode,
    );
    final CityOverviewRequest request = (
      municipalityCode: municipalityCode,
      localeCode: localeCode,
    );

    final overviewAsync = ref.watch(cityOverviewProvider(request));
    final filteredContentAsync = ref.watch(
      filteredCityContentProvider(request),
    );
    final availableSections = ref.watch(cityAvailableSectionsProvider(request));
    final selectedSection = ref.watch(selectedCitySectionProvider);
    final isDemoMode = ref.watch(isDemoModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'common.back'.tr(),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _navigateBack(context),
        ),
        title: Text('city.page_title'.tr()),
      ),
      body: SafeArea(
        child: overviewAsync.when(
          loading: () => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'city.loading'.tr(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          error: (error, stackTrace) => _CityErrorView(
            error: error,
            onRetry: () => ref.invalidate(cityOverviewProvider(request)),
            onBack: () => _navigateBack(context),
          ),
          data: (overview) {
            final textTheme = Theme.of(context).textTheme;
            final department = ref.watch(
              departmentByCodeProvider(overview.departmentCode),
            );
            final heroLandmark = CityLandmarkCatalog.editorialHeroForMunicipality(
              overview.municipalityCode,
            );
            final visualIdentity = CityVisualIdentityCatalog.forMunicipality(
              municipalityCode: overview.municipalityCode,
              departmentCode: overview.departmentCode,
              isPilot: overview.isPilot,
            );
            final contentItems =
                filteredContentAsync.asData?.value ?? const <CityContentItem>[];

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(cityOverviewProvider(request));
                await ref.read(cityOverviewProvider(request).future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (heroLandmark != null)
                      CityEditorialPhotoHero(
                        landmark: heroLandmark,
                        captionLabel: 'city.hero_caption'.tr(),
                      )
                    else
                      CityCulturalIllustrationBanner(
                        identity: visualIdentity,
                        cityName: overview.municipalityName,
                        departmentName: department?.name,
                        isPilot: overview.isPilot,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      overview.municipalityName,
                      style: textTheme.headlineMedium,
                    ),
                    if (department != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(department.name, style: textTheme.bodyLarge),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        VjBadge(
                          label: isDemoMode
                              ? 'city.demo_badge'.tr()
                              : 'city.verified_badge'.tr(),
                          icon: isDemoMode
                              ? Icons.science_outlined
                              : Icons.verified_outlined,
                        ),
                      ],
                    ),

                    if (overview.hasLocaleFallback) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.translate_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'city.locale_fallback_notice'.tr(),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'city.events_section_title'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (overview.events.isEmpty)
                      VjCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'city.events_empty'.tr(),
                          style: textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (var i = 0; i < overview.events.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _CityEventCard(
                          event: overview.events[i],
                          localeCode: localeCode,
                        ),
                      ],

                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'city.content_section_title'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    if (availableSections.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          ChoiceChip(
                            label: Text('city.section_all'.tr()),
                            selected: selectedSection == null,
                            onSelected: (_) => ref
                                .read(selectedCitySectionProvider.notifier)
                                .select(null),
                          ),
                          for (final section in availableSections)
                            ChoiceChip(
                              label: Text(_sectionLabelKey(section).tr()),
                              selected: selectedSection == section,
                              onSelected: (isSelected) => ref
                                  .read(selectedCitySectionProvider.notifier)
                                  .select(isSelected ? section : null),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (contentItems.isEmpty)
                      VjCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'city.content_empty'.tr(),
                          style: textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (var i = 0; i < contentItems.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _CityContentCard(
                          item: contentItems[i],
                          onOpenSource: (uri) =>
                              _openSourceUrl(context, ref, uri),
                        ),
                      ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CityEventCard extends StatelessWidget {
  const _CityEventCard({
    required this.event,
    required this.localeCode,
  });

  final CityEvent event;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isActive =
        event.temporalStatus == CityEventTemporalStatus.active &&
        event.isCurrentlyActive;
    final description = event.descriptionForLocale(localeCode);
    final isDescriptionFallback =
        event.isDescriptionFallbackForLocale(localeCode);

    final (String statusKey, IconData statusIcon) =
        switch (event.temporalStatus) {
      CityEventTemporalStatus.active => (
        'city.event_status_active',
        Icons.event_available_outlined,
      ),
      CityEventTemporalStatus.upcoming => (
        'city.event_status_upcoming',
        Icons.schedule_outlined,
      ),
      CityEventTemporalStatus.past => (
        'city.event_status_past',
        Icons.history_outlined,
      ),
    };

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            VjBadge(label: statusKey.tr(), icon: statusIcon),
            if (event.isDemo)
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
        Text(event.name, style: textTheme.titleMedium),
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
              Expanded(child: Text(event.venue!, style: textTheme.bodySmall)),
            ],
          ),
        ],
        if (description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: textTheme.bodyMedium),
        ],
        if (event.temporalStatus == CityEventTemporalStatus.upcoming) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'city.event_not_active_note'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (event.sourceCitation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'city.source_label'.tr(
              namedArgs: {'source': event.sourceCitation!},
            ),
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );

    if (isActive) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: inner,
      );
    }

    return VjCard(padding: const EdgeInsets.all(AppSpacing.lg), child: inner);
  }
}

class _CityContentCard extends StatelessWidget {
  const _CityContentCard({
    required this.item,
    required this.onOpenSource,
  });

  final CityContentItem item;
  final void Function(Uri uri) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final safeSourceUri = item.safeSourceUri;
    final safeAssetPath = item.safeLicensedAssetPath;
    final safeImageUri = item.safeLicensedImageUri;

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              VjBadge(label: _sectionLabelKey(item.section).tr()),
              if (item.isLocaleFallback)
                VjBadge(
                  label: 'city.item_fallback_badge'.tr(),
                  icon: Icons.translate_outlined,
                ),
              if (item.isDemo)
                VjBadge(
                  label: 'city.demo_badge'.tr(),
                  icon: Icons.science_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(item.body, style: textTheme.bodyMedium),
          if (item.hasLicensedImage) ...[
            const SizedBox(height: AppSpacing.md),
            if (safeAssetPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    safeAssetPath,
                    fit: BoxFit.cover,
                    semanticLabel: item.title,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ] else if (safeImageUri != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  safeImageUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              'city.image_license_label'.tr(
                namedArgs: {'license': item.imageLicense!},
              ),
              style: textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'city.source_label'.tr(namedArgs: {'source': item.sourceCitation}),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (safeSourceUri != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => onOpenSource(safeSourceUri),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(48, 48),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text('city.open_source_cta'.tr())),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CityErrorView extends StatelessWidget {
  const _CityErrorView({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final kind = error is CityLoadException
        ? (error as CityLoadException).kind
        : CityLoadErrorKind.unknown;

    final (String messageKey, bool allowRetry) = switch (kind) {
      CityLoadErrorKind.notPilot => ('city.error_not_pilot', false),
      CityLoadErrorKind.notFound => ('city.error_not_found', false),
      CityLoadErrorKind.network => ('city.error_network', true),
      CityLoadErrorKind.unknown => ('city.error_generic', true),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_city_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              messageKey.tr(),
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (allowRetry)
              VjButton(
                label: 'common.retry'.tr(),
                leadingIcon: Icons.refresh,
                onPressed: onRetry,
              )
            else
              VjButton(
                label: 'common.back'.tr(),
                leadingIcon: Icons.arrow_back,
                onPressed: onBack,
              ),
          ],
        ),
      ),
    );
  }
}

String _sectionLabelKey(CityContentSection section) {
  switch (section) {
    case CityContentSection.welcome:
      return 'city.section_welcome';
    case CityContentSection.context:
      return 'city.section_context';
    case CityContentSection.culture:
      return 'city.section_culture';
    case CityContentSection.places:
      return 'city.section_places';
    case CityContentSection.gastronomy:
      return 'city.section_gastronomy';
    case CityContentSection.emergency:
      return 'city.section_emergency';
  }
}
