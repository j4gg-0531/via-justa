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
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/businesses/presentation/widgets/business_withdraw_dialog.dart';

/// Abre la hoja modal compacta "Mis negocios" desde Perfil para gestionar los comercios del dueño.
Future<void> showMyBusinessesSheet(BuildContext context) {
  return showVjModalSheet<void>(
    context: context,
    builder: (sheetContext) => const _MyBusinessesSheetBody(),
  );
}

class _MyBusinessesSheetBody extends ConsumerWidget {
  const _MyBusinessesSheetBody();

  void _openDetail(BuildContext context, String businessId) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    if (router != null) {
      router.push(AppRoutes.businessDetailPath(businessId));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BusinessDetailPage(businessId: businessId),
        ),
      );
    }
  }

  void _openEdit(BuildContext context, String businessId) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    router?.push(AppRoutes.businessEditPath(businessId));
  }

  void _openRegister(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    router?.push(AppRoutes.businessRegister);
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
    final myBusinessesAsync = ref.watch(myBusinessesProvider);
    final ownerBusy = ref.watch(businessOwnerActionProvider);
    final textTheme = Theme.of(context).textTheme;

    return VjModalSheet(
      icon: Icons.storefront_rounded,
      tone: VjModalTone.neutral,
      title: 'businesses.my_businesses_sheet_title'.tr(),
      scrollable: false,
      maxHeightFactor: 0.78,
      footer: VjButton(
        label: (myBusinessesAsync.asData?.value.isNotEmpty ?? false)
            ? 'businesses.my_businesses_add_another'.tr()
            : 'businesses.register_action'.tr(),
        leadingIcon: Icons.add_rounded,
        onPressed: () => _openRegister(context),
      ),
      child: myBusinessesAsync.when(
        loading: () => const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VjSkeletonBox(height: 84, borderRadius: AppRadius.xl),
            SizedBox(height: AppSpacing.sm),
            VjSkeletonBox(height: 84, borderRadius: AppRadius.xl),
          ],
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'municipality.load_error'.tr(),
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              VjButton(
                label: 'common.retry'.tr(),
                onPressed: () => ref.invalidate(myBusinessesProvider),
              ),
            ],
          ),
        ),
        data: (businesses) {
          if (businesses.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'businesses.my_businesses_empty'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            itemCount: businesses.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final business = businesses[index];
              return _MyBusinessSheetCard(
                business: business,
                ownerBusy: ownerBusy,
                onViewTap: business.isApproved
                    ? () => _openDetail(context, business.id)
                    : null,
                onEditTap: () => _openEdit(context, business.id),
                onWithdrawTap: () => _confirmWithdraw(context, ref, business),
              );
            },
          );
        },
      ),
    );
  }
}

class _MyBusinessSheetCard extends StatelessWidget {
  const _MyBusinessSheetCard({
    required this.business,
    required this.ownerBusy,
    required this.onViewTap,
    required this.onEditTap,
    required this.onWithdrawTap,
  });

  final Business business;
  final bool ownerBusy;
  final VoidCallback? onViewTap;
  final VoidCallback onEditTap;
  final VoidCallback onWithdrawTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      backgroundColor: AppColors.surfaceSubtle,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onViewTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
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
                    const SizedBox(height: 2),
                    Text(
                      business.address,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (business.isPending || business.isRejected) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            VjBadge(
              label: business.isPending
                  ? 'businesses.status_pending'.tr()
                  : 'businesses.status_rejected'.tr(),
              variant: business.isPending
                  ? VjBadgeVariant.tonal
                  : VjBadgeVariant.outline,
            ),
            if (business.isRejected &&
                (business.rejectionReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                business.rejectionReason!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (onViewTap != null)
                TextButton.icon(
                  onPressed: onViewTap,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text('businesses.action_view'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandNavy,
                    minimumSize: const Size(48, 48),
                  ),
                ),
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
      ),
    );
  }
}
