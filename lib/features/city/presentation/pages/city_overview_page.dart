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
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';
import 'package:via_justa/features/city/domain/emergency_contact.dart';
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

  Future<void> _confirmEmergencyCall(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final telUri = contact.safeTelUri;
    if (telUri == null) return;
    final confirmed = await showVjConfirmDialog(
      context: context,
      icon: Icons.call_rounded,
      tone: contact.isUrgent ? VjModalTone.destructive : VjModalTone.primary,
      title: 'city.emergency_call_dialog_title'.tr(
        namedArgs: {'number': contact.displayNumber},
      ),
      body: 'city.emergency_call_dialog_body'.tr(
        namedArgs: {'name': contact.titleKey.tr()},
      ),
      cancelLabel: 'common.close'.tr(),
      confirmLabel: 'city.emergency_call_confirm'.tr(),
    );
    if (confirmed != true || !context.mounted) return;

    final launched = await ref
        .read(cityExternalLauncherProvider)
        .launchExternalUri(telUri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('city.emergency_call_error'.tr())),
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
          loading: () => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VjSkeletonBox(height: 190, borderRadius: AppRadius.xl),
                const SizedBox(height: AppSpacing.lg),
                const VjSkeletonBox(height: 28, width: 200),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'city.loading'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const VjSkeletonBox(height: 112, borderRadius: AppRadius.xl),
                const SizedBox(height: AppSpacing.md),
                const VjSkeletonBox(height: 112, borderRadius: AppRadius.xl),
              ],
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
                          variant: isDemoMode
                              ? VjBadgeVariant.neutral
                              : VjBadgeVariant.tonal,
                        ),
                      ],
                    ),

                    if (overview.hasLocaleFallback) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primarySoft.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.primaryBorder),
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
                        borderRadius: AppRadius.xl,
                        backgroundColor: AppColors.surfaceSubtle,
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
                      const SizedBox(height: AppSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CitySectionFilterPill(
                              label: 'city.section_all'.tr(),
                              selected: selectedSection == null,
                              onTap: () => ref
                                  .read(selectedCitySectionProvider.notifier)
                                  .select(null),
                            ),
                            for (final section in availableSections) ...[
                              const SizedBox(width: AppSpacing.xs + 2),
                              _CitySectionFilterPill(
                                label: _sectionLabelKey(section).tr(),
                                selected: selectedSection == section,
                                onTap: () => ref
                                    .read(selectedCitySectionProvider.notifier)
                                    .select(
                                      selectedSection == section
                                          ? null
                                          : section,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (selectedSection == null ||
                        selectedSection == CityContentSection.emergency) ...[
                      const SizedBox(height: AppSpacing.md),
                      _EmergencyDialerStrip(
                        contacts: kValleduparEmergencyContacts,
                        onCallTap: (contact) =>
                            _confirmEmergencyCall(context, ref, contact),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (contentItems.isEmpty)
                      VjCard(
                        borderRadius: AppRadius.xl,
                        backgroundColor: AppColors.surfaceSubtle,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? const [AppColors.brandNavy, AppColors.primary]
                      : [AppColors.primarySoft, AppColors.surfaceSubtle],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: isActive
                    ? null
                    : Border.all(color: AppColors.primaryBorder),
              ),
              child: Icon(
                Icons.festival_outlined,
                size: 22,
                color: isActive ? Colors.white : AppColors.primary,
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
                        label: statusKey.tr(),
                        icon: statusIcon,
                        variant:
                            isActive ? VjBadgeVariant.navy : VjBadgeVariant.tonal,
                      ),
                      if (event.isDemo)
                        VjBadge(
                          label: 'city.demo_badge'.tr(),
                          icon: Icons.science_outlined,
                          variant: VjBadgeVariant.neutral,
                        ),
                      if (isDescriptionFallback)
                        VjBadge(
                          label: 'city.item_fallback_badge'.tr(),
                          icon: Icons.translate_outlined,
                          variant: VjBadgeVariant.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    event.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
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
      return VjCard(
        borderRadius: AppRadius.xl,
        elevated: true,
        backgroundColor: AppColors.primarySoft.withValues(alpha: 0.55),
        borderColor: AppColors.primaryBorder,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: inner,
      );
    }

    return VjCard(
      borderRadius: AppRadius.xl,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: inner,
    );
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
      borderRadius: AppRadius.xl,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              VjBadge(
                label: _sectionLabelKey(item.section).tr(),
                variant: VjBadgeVariant.tonal,
              ),
              if (item.isLocaleFallback)
                VjBadge(
                  label: 'city.item_fallback_badge'.tr(),
                  icon: Icons.translate_outlined,
                  variant: VjBadgeVariant.neutral,
                ),
              if (item.isDemo)
                VjBadge(
                  label: 'city.demo_badge'.tr(),
                  icon: Icons.science_outlined,
                  variant: VjBadgeVariant.neutral,
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

class _CitySectionFilterPill extends StatelessWidget {
  const _CitySectionFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md + 2,
                  vertical: AppSpacing.xs + 5,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandNavy : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: selected ? AppColors.brandNavy : AppColors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
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

/// Bloque de marcación directa en 1 toque para líneas de emergencia oficiales (`tel:`).
class _EmergencyDialerStrip extends StatelessWidget {
  const _EmergencyDialerStrip({
    required this.contacts,
    required this.onCallTap,
  });

  final List<EmergencyContact> contacts;
  final ValueChanged<EmergencyContact> onCallTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'city.emergency_call_section_title'.tr(),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < contacts.length; i++) ...[
          VjCard(
            borderRadius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: contacts[i].isUrgent
                        ? errorColor.withValues(alpha: 0.10)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: contacts[i].isUrgent
                          ? errorColor.withValues(alpha: 0.25)
                          : AppColors.primaryBorder,
                    ),
                  ),
                  child: Icon(
                    contacts[i].isUrgent
                        ? Icons.emergency_outlined
                        : Icons.call_outlined,
                    size: 20,
                    color: contacts[i].isUrgent
                        ? errorColor
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contacts[i].titleKey.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contacts[i].descriptionKey.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contacts[i].displayNumber,
                        style: textTheme.labelMedium?.copyWith(
                          color: contacts[i].isUrgent
                              ? errorColor
                              : AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => onCallTap(contacts[i]),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text('city.emergency_call_cta'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: contacts[i].isUrgent
                        ? errorColor
                        : AppColors.brandNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < contacts.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
