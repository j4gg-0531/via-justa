import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
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

  Future<void> _confirmWithdraw(
    BuildContext context,
    WidgetRef ref,
    BusinessDetail detail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('businessRegistration.withdrawTitle'.tr()),
        content: Text('businessRegistration.withdrawBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('businessRegistration.stay'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('businessRegistration.withdrawConfirm'.tr()),
          ),
        ],
      ),
    );
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Galería / Foto de portada del negocio
                  _PhotoHeader(photos: detail.photos),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Categoría · Municipio y título del negocio
                  Text(
                    '${'businessRegistration.types.${detail.type}'.tr()} · $cityName',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail.name,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 3. Resumen de valoraciones
                  _RatingSummaryRow(detail: detail),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. Acciones principales: Ver menú y pedir / WhatsApp
                  VjButton(
                    label: 'business_detail.action_order'.tr(),
                    trailingIcon: Icons.north_east,
                    onPressed: detail.canOrderExternal
                        ? () => onOrderTap?.call(detail)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  VjButton(
                    label: 'business_detail.action_whatsapp'.tr(),
                    variant: VjButtonVariant.outlined,
                    trailingIcon: Icons.north_east,
                    onPressed: detail.canWhatsapp
                        ? () => onWhatsappTap?.call(detail)
                        : null,
                  ),
                  if (detail.canOrderExternal &&
                      detail.externalOrderDisclaimer.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detail.externalOrderDisclaimer,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),

                  // 5. Sección Información y descripción
                  Text(
                    'business_detail.section_info'.tr(),
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    style: textTheme.bodyLarge,
                  ),

                  if (detail.dishes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'business_detail.section_dishes'.tr(),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final dish in detail.dishes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: VjCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              Text(
                                dish.name,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                dish.formattedPriceCop,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),

                  // 6. Sección Horario
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
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          'businessRegistration.daySummary'.tr(
                            args: [
                              'businessRegistration.days.${day.dayKey}'.tr(),
                              day.isOpen
                                  ? day.rangesText
                                  : 'businessRegistration.closed'.tr(),
                            ],
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),

                  // 7. Sección Ubicación + Cómo llegar
                  Text(
                    'business_detail.section_location'.tr(),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail.address,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  VjButton(
                    label: 'business_detail.action_directions'.tr(),
                    variant: VjButtonVariant.outlined,
                    trailingIcon: Icons.north_east,
                    onPressed: detail.canDirections
                        ? () => onDirectionsTap?.call(detail)
                        : null,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),

                  // 8. Sección Valoraciones
                  Text(
                    'business_detail.section_ratings'.tr(),
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RatingSummaryRow(detail: detail),

                  if (isOwner) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
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
                ],
              ),
            );
          },
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
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'business_detail.photo_placeholder'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
