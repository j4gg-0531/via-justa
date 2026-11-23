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
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/businesses/presentation/widgets/business_withdraw_dialog.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

/// Ficha compartida de negocio (VJ-17) accesible desde el directorio y desde el mapa.
class BusinessDetailPage extends ConsumerWidget {
  const BusinessDetailPage({
    super.key,
    required this.businessId,
    this.onOrderTap,
    this.onWhatsappTap,
    this.onDirectionsTap,
  });

  final String businessId;
  final void Function(BusinessDetail detail)? onOrderTap;
  final void Function(BusinessDetail detail)? onWhatsappTap;
  final void Function(BusinessDetail detail)? onDirectionsTap;

  Future<void> _runExternalAction(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final ok = await action();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('business_detail.action_launch_error'.tr())),
      );
    }
  }

  Future<void> _confirmWithdraw(
    BuildContext context,
    WidgetRef ref,
    BusinessDetail detail,
  ) async {
    final confirmed = await showWithdrawBusinessDialog(context);
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(businessOwnerActionProvider.notifier)
        .withdraw(detail.id);
    if (!context.mounted) return;
    if (ok) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.businesses);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('businesses.withdraw_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(businessDetailProvider(businessId));
    final currentOwnerId = ref.watch(currentBusinessOwnerIdProvider);
    final ownerBusy = ref.watch(businessOwnerActionProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final textTheme = Theme.of(context).textTheme;
    final localeCode =
        EasyLocalization.of(context)?.locale.languageCode ?? 'es';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detailAsync.asData?.value.name ?? 'businesses.title'.tr(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'common.back'.tr(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.businesses);
            }
          },
        ),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VjSkeletonBox(height: 200, borderRadius: AppRadius.xl),
                SizedBox(height: AppSpacing.lg),
                VjSkeletonBox(height: 24, width: 180),
                SizedBox(height: AppSpacing.sm),
                VjSkeletonBox(height: 16, width: 240),
                SizedBox(height: AppSpacing.lg),
                VjSkeletonBox(height: 120, borderRadius: AppRadius.xl),
                SizedBox(height: AppSpacing.md),
                VjSkeletonBox(height: 120, borderRadius: AppRadius.xl),
              ],
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'municipality.load_error'.tr(),
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  VjButton(
                    label: 'common.retry'.tr(),
                    onPressed: () =>
                        ref.invalidate(businessDetailProvider(businessId)),
                  ),
                ],
              ),
            ),
          ),
          data: (detail) {
            final isOwner =
                currentOwnerId != null && detail.ownerId == currentOwnerId;
            final description = detail.localizedDescription(localeCode);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Portada visual del negocio
                  _PhotoHeader(photos: detail.photos),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Cabecera editorial: categoría, nombre y valoración
                  VjCard(
                    borderRadius: AppRadius.xl,
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VjBadge(
                          label:
                              '${'businessRegistration.types.${detail.type}'.tr()} · $cityName',
                          variant: VjBadgeVariant.tonal,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          detail.name,
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _RatingSummaryRow(detail: detail),
                        const SizedBox(height: AppSpacing.md),

                        // 3. Dock rápido de 3 acciones (Pedir / WhatsApp / Cómo llegar)
                        _QuickActionsDock(
                          orderLabel: 'business_detail.action_order'.tr(),
                          whatsappLabel: 'business_detail.action_whatsapp'.tr(),
                          directionsLabel:
                              'business_detail.action_directions'.tr(),
                          onOrder: detail.canOrderExternal
                              ? () {
                                  if (onOrderTap != null) {
                                    onOrderTap!(detail);
                                  } else {
                                    _runExternalAction(
                                      context,
                                      () => ref
                                          .read(
                                            businessExternalActionProvider
                                                .notifier,
                                          )
                                          .openOrder(detail),
                                    );
                                  }
                                }
                              : null,
                          onWhatsapp: detail.canWhatsapp
                              ? () {
                                  if (onWhatsappTap != null) {
                                    onWhatsappTap!(detail);
                                  } else {
                                    _runExternalAction(
                                      context,
                                      () => ref
                                          .read(
                                            businessExternalActionProvider
                                                .notifier,
                                          )
                                          .openWhatsapp(
                                            detail,
                                            localeCode: localeCode,
                                          ),
                                    );
                                  }
                                }
                              : null,
                          onDirections: detail.canDirections
                              ? () {
                                  if (onDirectionsTap != null) {
                                    onDirectionsTap!(detail);
                                  } else {
                                    _runExternalAction(
                                      context,
                                      () => ref
                                          .read(
                                            businessExternalActionProvider
                                                .notifier,
                                          )
                                          .openDirections(detail),
                                    );
                                  }
                                }
                              : null,
                        ),
                        if (detail.canOrderExternal &&
                            detail.externalOrderDisclaimer.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            detail.externalOrderDisclaimer,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 4. Tarjeta de información y carta / precios
                  VjCard(
                    borderRadius: AppRadius.xl,
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'business_detail.section_info'.tr(),
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (detail.dishes.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'business_detail.section_dishes'.tr(),
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (var i = 0; i < detail.dishes.length; i++) ...[
                            if (i > 0) const Divider(height: AppSpacing.md),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                Text(
                                  detail.dishes[i].name,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  detail.dishes[i].formattedPriceCop,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 5. Tarjeta de horarios y ubicación
                  VjCard(
                    borderRadius: AppRadius.xl,
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'business_detail.section_hours'.tr(),
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (detail.schedule.isEmpty)
                          Text(
                            'business_detail.hours_not_specified'.tr(),
                            style: textTheme.bodyMedium,
                          )
                        else
                          for (final day in detail.schedule)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'businessRegistration.daySummary'.tr(
                                  args: [
                                    'businessRegistration.days.${day.dayKey}'
                                        .tr(),
                                    day.isOpen
                                        ? day.rangesText
                                        : 'businessRegistration.closed'.tr(),
                                  ],
                                ),
                                style: textTheme.bodySmall?.copyWith(
                                  color: day.isOpen
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontWeight: day.isOpen
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'business_detail.section_location'.tr(),
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                detail.address,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 6. Sección Valoraciones
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xs,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      'business_detail.section_ratings'.tr(),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  _BusinessRatingInteractiveSection(detail: detail),

                  if (isOwner) ...[
                    const SizedBox(height: AppSpacing.lg),
                    VjCard(
                      borderRadius: AppRadius.xl,
                      backgroundColor: AppColors.surfaceSubtle,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VjButton(
                            label: 'businesses.action_edit'.tr(),
                            variant: VjButtonVariant.outlined,
                            onPressed: ownerBusy
                                ? null
                                : () => context.push(
                                    AppRoutes.businessEditPath(detail.id),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          VjButton(
                            label: 'businesses.action_withdraw'.tr(),
                            variant: VjButtonVariant.outlined,
                            onPressed: ownerBusy
                                ? null
                                : () => _confirmWithdraw(context, ref, detail),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickActionsDock extends StatelessWidget {
  const _QuickActionsDock({
    required this.orderLabel,
    required this.whatsappLabel,
    required this.directionsLabel,
    required this.onOrder,
    required this.onWhatsapp,
    required this.onDirections,
  });

  final String orderLabel;
  final String whatsappLabel;
  final String directionsLabel;
  final VoidCallback? onOrder;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onDirections;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 300 || textScale >= 1.55;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VjButton(
                label: orderLabel,
                trailingIcon: Icons.north_east,
                onPressed: onOrder,
              ),
              const SizedBox(height: AppSpacing.sm),
              VjButton(
                label: whatsappLabel,
                variant: VjButtonVariant.outlined,
                trailingIcon: Icons.north_east,
                onPressed: onWhatsapp,
              ),
              const SizedBox(height: AppSpacing.sm),
              VjButton(
                label: directionsLabel,
                variant: VjButtonVariant.outlined,
                trailingIcon: Icons.north_east,
                onPressed: onDirections,
              ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.restaurant_menu_rounded,
                  label: orderLabel,
                  primary: true,
                  onTap: onOrder,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: whatsappLabel,
                  onTap: onWhatsapp,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.directions_outlined,
                  label: directionsLabel,
                  onTap: onDirections,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final bgColor = primary
        ? (enabled ? AppColors.primary : AppColors.border)
        : (enabled ? AppColors.surfaceSubtle : AppColors.background);
    final fgColor = primary
        ? (enabled ? Colors.white : AppColors.textMuted)
        : (enabled ? AppColors.textPrimary : AppColors.textMuted);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: primary
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: fgColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.photos});

  final List<BusinessPhotoItem> photos;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (photos.isEmpty || photos.first.bytes == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandNavy, AppColors.brandNavySurface],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'business_detail.photo_placeholder'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 204,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: PageView.builder(
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            if (photo.bytes == null) {
              return Container(
                color: AppColors.primarySoft,
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              );
            }
            return Image.memory(
              photo.bytes!,
              fit: BoxFit.cover,
              semanticLabel: 'businessRegistration.photo'.tr(),
            );
          },
        ),
      ),
    );
  }
}

class _RatingSummaryRow extends StatelessWidget {
  const _RatingSummaryRow({required this.detail});

  final BusinessDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!detail.hasRatings) {
      return Row(
        children: [
          const Icon(
            Icons.star_border,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'business_detail.no_ratings'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.star,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'business_detail.rating_summary'.tr(
              args: [
                detail.formattedRatingAverage,
                detail.ratingCount.toString(),
              ],
            ),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessRatingInteractiveSection extends ConsumerWidget {
  const _BusinessRatingInteractiveSection({required this.detail});

  final BusinessDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingState = ref.watch(businessRatingControllerProvider);
    final ratingNotifier = ref.read(businessRatingControllerProvider.notifier);
    final eligibility = ratingState.eligibilityFor(detail);
    final selectedStars = ratingState.effectiveStarsFor(detail);
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'business_detail.your_rating'.tr(),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (eligibility == BusinessRatingEligibility.ownerForbidden)
            Text(
              'business_detail.owner_cannot_rate'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (eligibility == BusinessRatingEligibility.requiresAuth)
            Text(
              'business_detail.auth_required_to_rate'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    key: ValueKey('rate-star-$star'),
                    onPressed: ratingState.submitting
                        ? null
                        : () => ratingNotifier.selectStars(detail.id, star),
                    tooltip: 'business_detail.star_label'.tr(
                      args: [star.toString()],
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: Icon(
                      selectedStars != null && star <= selectedStars
                          ? Icons.star
                          : Icons.star_border,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            VjButton(
              label: 'business_detail.save_rating'.tr(),
              onPressed: selectedStars == null || ratingState.submitting
                  ? null
                  : () => ratingNotifier.submitRating(detail),
            ),
            if (ratingState.savedBusinessId == detail.id) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'business_detail.rating_saved'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (ratingState.errorBusinessId == detail.id) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'business_detail.rating_error'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
