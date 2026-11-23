import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/currency/currency_formatter.dart';
import 'package:via_justa/core/currency/currency_providers.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_page_header.dart';
import 'package:via_justa/features/activity/presentation/state/user_activity_providers.dart';
import 'package:via_justa/features/budget/domain/trip_budget.dart';
import 'package:via_justa/features/budget/presentation/state/trip_budget_providers.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

/// Colores de gráfico no-semáforo para el desglose proporcional por rubro.
const Color _kChartLodging = AppColors.brandNavy;
const Color _kChartFood = AppColors.primary;
const Color _kChartTransport = Color(0xFF6366F1);
const Color _kChartBuffer = Color(0xFF94A3B8);

/// Pantalla de Plan de Presupuesto de Viaje (`/budget`), 100% determinística sobre medianas reales.
class TripBudgetPage extends ConsumerStatefulWidget {
  const TripBudgetPage({super.key});

  @override
  ConsumerState<TripBudgetPage> createState() => _TripBudgetPageState();
}

class _TripBudgetPageState extends ConsumerState<TripBudgetPage> {
  final TextEditingController _budgetController = TextEditingController();

  @override
  void dispose() {
    _budgetController.dispose();
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

  void _applyPresetBudget(int? amountCop) {
    ref.read(tripBudgetInputProvider.notifier).setAvailableBudget(amountCop);
    _budgetController.text = amountCop == null ? '' : '$amountCop';
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(tripBudgetInputProvider);
    final notifier = ref.read(tripBudgetInputProvider.notifier);
    final breakdown = ref.watch(tripBudgetBreakdownProvider);
    final suggestedBusinesses = ref.watch(tripBudgetBusinessesProvider);
    final activityState = ref.watch(userActivityProvider);
    final locationLabel = ref.watch(selectedLocationLabelProvider);
    final cityName = locationLabel ?? 'home.default_city'.tr();
    final textTheme = Theme.of(context).textTheme;

    String langCode;
    try {
      langCode = context.locale.languageCode;
    } catch (_) {
      langCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }
    final currencyMode = ref.watch(effectiveCurrencyModeProvider(langCode));
    final copPerUsd = ref.watch(activeCopPerUsdRateProvider);

    final totalMoney = formatMoney(
      amountCop: breakdown.totalCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    );
    final perDayMoney = formatMoney(
      amountCop: breakdown.perDayCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    );
    final minMoney = formatMoney(
      amountCop: breakdown.minRangeCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    );
    final maxMoney = formatMoney(
      amountCop: breakdown.maxRangeCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    );

    final daysLabel = input.days == 1
        ? 'budget.days_one'.tr()
        : 'budget.days_many'.tr(namedArgs: {'count': '${input.days}'});
    final travelersLabel = input.travelers == 1
        ? 'budget.travelers_one'.tr()
        : 'budget.travelers_many'.tr(
            namedArgs: {'count': '${input.travelers}'},
          );
    final nightsLabel = breakdown.nights == 1
        ? 'budget.nights_one'.tr()
        : 'budget.nights_many'.tr(namedArgs: {'count': '${breakdown.nights}'});
    final roomsLabel = breakdown.rooms == 1
        ? 'budget.rooms_one'.tr()
        : 'budget.rooms_many'.tr(namedArgs: {'count': '${breakdown.rooms}'});

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            VjPageHeader(
              title: 'budget.page_title'.tr(),
              subtitle: 'budget.page_subtitle'.tr(),
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Tarjeta resumen principal en Brand Navy
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg + 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandNavy, AppColors.brandNavySurface],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'budget.summary_tag'.tr(
                            namedArgs: {
                              'days': daysLabel,
                              'travelers': travelersLabel,
                            },
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (currencyMode != CurrencyDisplayMode.copOnly)
                        Text(
                          'currency.rate_hint'.tr(
                            namedArgs: {
                              'rate': formatCopCurrency(copPerUsd),
                            },
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    totalMoney.primary,
                    style: textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalMoney.secondary != null
                        ? 'budget.orientative_usd_note'.tr(
                            namedArgs: {
                              'usd': formatUsdApprox(
                                breakdown.totalCop,
                                copPerUsd: copPerUsd,
                              ),
                            },
                          )
                        : 'budget.based_on_medians_note'.tr(
                            namedArgs: {'city': cityName},
                          ),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryBorder,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _NavyMetaChip(
                        label: 'budget.per_day'.tr(
                          namedArgs: {'amount': perDayMoney.primary},
                        ),
                      ),
                      _NavyMetaChip(
                        label: 'budget.range_label'.tr(
                          namedArgs: {
                            'min': minMoney.primary,
                            'max': maxMoney.primary,
                          },
                        ),
                      ),
                    ],
                  ),
                  if (breakdown.feasibility != null &&
                      input.availableBudgetCop != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _FeasibilityBanner(
                      feasibility: breakdown.feasibility!,
                      availableBudgetCop: input.availableBudgetCop!,
                      differenceCop: breakdown.differenceCop ?? 0,
                      currencyMode: currencyMode,
                      copPerUsd: copPerUsd,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Controles interactivos de viaje
            VjCard(
              borderRadius: AppRadius.xl,
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.25) ...[
                    _CompactStepper(
                      label: 'budget.duration_label'.tr(),
                      valueText: daysLabel,
                      onDecrement: input.days > 1
                          ? () => notifier.changeDays(-1)
                          : null,
                      onIncrement: input.days < 15
                          ? () => notifier.changeDays(1)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CompactStepper(
                      label: 'budget.travelers_label'.tr(),
                      valueText: 'budget.travelers_short'.tr(
                        namedArgs: {'count': '${input.travelers}'},
                      ),
                      onDecrement: input.travelers > 1
                          ? () => notifier.changeTravelers(-1)
                          : null,
                      onIncrement: input.travelers < 6
                          ? () => notifier.changeTravelers(1)
                          : null,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _CompactStepper(
                            label: 'budget.duration_label'.tr(),
                            valueText: daysLabel,
                            onDecrement: input.days > 1
                                ? () => notifier.changeDays(-1)
                                : null,
                            onIncrement: input.days < 15
                                ? () => notifier.changeDays(1)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm + 2),
                        Expanded(
                          child: _CompactStepper(
                            label: 'budget.travelers_label'.tr(),
                            valueText: 'budget.travelers_short'.tr(
                              namedArgs: {'count': '${input.travelers}'},
                            ),
                            onDecrement: input.travelers > 1
                                ? () => notifier.changeTravelers(-1)
                                : null,
                            onIncrement: input.travelers < 6
                                ? () => notifier.changeTravelers(1)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'budget.style_label'.tr(),
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
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
                          child: _StyleSegment(
                            label: 'budget.style_economy'.tr(),
                            selected: input.style == TripStyle.economy,
                            onTap: () => notifier.selectStyle(TripStyle.economy),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _StyleSegment(
                            label: 'budget.style_standard'.tr(),
                            selected: input.style == TripStyle.standard,
                            onTap: () =>
                                notifier.selectStyle(TripStyle.standard),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _StyleSegment(
                            label: 'budget.style_comfort'.tr(),
                            selected: input.style == TripStyle.comfort,
                            onTap: () => notifier.selectStyle(TripStyle.comfort),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'budget.available_budget_label'.tr(),
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Wrap(
                    spacing: AppSpacing.xs + 2,
                    runSpacing: AppSpacing.xs + 2,
                    children: [
                      ChoiceChip(
                        label: Text('budget.no_cap_chip'.tr()),
                        selected: input.availableBudgetCop == null,
                        onSelected: (_) => _applyPresetBudget(null),
                      ),
                      for (final preset in const <int>[
                        350000,
                        550000,
                        800000,
                        1400000,
                      ])
                        ChoiceChip(
                          label: Text(formatCopCurrency(preset)),
                          selected: input.availableBudgetCop == preset,
                          onSelected: (_) => _applyPresetBudget(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (raw) {
                      final parsed = int.tryParse(raw.trim());
                      notifier.setAvailableBudget(parsed);
                    },
                    decoration: InputDecoration(
                      hintText: 'budget.custom_budget_hint'.tr(),
                      prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                      filled: true,
                      fillColor: AppColors.surfaceSubtle,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      value: input.includeLodging,
                      onChanged: notifier.setIncludeLodging,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'budget.include_lodging_title'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'budget.include_lodging_desc'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      value: input.isEventSeason,
                      onChanged: notifier.setEventSeason,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'budget.event_season_title'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'budget.event_season_desc'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Desglose determinístico con barra apilada 100% (tonos no-semáforo)
            VjCard(
              borderRadius: AppRadius.xl,
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'budget.breakdown_title'.tr(),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'budget.breakdown_verified'.tr(),
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (breakdown.lodgingPct > 0)
                            Expanded(
                              flex: breakdown.lodgingPct,
                              child: const ColoredBox(color: _kChartLodging),
                            ),
                          if (breakdown.foodPct > 0)
                            Expanded(
                              flex: breakdown.foodPct,
                              child: const ColoredBox(color: _kChartFood),
                            ),
                          if (breakdown.transportPct > 0)
                            Expanded(
                              flex: breakdown.transportPct,
                              child: const ColoredBox(color: _kChartTransport),
                            ),
                          if (breakdown.bufferPct > 0)
                            Expanded(
                              flex: breakdown.bufferPct,
                              child: const ColoredBox(color: _kChartBuffer),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (input.includeLodging) ...[
                    _BreakdownLine(
                      dotColor: _kChartLodging,
                      title: 'budget.item_lodging'.tr(),
                      pct: breakdown.lodgingPct,
                      subtitle: '$nightsLabel · $roomsLabel',
                      money: formatMoney(
                        amountCop: breakdown.lodgingCop,
                        mode: currencyMode,
                        copPerUsd: copPerUsd,
                      ),
                    ),
                    const Divider(height: AppSpacing.md),
                  ],
                  _BreakdownLine(
                    dotColor: _kChartFood,
                    title: 'budget.item_food'.tr(),
                    pct: breakdown.foodPct,
                    subtitle: '$daysLabel · $travelersLabel',
                    money: formatMoney(
                      amountCop: breakdown.foodCop,
                      mode: currencyMode,
                      copPerUsd: copPerUsd,
                    ),
                  ),
                  const Divider(height: AppSpacing.md),
                  _BreakdownLine(
                    dotColor: _kChartTransport,
                    title: 'budget.item_transport'.tr(),
                    pct: breakdown.transportPct,
                    subtitle: 'budget.item_transport_sub'.tr(),
                    money: formatMoney(
                      amountCop: breakdown.transportCop,
                      mode: currencyMode,
                      copPerUsd: copPerUsd,
                    ),
                  ),
                  const Divider(height: AppSpacing.md),
                  _BreakdownLine(
                    dotColor: _kChartBuffer,
                    title: 'budget.item_buffer'.tr(),
                    pct: breakdown.bufferPct,
                    subtitle: 'budget.item_buffer_sub'.tr(),
                    money: formatMoney(
                      amountCop: breakdown.bufferCop,
                      mode: currencyMode,
                      copPerUsd: copPerUsd,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Comercios reales del directorio relevantes para el viaje
            VjCard(
              borderRadius: AppRadius.xl,
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'budget.matches_title'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'budget.matches_subtitle'.tr(
                      namedArgs: {'city': cityName},
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (suggestedBusinesses.isEmpty)
                    Text(
                      'budget.matches_empty'.tr(),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    for (var i = 0; i < suggestedBusinesses.length; i++) ...[
                      _BudgetBusinessTile(
                        business: suggestedBusinesses[i],
                        isFavorite: activityState.isFavorite(
                          suggestedBusinesses[i].id,
                        ),
                        onTap: () => _openBusinessDetail(
                          context,
                          suggestedBusinesses[i].id,
                        ),
                        onToggleFavorite: () => ref
                            .read(userActivityProvider.notifier)
                            .toggleFavoriteBusiness(suggestedBusinesses[i].id),
                      ),
                      if (i < suggestedBusinesses.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Consejos determinísticos según el resultado
            VjCard(
              borderRadius: AppRadius.xl,
              backgroundColor: AppColors.surfaceSubtle,
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        'budget.advice_title'.tr(),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final advice in breakdown.adviceKeys) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _adviceText(advice),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'budget.disclaimer'.tr(),
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _adviceText(TripBudgetAdviceKey key) {
    return switch (key) {
      TripBudgetAdviceKey.shortBudget => 'budget.advice_short_budget'.tr(),
      TripBudgetAdviceKey.eventSeason => 'budget.advice_event_season'.tr(),
      TripBudgetAdviceKey.centralLodging => 'budget.advice_central_lodging'.tr(),
      TripBudgetAdviceKey.verifyPrices => 'budget.advice_verify_prices'.tr(),
    };
  }
}

class _NavyMetaChip extends StatelessWidget {
  const _NavyMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeasibilityBanner extends StatelessWidget {
  const _FeasibilityBanner({
    required this.feasibility,
    required this.availableBudgetCop,
    required this.differenceCop,
    required this.currencyMode,
    required this.copPerUsd,
  });

  final BudgetFeasibility feasibility;
  final int availableBudgetCop;
  final int differenceCop;
  final CurrencyDisplayMode currencyMode;
  final int copPerUsd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final budgetText = formatMoney(
      amountCop: availableBudgetCop,
      mode: currencyMode,
      copPerUsd: copPerUsd,
    ).inline;
    final diffText = formatMoney(
      amountCop: differenceCop.abs(),
      mode: currencyMode,
      copPerUsd: copPerUsd,
    ).inline;

    final (bg, fg, icon, message) = switch (feasibility) {
      BudgetFeasibility.comfortable => (
        AppColors.semaphoreGreenSoft,
        AppColors.semaphoreGreen,
        Icons.check_circle_outline_rounded,
        'budget.feasibility_comfortable'.tr(
          namedArgs: {'budget': budgetText, 'diff': diffText},
        ),
      ),
      BudgetFeasibility.tight => (
        AppColors.semaphoreAmberSoft,
        AppColors.semaphoreAmber,
        Icons.info_outline_rounded,
        differenceCop >= 0
            ? 'budget.feasibility_tight_surplus'.tr(
                namedArgs: {'diff': diffText},
              )
            : 'budget.feasibility_tight_deficit'.tr(
                namedArgs: {'diff': diffText},
              ),
      ),
      BudgetFeasibility.short => (
        AppColors.semaphoreRedSoft,
        AppColors.semaphoreRed,
        Icons.warning_amber_rounded,
        'budget.feasibility_short'.tr(namedArgs: {'diff': diffText}),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStepper extends StatelessWidget {
  const _CompactStepper({
    required this.label,
    required this.valueText,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String valueText;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_rounded, size: 18),
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              Expanded(
                child: Text(
                  valueText,
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandNavy,
                  ),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_rounded, size: 18),
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleSegment extends StatelessWidget {
  const _StyleSegment({
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                label,
                maxLines: 1,
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

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({
    required this.dotColor,
    required this.title,
    required this.pct,
    required this.subtitle,
    required this.money,
  });

  final Color dotColor;
  final String title;
  final int pct;
  final String subtitle;
  final FormattedMoney money;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title · $pct%',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money.primary,
              style: textTheme.bodyMedium?.copyWith(
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
        ),
      ],
    );
  }
}

class _BudgetBusinessTile extends StatelessWidget {
  const _BudgetBusinessTile({
    required this.business,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Business business;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;

    return Material(
      color: AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  business.category == BusinessCategory.lodging
                      ? Icons.hotel_outlined
                      : Icons.restaurant_outlined,
                  size: 20,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
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
                ),
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
