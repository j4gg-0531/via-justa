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
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/core/widgets/vj_page_header.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/activity/domain/user_activity.dart';
import 'package:via_justa/features/activity/presentation/state/user_activity_providers.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

enum _ActivityTab { checks, favorites, contributions }

/// Pantalla "Mi actividad" (accesible desde Perfil): Consultas recientes, Favoritos y Mis aportes.
class UserActivityPage extends ConsumerStatefulWidget {
  const UserActivityPage({super.key});

  @override
  ConsumerState<UserActivityPage> createState() => _UserActivityPageState();
}

class _UserActivityPageState extends ConsumerState<UserActivityPage> {
  final ValueNotifier<_ActivityTab> _selectedTab = ValueNotifier<_ActivityTab>(
    _ActivityTab.checks,
  );

  @override
  void dispose() {
    _selectedTab.dispose();
    super.dispose();
  }

  void _openBusinessDetail(BuildContext context, String businessId) {
    final router = GoRouter.maybeOf(context);
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

  Future<void> _confirmClearChecks() async {
    final confirmed = await showVjConfirmDialog(
      context: context,
      icon: Icons.delete_sweep_outlined,
      tone: VjModalTone.destructive,
      title: 'activity.clear_history_title'.tr(),
      body: 'activity.clear_history_body'.tr(),
      cancelLabel: 'common.close'.tr(),
      confirmLabel: 'activity.clear_history_confirm'.tr(),
    );
    if (confirmed == true) {
      await ref.read(userActivityProvider.notifier).clearRecentChecks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(userActivityProvider);
    final favorites = ref.watch(favoriteBusinessesProvider);
    final contributionsAsync = ref.watch(myPriceContributionsProvider);
    final contributionsCount = contributionsAsync.asData?.value.length ?? 0;

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
        child: ValueListenableBuilder<_ActivityTab>(
          valueListenable: _selectedTab,
          builder: (context, activeTab, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                VjPageHeader(
                  title: 'activity.page_title'.tr(),
                  subtitle: 'activity.page_subtitle'.tr(),
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.profile);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Selector segmentado de 3 vistas
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActivitySegmentButton(
                          label: 'activity.tab_checks'.tr(
                            namedArgs: {
                              'count': '${activity.recentChecks.length}',
                            },
                          ),
                          selected: activeTab == _ActivityTab.checks,
                          onTap: () => _selectedTab.value = _ActivityTab.checks,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ActivitySegmentButton(
                          label: 'activity.tab_favorites'.tr(
                            namedArgs: {'count': '${favorites.length}'},
                          ),
                          selected: activeTab == _ActivityTab.favorites,
                          onTap: () =>
                              _selectedTab.value = _ActivityTab.favorites,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ActivitySegmentButton(
                          label: 'activity.tab_contributions'.tr(
                            namedArgs: {'count': '$contributionsCount'},
                          ),
                          selected: activeTab == _ActivityTab.contributions,
                          onTap: () =>
                              _selectedTab.value = _ActivityTab.contributions,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (activeTab == _ActivityTab.checks)
                  _ChecksTabContent(
                    checks: activity.recentChecks,
                    languageCode: langCode,
                    currencyMode: currencyMode,
                    copPerUsd: copPerUsd,
                    onClearTap: _confirmClearChecks,
                  )
                else if (activeTab == _ActivityTab.favorites)
                  _FavoritesTabContent(
                    favorites: favorites,
                    onOpenDetail: (id) => _openBusinessDetail(context, id),
                    onRemoveFavorite: (id) => ref
                        .read(userActivityProvider.notifier)
                        .toggleFavoriteBusiness(id),
                  )
                else
                  _ContributionsTabContent(
                    contributionsAsync: contributionsAsync,
                    languageCode: langCode,
                    currencyMode: currencyMode,
                    copPerUsd: copPerUsd,
                    onRetry: () => ref.invalidate(myPriceContributionsProvider),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivitySegmentButton extends StatelessWidget {
  const _ActivitySegmentButton({
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

    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs + 2,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: selected
                      ? AppColors.brandNavy
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecksTabContent extends StatelessWidget {
  const _ChecksTabContent({
    required this.checks,
    required this.languageCode,
    required this.currencyMode,
    required this.copPerUsd,
    required this.onClearTap,
  });

  final List<RecentPriceCheck> checks;
  final String languageCode;
  final CurrencyDisplayMode currencyMode;
  final int copPerUsd;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (checks.isEmpty) {
      return _ActivityEmptyCard(
        icon: Icons.history_rounded,
        title: 'activity.empty_checks_title'.tr(),
        body: 'activity.empty_checks_body'.tr(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < checks.length; i++) ...[
          _RecentCheckCard(
            check: checks[i],
            languageCode: languageCode,
            currencyMode: currencyMode,
            copPerUsd: copPerUsd,
          ),
          if (i < checks.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        VjButton(
          label: 'activity.clear_history_cta'.tr(),
          variant: VjButtonVariant.outlined,
          leadingIcon: Icons.delete_sweep_outlined,
          onPressed: onClearTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'currency.disclaimer'.tr(),
          style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RecentCheckCard extends StatelessWidget {
  const _RecentCheckCard({
    required this.check,
    required this.languageCode,
    required this.currencyMode,
    required this.copPerUsd,
  });

  final RecentPriceCheck check;
  final String languageCode;
  final CurrencyDisplayMode currencyMode;
  final int copPerUsd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final observed = formatMoney(
      amountCop: check.observedCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    );

    final (statusColor, statusBg, statusIcon, statusLabel) = switch (check.level) {
      PriceVerdictLevel.green => (
        AppColors.semaphoreGreen,
        AppColors.semaphoreGreenSoft,
        Icons.check_circle_outline_rounded,
        'activity.verdict_green'.tr(),
      ),
      PriceVerdictLevel.yellow => (
        AppColors.semaphoreAmber,
        AppColors.semaphoreAmberSoft,
        Icons.info_outline_rounded,
        'activity.verdict_yellow'.tr(),
      ),
      PriceVerdictLevel.red => (
        AppColors.semaphoreRed,
        AppColors.semaphoreRedSoft,
        Icons.warning_amber_rounded,
        'activity.verdict_red'.tr(),
      ),
      PriceVerdictLevel.insufficient => (
        AppColors.textSecondary,
        AppColors.surfaceSubtle,
        Icons.help_outline_rounded,
        'activity.verdict_insufficient'.tr(),
      ),
    };

    final referenceCop = check.medianCop;
    final dateText = DateFormat('d MMM · HH:mm').format(check.checkedAt.toLocal());
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          check.localizedCategoryName(languageCode),
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          check.zoneName,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (referenceCop != null) ...[
          const SizedBox(height: 2),
          Text(
            'activity.median_label'.tr(
              namedArgs: {
                'amount': formatMoney(
                  amountCop: referenceCop,
                  mode: currencyMode,
                  copPerUsd: copPerUsd,
                ).inline,
              },
            ),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );

    final priceColumn = Column(
      crossAxisAlignment: textScale >= 1.35
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          observed.primary,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.brandNavy,
          ),
        ),
        if (observed.secondary != null)
          Text(
            observed.secondary!,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        statusLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                dateText,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (textScale >= 1.35) ...[
            infoColumn,
            const SizedBox(height: AppSpacing.xs),
            priceColumn,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: infoColumn),
                const SizedBox(width: AppSpacing.sm),
                Flexible(fit: FlexFit.loose, child: priceColumn),
              ],
            ),
        ],
      ),
    );
  }
}

class _FavoritesTabContent extends StatelessWidget {
  const _FavoritesTabContent({
    required this.favorites,
    required this.onOpenDetail,
    required this.onRemoveFavorite,
  });

  final List<Business> favorites;
  final ValueChanged<String> onOpenDetail;
  final ValueChanged<String> onRemoveFavorite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;

    if (favorites.isEmpty) {
      return _ActivityEmptyCard(
        icon: Icons.favorite_border_rounded,
        title: 'activity.empty_favorites_title'.tr(),
        body: 'activity.empty_favorites_body'.tr(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < favorites.length; i++) ...[
          VjCard(
            borderRadius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.md),
            onTap: () => onOpenDetail(favorites[i].id),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorites[i].name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        favorites[i].address,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'activity.favorite_remove_tooltip'.tr(),
                  onPressed: () => onRemoveFavorite(favorites[i].id),
                  icon: Icon(Icons.favorite_rounded, color: errorColor),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ),
          if (i < favorites.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ContributionsTabContent extends StatelessWidget {
  const _ContributionsTabContent({
    required this.contributionsAsync,
    required this.languageCode,
    required this.currencyMode,
    required this.copPerUsd,
    required this.onRetry,
  });

  final AsyncValue<List<UserPriceContribution>> contributionsAsync;
  final String languageCode;
  final CurrencyDisplayMode currencyMode;
  final int copPerUsd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return contributionsAsync.when(
      loading: () => const Column(
        children: [
          VjSkeletonBox(height: 84, borderRadius: AppRadius.xl),
          SizedBox(height: AppSpacing.sm),
          VjSkeletonBox(height: 84, borderRadius: AppRadius.xl),
        ],
      ),
      error: (_, _) => VjCard(
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              'municipality.load_error'.tr(),
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            VjButton(label: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _ActivityEmptyCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'activity.empty_contributions_title'.tr(),
            body: 'activity.empty_contributions_body'.tr(),
          );
        }

        final impactTitle = items.length == 1
            ? 'activity.impact_title_one'.tr()
            : 'activity.impact_title_many'.tr(
                namedArgs: {'count': '${items.length}'},
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.brandNavy,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'activity.impact_tag'.tr(),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryBorder,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    impactTitle,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'activity.impact_body'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < items.length; i++) ...[
              _ContributionCard(
                item: items[i],
                languageCode: languageCode,
                currencyMode: currencyMode,
                copPerUsd: copPerUsd,
              ),
              if (i < items.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.item,
    required this.languageCode,
    required this.currencyMode,
    required this.copPerUsd,
  });

  final UserPriceContribution item;
  final String languageCode;
  final CurrencyDisplayMode currencyMode;
  final int copPerUsd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final money = formatMoney(
      amountCop: item.amountCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    );

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final moneyColumn = Column(
      crossAxisAlignment: textScale >= 1.35
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          money.primary,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.brandNavy,
          ),
        ),
        if (money.secondary != null)
          Text(
            money.secondary!,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.localizedCategoryName(languageCode),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              VjBadge(label: 'activity.status_published'.tr()),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (textScale >= 1.35) ...[
            Text(
              '${item.zoneName} · ${DateFormat('d MMM y').format(item.createdAt.toLocal())}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            moneyColumn,
          ] else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.zoneName} · ${DateFormat('d MMM y').format(item.createdAt.toLocal())}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(fit: FlexFit.loose, child: moneyColumn),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityEmptyCard extends StatelessWidget {
  const _ActivityEmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.brandNavy, size: 24),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
