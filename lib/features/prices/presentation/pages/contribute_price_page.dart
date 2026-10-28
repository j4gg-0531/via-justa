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
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/zone_map_picker_card.dart';

/// Pantalla 14 (M10) · Asistente en 4 pasos para aportar un precio ciudadano (DEMO).
class ContributePricePage extends ConsumerStatefulWidget {
  const ContributePricePage({super.key});

  @override
  ConsumerState<ContributePricePage> createState() =>
      _ContributePricePageState();
}

class _ContributePricePageState extends ConsumerState<ContributePricePage> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(priceContributionProvider);
    _amountController = TextEditingController(text: initial.rawAmount);
    _noteController = TextEditingController(text: initial.rawPlaceNote);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    final wizard = ref.read(priceContributionProvider);
    final notifier = ref.read(priceContributionProvider.notifier);

    if (!wizard.isCompleted && wizard.currentStep > 0) {
      notifier.previousStep();
      return;
    }

    if (GoRouter.maybeOf(context) != null && context.canPop()) {
      context.pop();
    } else if (GoRouter.maybeOf(context) != null) {
      context.go(AppRoutes.home);
    }
  }

  void _applyQuickAmount(String amountText) {
    ref.read(priceContributionProvider.notifier).setRawAmount(amountText);
    _amountController.value = TextEditingValue(
      text: amountText,
      selection: TextSelection.collapsed(offset: amountText.length),
    );
  }

  void _startNewContribution() {
    ref.read(priceContributionProvider.notifier).startNewContribution();
    _amountController.clear();
    _noteController.clear();
  }

  String? _errorKeyForAmount(PriceContributionAmountError? error) {
    switch (error) {
      case PriceContributionAmountError.empty:
        return 'price_contribute.error_amount_empty';
      case PriceContributionAmountError.notPositiveNumber:
        return 'price_contribute.error_amount_invalid';
      case PriceContributionAmountError.belowMinimum:
        return 'price_contribute.error_amount_min';
      case PriceContributionAmountError.aboveMaximum:
        return 'price_contribute.error_amount_max';
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(priceContributionProvider);
    final notifier = ref.read(priceContributionProvider.notifier);
    final categoriesAsync = ref.watch(priceCategoriesProvider);
    final zonesAsync = ref.watch(municipalityZonesProvider);
    final activeCategory = ref.watch(activeContributionCategoryProvider);
    final activeZone = ref.watch(activeContributionZoneProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final municipality = ref.watch(selectedMunicipalityProvider);
    final municipalityCode = municipality?.code ?? '20001';
    final textTheme = Theme.of(context).textTheme;

    String languageCode;
    try {
      languageCode = context.locale.languageCode;
    } catch (_) {
      languageCode =
          Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    final amountErrorKey = _errorKeyForAmount(wizard.amountError);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Cabecera con botón Atrás, título e insignia DEMO
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'common.back'.tr(),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _handleBack(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'price_contribute.page_title'.tr(),
                          style:
                              textTheme.headlineMedium?.copyWith(fontSize: 22),
                        ),
                        VjBadge(label: 'common.demo_badge'.tr()),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Si ya se completó el aporte (Paso 4 confirmado), mostrar pantalla de éxito DEMO
              if (wizard.isCompleted)
                _CompletedContributionView(
                  record: wizard.submittedRecord!,
                  category: activeCategory,
                  zone: activeZone,
                  cityName: cityName,
                  languageCode: languageCode,
                  onAnotherContribution: _startNewContribution,
                  onFinish: () => _handleBack(context),
                )
              else ...[
                // Indicador de progreso de los 4 pasos
                _StepProgressHeader(
                  currentStep: wizard.currentStep,
                  displayStepNumber: wizard.displayStepNumber,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Contenido del paso activo (0, 1, 2 o 3)
                if (wizard.currentStep == 0)
                  _Step1CategorySelection(
                    categoriesAsync: categoriesAsync,
                    selectedCategoryId: wizard.selectedCategoryId,
                    languageCode: languageCode,
                    onSelectCategory: notifier.selectCategory,
                  )
                else if (wizard.currentStep == 1)
                  _Step2AmountInput(
                    controller: _amountController,
                    errorText: amountErrorKey?.tr(),
                    activeCategory: activeCategory,
                    languageCode: languageCode,
                    onChanged: notifier.setRawAmount,
                    onQuickAmountTap: _applyQuickAmount,
                  )
                else if (wizard.currentStep == 2)
                  _Step3ZoneAndNoteSelection(
                    wizard: wizard,
                    zonesAsync: zonesAsync,
                    activeZone: activeZone,
                    cityName: cityName,
                    municipalityCode: municipalityCode,
                    languageCode: languageCode,
                    noteController: _noteController,
                    onRequestGpsPermission: () =>
                        notifier.grantLocationPermissionAndDetect(
                          municipalityCode: municipalityCode,
                        ),
                    onDenyGpsPermission:
                        notifier.denyLocationPermissionAndOpenMap,
                    onToggleManualMap: notifier.toggleManualMapPicker,
                    onZoneTapped: notifier.selectZone,
                    onMapPointTapped: (normX, normY, zones) =>
                        notifier.selectPointOnMap(
                          normalizedX: normX,
                          normalizedY: normY,
                          zones: zones,
                        ),
                    onNoteChanged: notifier.setRawPlaceNote,
                  )
                else
                  _Step4ReviewAndConfirm(
                    wizard: wizard,
                    category: activeCategory,
                    zone: activeZone,
                    cityName: cityName,
                    languageCode: languageCode,
                    onEditStep: notifier.goToStep,
                  ),

                const SizedBox(height: AppSpacing.xl),

                // Botones de navegación del Wizard (Anterior / Siguiente o Confirmar)
                Row(
                  children: [
                    if (wizard.currentStep > 0) ...[
                      Expanded(
                        child: VjButton(
                          label: 'price_contribute.prev_step_cta'.tr(),
                          variant: VjButtonVariant.outlined,
                          onPressed: notifier.previousStep,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      flex: 2,
                      child: wizard.currentStep < 3
                          ? VjButton(
                              label: 'price_contribute.next_step_cta'.tr(),
                              trailingIcon: Icons.arrow_forward,
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                notifier.nextStep();
                              },
                            )
                          : VjButton(
                              label: 'price_contribute.confirm_submit_cta'.tr(),
                              leadingIcon: Icons.check_circle_outline,
                              onPressed: wizard.isSubmitting
                                  ? null
                                  : () => notifier.submitContribution(
                                      municipalityCode: municipalityCode,
                                    ),
                            ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso de 4 segmentos e indicador de paso actual.
class _StepProgressHeader extends StatelessWidget {
  const _StepProgressHeader({
    required this.currentStep,
    required this.displayStepNumber,
  });

  final int currentStep;
  final int displayStepNumber;

  String _stepTitleKey(int step) {
    switch (step) {
      case 0:
        return 'price_contribute.step1_title';
      case 1:
        return 'price_contribute.step2_title';
      case 2:
        return 'price_contribute.step3_title';
      default:
        return 'price_contribute.step4_title';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'price_contribute.step_counter'.tr(
            namedArgs: {'step': displayStepNumber.toString(), 'total': '4'},
          ),
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _stepTitleKey(currentStep).tr(),
          style: textTheme.titleMedium?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(4, (index) {
            final isActiveOrDone = index <= currentStep;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: index < 3 ? AppSpacing.xs : 0),
                decoration: BoxDecoration(
                  color: isActiveOrDone ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Paso 1: Selección de categoría comparable.
class _Step1CategorySelection extends StatelessWidget {
  const _Step1CategorySelection({
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.languageCode,
    required this.onSelectCategory,
  });

  final AsyncValue<List<PriceCategory>> categoriesAsync;
  final String selectedCategoryId;
  final String languageCode;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'price_contribute.step1_subtitle'.tr(),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text(
              'price_verdict.load_error'.tr(),
              style: textTheme.bodySmall,
            ),
            data: (categories) => Column(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SelectableCategoryCard(
                      category: category,
                      languageCode: languageCode,
                      selected: category.id == selectedCategoryId,
                      onTap: () => onSelectCategory(category.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paso 2: Ingreso de monto en COP con validación en dominio y botones rápidos de referencia.
class _Step2AmountInput extends StatelessWidget {
  const _Step2AmountInput({
    required this.controller,
    required this.errorText,
    required this.activeCategory,
    required this.languageCode,
    required this.onChanged,
    required this.onQuickAmountTap,
  });

  final TextEditingController controller;
  final String? errorText;
  final PriceCategory? activeCategory;
  final String languageCode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onQuickAmountTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categoryLabel = activeCategory?.localizedName(languageCode) ?? '';
    final unitLabel = activeCategory?.localizedUnit(languageCode) ?? '';

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryLabel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel,
                    style: textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  if (unitLabel.isNotEmpty)
                    Text(unitLabel, style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'price_contribute.step2_subtitle'.tr(),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          VjTextField(
            label: 'price_contribute.amount_label'.tr(),
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            errorText: errorText,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'price_contribute.quick_amounts_label'.tr(),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preset in const ['10000', '12000', '16000', '80000'])
                ActionChip(
                  label: Text(formatCop(int.parse(preset))),
                  onPressed: () => onQuickAmountTap(preset),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paso 3: Ubicación por permiso GPS o selección en mapa por zona + nota opcional sin PII.
class _Step3ZoneAndNoteSelection extends StatelessWidget {
  const _Step3ZoneAndNoteSelection({
    required this.wizard,
    required this.zonesAsync,
    required this.activeZone,
    required this.cityName,
    required this.municipalityCode,
    required this.languageCode,
    required this.noteController,
    required this.onRequestGpsPermission,
    required this.onDenyGpsPermission,
    required this.onToggleManualMap,
    required this.onZoneTapped,
    required this.onMapPointTapped,
    required this.onNoteChanged,
  });

  final PriceContributionWizardState wizard;
  final AsyncValue<List<MunicipalityZone>> zonesAsync;
  final MunicipalityZone? activeZone;
  final String cityName;
  final String municipalityCode;
  final String languageCode;
  final TextEditingController noteController;
  final VoidCallback onRequestGpsPermission;
  final VoidCallback onDenyGpsPermission;
  final ValueChanged<bool> onToggleManualMap;
  final ValueChanged<String> onZoneTapped;
  final void Function(
    double normalizedX,
    double normalizedY,
    List<MunicipalityZone> zones,
  ) onMapPointTapped;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          zonesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text(
              'price_verdict.load_error'.tr(),
              style: textTheme.bodySmall,
            ),
            data: (zones) => ZoneMapPickerCard(
              selectedZoneId: wizard.selectedZoneId,
              locationPermission: wizard.locationPermission,
              isManualMapOpen: wizard.isManualMapOpen,
              shouldShowMapPicker: wizard.shouldShowMapPicker,
              pinAlignmentX: wizard.pinAlignmentX,
              pinAlignmentY: wizard.pinAlignmentY,
              zones: zones,
              activeZone: activeZone,
              cityName: cityName,
              languageCode: languageCode,
              onRequestGpsPermission: onRequestGpsPermission,
              onDenyGpsPermission: onDenyGpsPermission,
              onToggleManualMap: onToggleManualMap,
              onZoneTapped: onZoneTapped,
              onMapPointTapped: (normX, normY) =>
                  onMapPointTapped(normX, normY, zones),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          VjTextField(
            label: 'price_contribute.note_label'.tr(),
            controller: noteController,
            onChanged: onNoteChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'price_contribute.note_privacy_helper'.tr(),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Paso 4: Resumen de los datos antes de confirmar y aviso obligatorio de honestidad DEMO.
class _Step4ReviewAndConfirm extends StatelessWidget {
  const _Step4ReviewAndConfirm({
    required this.wizard,
    required this.category,
    required this.zone,
    required this.cityName,
    required this.languageCode,
    required this.onEditStep,
  });

  final PriceContributionWizardState wizard;
  final PriceCategory? category;
  final MunicipalityZone? zone;
  final String cityName;
  final String languageCode;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categoryName =
        category?.localizedName(languageCode) ?? wizard.selectedCategoryId;
    final unitName = category?.localizedUnit(languageCode) ?? '';
    final zoneName =
        zone?.localizedFullLabel(languageCode) ?? wizard.selectedZoneId;
    final formattedAmount = wizard.parsedAmount != null
        ? formatCop(wizard.parsedAmount!)
        : wizard.rawAmount;
    final note = wizard.sanitizedNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'price_contribute.step4_subtitle'.tr(),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(
                label: 'price_verdict.category_field_label'.tr(),
                value: categoryName,
                subtitle: unitName,
                onEdit: () => onEditStep(0),
              ),
              const Divider(height: AppSpacing.lg, color: AppColors.border),
              _SummaryRow(
                label: 'price_contribute.amount_label'.tr(),
                value: formattedAmount,
                onEdit: () => onEditStep(1),
              ),
              const Divider(height: AppSpacing.lg, color: AppColors.border),
              _SummaryRow(
                label: 'price_verdict.zone_field_label'.tr(),
                value: '$cityName · $zoneName',
                onEdit: () => onEditStep(2),
              ),
              if (note != null) ...[
                const Divider(height: AppSpacing.lg, color: AppColors.border),
                _SummaryRow(
                  label: 'price_contribute.note_label'.tr(),
                  value: note,
                  onEdit: () => onEditStep(2),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'price_contribute.demo_sync_disclaimer'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Estado final cuando el aporte ya se guardó localmente en modo DEMO.
class _CompletedContributionView extends StatelessWidget {
  const _CompletedContributionView({
    required this.record,
    required this.category,
    required this.zone,
    required this.cityName,
    required this.languageCode,
    required this.onAnotherContribution,
    required this.onFinish,
  });

  final PriceContributionRecord record;
  final PriceCategory? category;
  final MunicipalityZone? zone;
  final String cityName;
  final String languageCode;
  final VoidCallback onAnotherContribution;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categoryName =
        category?.localizedName(languageCode) ?? record.categoryId;
    final zoneName = zone?.localizedFullLabel(languageCode) ?? record.zoneId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.semaphoreGreenSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.semaphoreGreen, width: 1.8),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.semaphoreGreen,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'price_contribute.success_title'.tr(),
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'price_contribute.demo_sync_disclaimer'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              Text(
                categoryName,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                formatCop(record.amountCop),
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$cityName · $zoneName',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        VjButton(
          label: 'price_contribute.another_contribution_cta'.tr(),
          leadingIcon: Icons.add,
          onPressed: onAnotherContribution,
        ),
        const SizedBox(height: AppSpacing.sm),
        VjButton(
          label: 'common.back'.tr(),
          variant: VjButtonVariant.outlined,
          onPressed: onFinish,
        ),
      ],
    );
  }
}

class _SelectableCategoryCard extends StatelessWidget {
  const _SelectableCategoryCard({
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
          constraints: const BoxConstraints(minHeight: 52),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                  selected ? Icons.check_circle : Icons.circle_outlined,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onEdit,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 20),
          color: AppColors.primary,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    );
  }
}
