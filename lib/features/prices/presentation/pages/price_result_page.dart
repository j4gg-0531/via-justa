import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/currency/currency_providers.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_page_header.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/price_verdict_card.dart';

/// Pantalla 11 (M07 y M20) · Resultado del análisis estadístico de precio con semáforo accesible.
class PriceResultPage extends ConsumerWidget {
  const PriceResultPage({super.key});

  void _openContributeFlow(BuildContext context) {
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.priceContribute);
      return;
    }
    showVjConfirmDialog(
      context: context,
      icon: Icons.info_outline_rounded,
      title: 'home.contribute_dialog_title'.tr(),
      body: 'home.contribute_dialog_body'.tr(),
      confirmLabel: 'common.close'.tr(),
    );
  }

  void _goBackToScan(BuildContext context, WidgetRef ref) {
    ref.read(priceScanProvider.notifier).clearVerdict();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.scan);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(priceScanProvider);
    final category = ref.watch(activeVerdictCategoryProvider);
    final zone = ref.watch(activeVerdictZoneProvider);
    final destinationZone = ref.watch(activeVerdictDestinationZoneProvider);
    final municipality = ref.watch(selectedMunicipalityProvider);
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(priceScanProvider.notifier);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              VjPageHeader(
                title: 'price_verdict.result_page_title'.tr(),
                onBack: () => _goBackToScan(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Estado del veredicto: cargando, error o tarjeta de resultado
              scanState.verdictAsync.when(
                loading: () => const Column(
                  children: [
                    VjSkeletonBox(height: 150, borderRadius: AppRadius.xl),
                    SizedBox(height: AppSpacing.md),
                    VjSkeletonBox(height: 110, borderRadius: AppRadius.xl),
                    SizedBox(height: AppSpacing.md),
                    VjSkeletonBox(height: 84, borderRadius: AppRadius.lg),
                  ],
                ),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'price_verdict.load_error'.tr(),
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      VjButton(
                        label: 'common.retry'.tr(),
                        onPressed: () => notifier.submitEvaluation(
                          municipalityCode: municipality?.code ?? '20001',
                        ),
                      ),
                    ],
                  ),
                ),
                data: (verdict) {
                  if (verdict == null) {
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Column(
                        children: [
                          Text(
                            'price_verdict.empty_result_prompt'.tr(),
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          VjButton(
                            label: 'price_verdict.new_search_cta'.tr(),
                            onPressed: () => _goBackToScan(context, ref),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PriceVerdictCard(
                        verdict: verdict,
                        category: category,
                        zone: zone,
                        destinationZone: destinationZone,
                        currencyMode: currencyMode,
                        copPerUsd: copPerUsd,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      VjButton(
                        label: 'price_verdict.contribute_from_result_cta'.tr(),
                        leadingIcon: Icons.add_chart_outlined,
                        onPressed: () => _openContributeFlow(context),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      VjButton(
                        label: 'price_verdict.new_search_cta'.tr(),
                        variant: VjButtonVariant.outlined,
                        onPressed: () => _goBackToScan(context, ref),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
