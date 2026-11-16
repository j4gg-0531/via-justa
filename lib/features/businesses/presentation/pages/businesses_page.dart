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
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

/// Pantalla 21 (M21) · Directorio de comercios publicados en Valledupar con buscador y categorías.
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

  Future<void> _contactBusiness(
    BuildContext context,
    WidgetRef ref,
    Business business,
    String localeCode,
  ) async {
    final ok = await ref
        .read(businessExternalActionProvider.notifier)
        .openCardContact(business, localeCode: localeCode);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('business_detail.action_launch_error'.tr())),
      );
    }
  }

  Future<void> _confirmWithdraw(
    BuildContext context,
    WidgetRef ref,
    Business business,
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
        .withdraw(business.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('businesses.withdraw_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(filteredBusinessesProvider);
    final selectedCategory = ref.watch(businessCategoryProvider);
    final currentOwnerId = ref.watch(currentBusinessOwnerIdProvider);
    final ownerBusy = ref.watch(businessOwnerActionProvider);
    final canLoadMore = ref.watch(canLoadMoreBusinessesProvider);
    final isLoadingMore = ref.watch(isLoadingMoreBusinessesProvider);
    final textTheme = Theme.of(context).textTheme;
    final localeCode =
        EasyLocalization.of(context)?.locale.languageCode ?? 'es';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // Título y descripción
                    Text(
                      'businesses.title'.tr(),
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'businesses.subtitle'.tr(),
                      style: textTheme.bodyMedium,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Campo de búsqueda
                    VjSearchField(
                      hint: 'businesses.search_hint'.tr(),
                      onChanged: ref
                          .read(businessSearchQueryProvider.notifier)
                          .updateQuery,
                    ),

                    const SizedBox(height: AppSpacing.md),

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

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            // Lista de resultados
            businessesAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverToBoxAdapter(
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
                        onPressed: () =>
                            ref.invalidate(businessCatalogProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (businesses) {
                if (businesses.isEmpty) {
                  return SliverToBoxAdapter(
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
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final business = businesses[index];
                        final isOwner =
                            currentOwnerId != null &&
                            business.ownerId == currentOwnerId;
                        final description = business.localizedDescription(
                          localeCode,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _BusinessCard(
                            business: business,
                            description: description,
                            isOwner: isOwner,
                            ownerBusy: ownerBusy,
                            onTap: () =>
                                _openBusinessDetail(context, business.id),
                            onContactTap: () => _contactBusiness(
                              context,
                              ref,
                              business,
                              localeCode,
                            ),
                            onEditTap: isOwner
                                ? () => context.push(
                                    AppRoutes.businessEditPath(business.id),
                                  )
                                : null,
                            onWithdrawTap: isOwner
                                ? () => _confirmWithdraw(context, ref, business)
                                : null,
                          ),
                        );
                      },
                      childCount: businesses.length,
                    ),
                  ),
                );
              },
            ),

            // Botón de paginación ("Cargar más negocios")
            if (canLoadMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
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

            // Registro de negocio (para dueños locales)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: VjCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'businesses.register_title'.tr(),
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'businesses.register_subtitle'.tr(),
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      VjButton(
                        label: 'businesses.register_action'.tr(),
                        onPressed: () =>
                            context.push(AppRoutes.businessRegister),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de categoría interactivo
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
    return ActionChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.primary,
            )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: selected ? AppColors.primary : AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      onPressed: onTap,
    );
  }
}

/// Tarjeta de negocio individual
class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.description,
    required this.onTap,
    required this.onContactTap,
    this.isOwner = false,
    this.ownerBusy = false,
    this.onEditTap,
    this.onWithdrawTap,
  });

  final Business business;
  final String description;
  final VoidCallback onTap;
  final VoidCallback onContactTap;
  final bool isOwner;
  final bool ownerBusy;
  final VoidCallback? onEditTap;
  final VoidCallback? onWithdrawTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  business.name,
                  style: textTheme.titleMedium,
                ),
              ),
              VjBadge(
                label: 'businesses.published_badge'.tr(),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  business.address,
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (isOwner) ...[
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
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: onContactTap,
                icon: const Icon(Icons.phone, size: 16),
                label: Text('businesses.action_call'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
