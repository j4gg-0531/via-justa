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
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/contracts/presentation/widgets/demo_contract_summary.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/zone_map_picker_card.dart';
import 'package:via_justa/features/scan/domain/scan_mode.dart';
import 'package:via_justa/features/scan/presentation/state/scan_providers.dart';

/// Pantalla 10 (M06) · Escaneo y consulta DEMO de precios por zona del municipio (semáforo) y contratos.
class PriceScanPage extends ConsumerStatefulWidget {
  const PriceScanPage({super.key});

  @override
  ConsumerState<PriceScanPage> createState() => _PriceScanPageState();
}

class _PriceScanPageState extends ConsumerState<PriceScanPage> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final initialAmount = ref.read(priceScanProvider).rawAmount;
    _amountController = TextEditingController(text: initialAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('scan.dialog_title'.tr()),
        content: Text('scan.dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _onEvaluatePressed() async {
    FocusScope.of(context).unfocus();
    final municipality = ref.read(selectedMunicipalityProvider);
    final code = municipality?.code ?? '20001';
    final ok = await ref
        .read(priceScanProvider.notifier)
        .submitEvaluation(municipalityCode: code);
    if (!ok || !mounted) return;
    try {
      context.push(AppRoutes.priceResult);
    } catch (_) {}
  }

  void _onScenarioSelected(DemoPriceScenario scenario) {
    ref.read(priceScanProvider.notifier).selectPresetScenario(scenario);
    final updatedAmount = ref.read(priceScanProvider).rawAmount;
    _amountController.value = TextEditingValue(
      text: updatedAmount,
      selection: TextSelection.collapsed(offset: updatedAmount.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode = ref.watch(scanModeProvider);
    final modeNotifier = ref.read(scanModeProvider.notifier);
    final scanState = ref.watch(priceScanProvider);
    final zonesAsync = ref.watch(municipalityZonesProvider);
    final categoriesAsync = ref.watch(priceCategoriesProvider);
    final contractAsync = ref.watch(demoContractAnalysisProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final activeZone = ref.watch(activeVerdictZoneProvider);
    final textTheme = Theme.of(context).textTheme;

    String languageCode;
    try {
      languageCode = context.locale.languageCode;
    } catch (_) {
      languageCode =
          Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Título y subtítulo
              Text(
                'scan.title'.tr(),
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'scan.subtitle'.tr(),
                style: textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Selector segmentado: Precio vs Contrato
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScanModeTab(
                        label: 'scan.tab_price'.tr(),
                        icon: Icons.receipt_long_outlined,
                        selected: selectedMode == ScanMode.price,
                        onTap: () => modeNotifier.selectMode(ScanMode.price),
                      ),
                    ),
                    Expanded(
                      child: _ScanModeTab(
                        label: 'scan.tab_contract'.tr(),
                        icon: Icons.assignment_outlined,
                        selected: selectedMode == ScanMode.contract,
                        onTap: () => modeNotifier.selectMode(ScanMode.contract),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              if (selectedMode == ScanMode.price)
                _PriceScanSection(
                  scanState: scanState,
                  zonesAsync: zonesAsync,
                  categoriesAsync: categoriesAsync,
                  cityName: cityName,
                  activeZone: activeZone,
                  languageCode: languageCode,
                  amountController: _amountController,
                  onScenarioSelected: _onScenarioSelected,
                  onEvaluatePressed: _onEvaluatePressed,
                  onComingSoonTap: () => _showInfoDialog(context),
                )
              else
                _ContractScanSection(
                  contractAsync: contractAsync,
                  onComingSoonTap: () => _showInfoDialog(context),
                ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección del modo Precio (M06): detección por GPS o selección en mapa por zona, categoría comparable, escenarios DEMO, monto y evaluación.
class _PriceScanSection extends ConsumerWidget {
  const _PriceScanSection({
    required this.scanState,
    required this.zonesAsync,
    required this.categoriesAsync,
    required this.cityName,
    required this.activeZone,
    required this.languageCode,
    required this.amountController,
    required this.onScenarioSelected,
    required this.onEvaluatePressed,
    required this.onComingSoonTap,
  });

  final PriceScanState scanState;
  final AsyncValue<List<MunicipalityZone>> zonesAsync;
  final AsyncValue<List<PriceCategory>> categoriesAsync;
  final String cityName;
  final MunicipalityZone? activeZone;
  final String languageCode;
  final TextEditingController amountController;
  final ValueChanged<DemoPriceScenario> onScenarioSelected;
  final VoidCallback onEvaluatePressed;
  final VoidCallback onComingSoonTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(priceScanProvider.notifier);
    final municipality = ref.watch(selectedMunicipalityProvider);
    final municipalityCode = municipality?.code ?? '20001';
    final zoneName =
        activeZone?.localizedName(languageCode) ?? scanState.selectedZoneId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del modo Precio
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.price_check,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'scan.price_header'.tr(),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  VjBadge(label: 'common.demo_badge'.tr()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'scan.price_description'.tr(),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'price_verdict.active_municipality_note'.tr(
                        namedArgs: {
                          'city': cityName,
                          'zone': zoneName,
                        },
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Selector rápido de escenarios DEMO (verde, ámbar, rojo, insuficiente M20, precio bajo)
        Text(
          'price_verdict.demo_scenarios_title'.tr(),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'price_verdict.demo_scenarios_subtitle'.tr(),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _ScenarioChip(
              label: 'price_verdict.scenario_green'.tr(),
              selected:
                  scanState.selectedScenario == DemoPriceScenario.greenFair,
              onTap: () => onScenarioSelected(DemoPriceScenario.greenFair),
            ),
            _ScenarioChip(
              label: 'price_verdict.scenario_yellow'.tr(),
              selected:
                  scanState.selectedScenario ==
                  DemoPriceScenario.yellowModerate,
              onTap: () => onScenarioSelected(DemoPriceScenario.yellowModerate),
            ),
            _ScenarioChip(
              label: 'price_verdict.scenario_red'.tr(),
              selected:
                  scanState.selectedScenario == DemoPriceScenario.redOvercharge,
              onTap: () => onScenarioSelected(DemoPriceScenario.redOvercharge),
            ),
            _ScenarioChip(
              label: 'price_verdict.scenario_insufficient'.tr(),
              selected:
                  scanState.selectedScenario ==
                  DemoPriceScenario.insufficientSample,
              onTap: () =>
                  onScenarioSelected(DemoPriceScenario.insufficientSample),
            ),
            _ScenarioChip(
              label: 'price_verdict.scenario_low_price'.tr(),
              selected:
                  scanState.selectedScenario == DemoPriceScenario.lowPriceAlert,
              onTap: () => onScenarioSelected(DemoPriceScenario.lowPriceAlert),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Formulario: 1) Ubicación automática GPS o Mapa de Zonas + 2) Categoría comparable + 3) Monto en COP
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Selector de Zona por permiso de GPS o Mapa interactivo estilo M08
              zonesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Text(
                  'price_verdict.load_error'.tr(),
                  style: textTheme.bodySmall,
                ),
                data: (zones) => ZoneMapPickerCard(
                  selectedZoneId: scanState.selectedZoneId,
                  locationPermission: scanState.locationPermission,
                  isManualMapOpen: scanState.isManualMapOpen,
                  shouldShowMapPicker: scanState.shouldShowMapPicker,
                  pinAlignmentX: scanState.pinAlignmentX,
                  pinAlignmentY: scanState.pinAlignmentY,
                  zones: zones,
                  activeZone: activeZone,
                  cityName: cityName,
                  languageCode: languageCode,
                  onRequestGpsPermission: () =>
                      notifier.grantLocationPermissionAndDetect(
                        municipalityCode: municipalityCode,
                      ),
                  onDenyGpsPermission:
                      notifier.denyLocationPermissionAndOpenMap,
                  onToggleManualMap: notifier.toggleManualMapPicker,
                  onZoneTapped: notifier.selectZone,
                  onMapPointTapped: (normX, normY) => notifier.selectPointOnMap(
                    normalizedX: normX,
                    normalizedY: normY,
                    zones: zones,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 2. Selector de Categoría Comparable
              Text(
                'price_verdict.category_field_label'.tr(),
                style: textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.sm),
              categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Text(
                  'price_verdict.load_error'.tr(),
                  style: textTheme.bodySmall,
                ),
                data: (categories) {
                  return Column(
                    children: [
                      for (final category in categories)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _CategoryOptionTile(
                            category: category,
                            languageCode: languageCode,
                            selected:
                                scanState.selectedCategoryId == category.id,
                            onTap: () => notifier.selectCategory(category.id),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // 3. Monto observado en COP
              VjTextField(
                label: 'price_verdict.amount_field_label'.tr(),
                controller: amountController,
                keyboardType: TextInputType.number,
                onChanged: notifier.setRawAmount,
                errorText: scanState.amountError
                    ? 'price_verdict.amount_error_invalid'.tr()
                    : null,
              ),

              const SizedBox(height: AppSpacing.sm),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'price_verdict.simulate_event_toggle'.tr(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'price_verdict.simulate_event_subtitle'.tr(),
                  style: textTheme.bodySmall,
                ),
                value: scanState.includeEventContext,
                onChanged: notifier.setIncludeEventContext,
              ),

              const SizedBox(height: AppSpacing.md),

              VjButton(
                label: 'price_verdict.evaluate_cta'.tr(),
                leadingIcon: Icons.analytics_outlined,
                onPressed: scanState.verdictAsync.isLoading
                    ? null
                    : onEvaluatePressed,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Nota de honestidad DEMO y botones de cámara/archivo (próximamente en VJ-13)
        Center(
          child: Text(
            'scan.demo_note'.tr(),
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: VjButton(
                label: 'scan.action_photo'.tr(),
                leadingIcon: Icons.camera_alt_outlined,
                variant: VjButtonVariant.outlined,
                onPressed: onComingSoonTap,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onComingSoonTap,
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                label: Text('scan.action_gallery'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sección del modo Contrato: encabezado + DemoContractSummary con dos puntos en ES/EN.
class _ContractScanSection extends StatelessWidget {
  const _ContractScanSection({
    required this.contractAsync,
    required this.onComingSoonTap,
  });

  final AsyncValue contractAsync;
  final VoidCallback onComingSoonTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(
                Icons.gavel_outlined,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'scan.contract_header'.tr(),
                  style: textTheme.titleMedium,
                ),
              ),
              VjBadge(label: 'common.coming_soon'.tr()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        contractAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Text(
            'price_verdict.load_error'.tr(),
            style: textTheme.bodyMedium,
          ),
          data: (analysis) => DemoContractSummary(
            analysis: analysis,
            onComingSoonTap: onComingSoonTap,
          ),
        ),
      ],
    );
  }
}

class _CategoryOptionTile extends StatelessWidget {
  const _CategoryOptionTile({
    required this.category,
    required this.languageCode,
    required this.selected,
    required this.onTap,
  });

  final PriceCategory category;
  final String languageCode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? AppColors.primarySoft : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.localizedName(languageCode),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Text(
                        category.localizedUnit(languageCode),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.primary : AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }
}

/// Pestaña del selector segmentado
class _ScanModeTab extends StatelessWidget {
  const _ScanModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: selected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
