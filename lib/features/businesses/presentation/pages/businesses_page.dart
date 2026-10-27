import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

/// Pantalla 21 (M21) · Directorio de comercios de muestra en Valledupar con buscador y categorías.
class BusinessesPage extends ConsumerWidget {
  const BusinessesPage({super.key});

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(filteredBusinessesProvider);
    final selectedCategory = ref.watch(businessCategoryProvider);
    final textTheme = Theme.of(context).textTheme;

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

                    const SizedBox(height: AppSpacing.md),

                    // Banner de muestra local
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'businesses.demo_banner'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                            selected: selectedCategory == BusinessCategory.food,
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
                  child: Center(
                    child: Text(
                      'municipality.load_error'.tr(),
                      style: textTheme.bodyLarge,
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final business = businesses[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _BusinessCard(
                            business: business,
                            onTap: () => _showInfoDialog(
                              context,
                              title: business.name,
                              body:
                                  '${business.description}\n\n${business.address}\nTel: ${business.phone}',
                            ),
                            onContactTap: () => _showInfoDialog(
                              context,
                              title: 'businesses.contact_dialog_title'.tr(),
                              body: 'businesses.contact_dialog_body'.tr(),
                            ),
                          ),
                        );
                      },
                      childCount: businesses.length,
                    ),
                  ),
                );
              },
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
                          VjBadge(label: 'common.coming_soon'.tr()),
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
                        onPressed: () => _showInfoDialog(
                          context,
                          title: 'businesses.register_dialog_title'.tr(),
                          body: 'businesses.register_dialog_body'.tr(),
                        ),
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
    required this.onTap,
    required this.onContactTap,
  });

  final Business business;
  final VoidCallback onTap;
  final VoidCallback onContactTap;

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
                label: business.isVerified
                    ? 'businesses.verified_badge'.tr()
                    : 'businesses.demo_badge'.tr(),
              ),
            ],
          ),
          if (business.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              business.description,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
