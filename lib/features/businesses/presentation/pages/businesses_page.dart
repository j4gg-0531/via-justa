import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/currency/currency_formatter.dart';
import 'package:via_justa/core/currency/currency_providers.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/activity/presentation/state/user_activity_providers.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/businesses/presentation/widgets/business_withdraw_dialog.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Pantalla 21 (M21) · Directorio compacto y escaneable de comercios locales.
class BusinessesPage extends ConsumerWidget {
  const BusinessesPage({super.key});

  void _openBusinessDetail(BuildContext context, String businessId) {
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.businessDetailPath(businessId));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BusinessDetailPage(businessId: businessId),
        ),
      );
    }
  }

  Future<void> _confirmWithdraw(
    BuildContext context,
    WidgetRef ref,
    Business business,
  ) async {
    final confirmed = await showWithdrawBusinessDialog(context);
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(businessOwnerActionProvider.notifier)
        .withdraw(business.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('businesses.withdraw_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partitionedAsync = ref.watch(partitionedBusinessesProvider);
    final selectedCategory = ref.watch(businessCategoryProvider);
    final ownerBusy = ref.watch(businessOwnerActionProvider);
    final canLoadMore = ref.watch(canLoadMoreBusinessesProvider);
    final isLoadingMore = ref.watch(isLoadingMoreBusinessesProvider);
    final activityState = ref.watch(userActivityProvider);
    final textTheme = Theme.of(context).textTheme;
    String langCode;
    try {
      langCode = context.locale.languageCode;
    } catch (_) {
      langCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }
    final currencyMode = ref.watch(effectiveCurrencyModeProvider(langCode));
    final copPerUsd = ref.watch(activeCopPerUsdRateProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // Cabecera limpia con acción directa de registro adaptable a 360dp @ 2.0x
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Text(
                            'businesses.title'.tr(),
                            style: textTheme.headlineMedium?.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.businessRegister),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text('businesses.register_action'.tr()),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Campo de búsqueda
                    VjSearchField(
                      hint: 'businesses.search_hint'.tr(),
                      onChanged: ref
                          .read(businessSearchQueryProvider.notifier)
                          .updateQuery,
                    ),

                    const SizedBox(height: AppSpacing.sm + 4),

                    // Filtro de categorías horizontal
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryChip(
                            label: 'businesses.category_all'.tr(),
                            selected: selectedCategory == null,
                            onTap: () => ref
                                .read(businessCategoryProvider.notifier)
                                .selectCategory(null),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CategoryChip(
                            label: 'businesses.category_food'.tr(),
                            selected:
                                selectedCategory == BusinessCategory.food,
                            icon: Icons.restaurant,
                            onTap: () => ref
                                .read(businessCategoryProvider.notifier)
                                .selectCategory(BusinessCategory.food),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CategoryChip(
                            label: 'businesses.category_transport'.tr(),
                            selected:
                                selectedCategory == BusinessCategory.transport,
                            icon: Icons.local_taxi,
                            onTap: () => ref
                                .read(businessCategoryProvider.notifier)
                                .selectCategory(BusinessCategory.transport),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CategoryChip(
                            label: 'businesses.category_lodging'.tr(),
                            selected:
                                selectedCategory == BusinessCategory.lodging,
                            icon: Icons.hotel,
                            onTap: () => ref
                                .read(businessCategoryProvider.notifier)
                                .selectCategory(BusinessCategory.lodging),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CategoryChip(
                            label: 'businesses.category_services'.tr(),
                            selected:
                                selectedCategory == BusinessCategory.services,
                            icon: Icons.business_center,
                            onTap: () => ref
                                .read(businessCategoryProvider.notifier)
                                .selectCategory(BusinessCategory.services),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            // Lista compacta de resultados separando "Tus negocios" arriba del resto
            ...partitionedAsync.when(
              loading: () => const <Widget>[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        VjSkeletonBox(height: 82, borderRadius: AppRadius.xl),
                        SizedBox(height: AppSpacing.sm),
                        VjSkeletonBox(height: 82, borderRadius: AppRadius.xl),
                        SizedBox(height: AppSpacing.sm),
                        VjSkeletonBox(height: 82, borderRadius: AppRadius.xl),
                        SizedBox(height: AppSpacing.sm),
                        VjSkeletonBox(height: 82, borderRadius: AppRadius.xl),
                      ],
                    ),
                  ),
                ),
              ],
              error: (err, stack) => <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        Text(
                          'municipality.load_error'.tr(),
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        VjButton(
                          label: 'common.retry'.tr(),
                          onPressed: () {
                            ref.invalidate(businessCatalogProvider);
                            ref.invalidate(myBusinessesProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              data: (partitioned) {
                if (partitioned.isEmpty) {
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Center(
                          child: Text(
                            'businesses.no_results'.tr(),
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ];
                }

                return <Widget>[
                  if (partitioned.hasOwned) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg + AppSpacing.xs,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xs + 2,
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.xs + 2,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Text(
                              'businesses.your_businesses_section'
                                  .tr()
                                  .toUpperCase(),
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            VjBadge(
                              label: '${partitioned.owned.length}',
                              variant: VjBadgeVariant.tonal,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final business = partitioned.owned[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _BusinessCard(
                                business: business,
                                isOwner: true,
                                ownerBusy: ownerBusy,
                                isFavorite: activityState.isFavorite(
                                  business.id,
                                ),
                                currencyMode: currencyMode,
                                copPerUsd: copPerUsd,
                                onToggleFavorite: () => ref
                                    .read(userActivityProvider.notifier)
                                    .toggleFavoriteBusiness(business.id),
                                onTap: () =>
                                    _openBusinessDetail(context, business.id),
                                onEditTap: () => context.push(
                                  AppRoutes.businessEditPath(business.id),
                                ),
                                onWithdrawTap: () =>
                                    _confirmWithdraw(context, ref, business),
                              ),
                            );
                          },
                          childCount: partitioned.owned.length,
                        ),
                      ),
                    ),
                    if (partitioned.hasOthers)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.xs,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: AppSpacing.md),
                              const SizedBox(height: AppSpacing.xs),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.xs,
                                ),
                                child: Text(
                                  'businesses.other_businesses_section'
                                      .tr()
                                      .toUpperCase(),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (partitioned.hasOthers)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final business = partitioned.others[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _BusinessCard(
                                business: business,
                                isOwner: false,
                                ownerBusy: ownerBusy,
                                isFavorite: activityState.isFavorite(
                                  business.id,
                                ),
                                currencyMode: currencyMode,
                                copPerUsd: copPerUsd,
                                onToggleFavorite: () => ref
                                    .read(userActivityProvider.notifier)
                                    .toggleFavoriteBusiness(business.id),
                                onTap: () =>
                                    _openBusinessDetail(context, business.id),
                              ),
                            );
                          },
                          childCount: partitioned.others.length,
                        ),
                      ),
                    ),
                ];
              },
            ),

            // Botón de paginación ("Cargar más negocios")
            if (canLoadMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: VjButton(
                    label: 'businesses.load_more'.tr(),
                    variant: VjButtonVariant.outlined,
                    onPressed: isLoadingMore
                        ? null
                        : () => ref
                              .read(businessCatalogProvider.notifier)
                              .loadMore(),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

/// Chip de categoría interactivo en estilo píldora.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ActionChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.primary,
            )
          : null,
      label: Text(label),
      labelStyle: textTheme.labelMedium?.copyWith(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: selected ? AppColors.brandNavy : AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.brandNavy : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      onPressed: onTap,
    );
  }
}

/// Tarjeta compacta de directorio (la descripción detallada vive en BusinessDetailPage).
class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.onTap,
    this.isOwner = false,
    this.ownerBusy = false,
    this.isFavorite = false,
    this.currencyMode = CurrencyDisplayMode.copOnly,
    this.copPerUsd = kDefaultCopPerUsd,
    this.onToggleFavorite,
    this.onEditTap,
    this.onWithdrawTap,
  });

  final Business business;
  final VoidCallback onTap;
  final bool isOwner;
  final bool ownerBusy;
  final bool isFavorite;
  final CurrencyDisplayMode currencyMode;
  final int copPerUsd;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onEditTap;
  final VoidCallback? onWithdrawTap;

  IconData _iconForCategory(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.food:
        return Icons.restaurant_rounded;
      case BusinessCategory.transport:
        return Icons.local_taxi_rounded;
      case BusinessCategory.lodging:
        return Icons.hotel_rounded;
      case BusinessCategory.services:
        return Icons.storefront_rounded;
    }
  }

  List<Color> _gradientForCategory(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.food:
        return const [AppColors.brandNavy, AppColors.primary];
      case BusinessCategory.transport:
        return const [AppColors.brandNavy, AppColors.brandNavySurface];
      case BusinessCategory.lodging:
        return const [AppColors.primary, AppColors.brandNavy];
      case BusinessCategory.services:
        return const [AppColors.brandNavySurface, AppColors.brandNavyMuted];
    }
  }

  String _categoryLabel(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.food:
        return 'businesses.category_food'.tr();
      case BusinessCategory.transport:
        return 'businesses.category_transport'.tr();
      case BusinessCategory.lodging:
        return 'businesses.category_lodging'.tr();
      case BusinessCategory.services:
        return 'businesses.category_services'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;
    final categoryLabel = _categoryLabel(business.category);
    final priceLabel = business.minDishPriceCop == null
        ? null
        : (currencyMode == CurrencyDisplayMode.copOnly
              ? formatCop(business.minDishPriceCop!)
              : formatMoney(
                  amountCop: business.minDishPriceCop!,
                  mode: currencyMode,
                  copPerUsd: copPerUsd,
                ).inline);
    final metaLine = priceLabel != null
        ? '$categoryLabel · $priceLabel'
        : categoryLabel;

    return VjCard(
      borderRadius: AppRadius.xl,
      elevated: true,
      backgroundColor: isOwner
          ? AppColors.primarySoft.withValues(alpha: 0.22)
          : AppColors.surface,
      borderColor: isOwner ? AppColors.primaryBorder : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradientForCategory(business.category),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  _iconForCategory(business.category),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: textTheme.titleSmall?.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: AppSpacing.xs + 2,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isOwner)
                          VjBadge(
                            label: 'businesses.owner_badge'.tr(),
                            variant: VjBadgeVariant.navy,
                          ),
                        Text(
                          metaLine,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            business.address,
                            style: textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (onToggleFavorite != null)
                IconButton(
                  tooltip: isFavorite
                      ? 'activity.favorite_remove_tooltip'.tr()
                      : 'activity.favorite_add_tooltip'.tr(),
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? errorColor : AppColors.textMuted,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
            ],
          ),
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: ownerBusy ? null : onEditTap,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('businesses.action_edit'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                TextButton.icon(
                  onPressed: ownerBusy ? null : onWithdrawTap,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text('businesses.action_withdraw'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
