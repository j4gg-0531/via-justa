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
import 'package:via_justa/core/widgets/vj_page_header.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_point_picker_sheet.dart';
import 'package:via_justa/features/prices/presentation/widgets/zone_map_picker_card.dart';

/// Pantalla 14 (M10) · Asistente en 4 pasos para aportar un precio ciudadano.
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

  Future<void> _openDestinationMapSheet({
    required BuildContext context,
    required List<MunicipalityZone> zones,
    required PriceContributionWizardState wizard,
    required String cityName,
    required String languageCode,
  }) async {
    final picked = await showMapPointPickerSheet(
      context: context,
      title: 'price_verdict.taxi_destination_label'.tr(),
      subtitle: 'price_verdict.taxi_destination_sheet_subtitle'.tr(
        namedArgs: {'city': cityName},
      ),
      zones: zones,
      initialZoneId: wizard.selectedDestinationZoneId ?? wizard.selectedZoneId,
      initialLatitude: wizard.destinationLatitude,
      initialLongitude: wizard.destinationLongitude,
      languageCode: languageCode,
      allowGpsButton: false,
    );
    if (!mounted || picked == null) return;
    ref.read(priceContributionProvider.notifier).selectPreciseDestination(
          destinationZoneId: picked.zoneId,
          latitude: picked.latitude,
          longitude: picked.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(priceContributionProvider);
    final notifier = ref.read(priceContributionProvider.notifier);
    final categoriesAsync = ref.watch(priceCategoriesProvider);
    final zonesAsync = ref.watch(municipalityZonesProvider);
    final activeCategory = ref.watch(activeContributionCategoryProvider);
    final activeZone = ref.watch(activeContributionZoneProvider);
    final activeDestZone = ref.watch(activeContributionDestinationZoneProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final isDemoMode = ref.watch(isDemoContributionModeProvider);
    final municipality = ref.watch(selectedMunicipalityProvider);
    final municipalityCode = municipality?.code ?? '20001';

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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Cabecera consistente
              VjPageHeader(
                title: 'price_contribute.page_title'.tr(),
                onBack: () => _handleBack(context),
              ),

              const SizedBox(height: AppSpacing.lg),

              if (wizard.isCompleted)
                _CompletedContributionView(
                  record: wizard.submittedRecord!,
                  category: activeCategory,
                  zone: activeZone,
                  destinationZone: activeDestZone,
                  cityName: cityName,
                  languageCode: languageCode,
                  isDemoMode: isDemoMode,
                  onAnotherContribution: _startNewContribution,
                  onFinish: () => _handleBack(context),
                )
              else ...[
                _StepProgressHeader(
                  currentStep: wizard.currentStep,
                  displayStepNumber: wizard.displayStepNumber,
                ),

                const SizedBox(height: AppSpacing.lg),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<int>(wizard.currentStep),
                    child: wizard.currentStep == 0
                        ? _Step1CategorySelection(
                            categoriesAsync: categoriesAsync,
                            selectedCategoryId: wizard.selectedCategoryId,
                            languageCode: languageCode,
                            onSelectCategory: notifier.selectCategory,
                          )
                        : wizard.currentStep == 1
                        ? _Step2AmountInput(
                            controller: _amountController,
                            errorText: amountErrorKey?.tr(),
                            activeCategory: activeCategory,
                            languageCode: languageCode,
                            onChanged: notifier.setRawAmount,
                            onQuickAmountTap: _applyQuickAmount,
                          )
                        : wizard.currentStep == 2
                        ? _Step3ZoneAndNoteSelection(
                            wizard: wizard,
                            zonesAsync: zonesAsync,
                            activeZone: activeZone,
                            activeDestinationZone: activeDestZone,
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
                            onPickDestinationOnMap: (zones) =>
                                _openDestinationMapSheet(
                                  context: context,
                                  zones: zones,
                                  wizard: wizard,
                                  cityName: cityName,
                                  languageCode: languageCode,
                                ),
                            onNoteChanged: notifier.setRawPlaceNote,
                          )
                        : _Step4ReviewAndConfirm(
                            wizard: wizard,
                            category: activeCategory,
                            zone: activeZone,
                            destinationZone: activeDestZone,
                            cityName: cityName,
                            languageCode: languageCode,
                            isDemoMode: isDemoMode,
                            onEditStep: notifier.goToStep,
                          ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

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
        VjBadge(
          label: 'price_contribute.step_counter'.tr(
            namedArgs: {'step': displayStepNumber.toString(), 'total': '4'},
          ),
          variant: VjBadgeVariant.tonal,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _stepTitleKey(currentStep).tr(),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(4, (index) {
            final isActiveOrDone = index <= currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 6,
                margin: EdgeInsets.only(right: index < 3 ? AppSpacing.xs : 0),
                decoration: BoxDecoration(
                  color: isActiveOrDone ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
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
      borderRadius: AppRadius.xl,
      elevated: true,
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
            loading: () => const Column(
              children: [
                VjSkeletonBox(height: 56, borderRadius: AppRadius.md),
                SizedBox(height: AppSpacing.sm),
                VjSkeletonBox(height: 56, borderRadius: AppRadius.md),
                SizedBox(height: AppSpacing.sm),
                VjSkeletonBox(height: 56, borderRadius: AppRadius.md),
              ],
            ),
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
      borderRadius: AppRadius.xl,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryLabel.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _iconForContributeCategory(activeCategory),
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryLabel,
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.brandNavy,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (unitLabel.isNotEmpty)
                          Text(
                            unitLabel,
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
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'price_contribute.step2_subtitle'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Caja numérica focal estilo fintech
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm + 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: errorText != null
                    ? Theme.of(context).colorScheme.error
                    : AppColors.primaryBorder,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'price_contribute.amount_label'.tr(),
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      r'$',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: onChanged,
                        style: textTheme.headlineLarge?.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.brandNavy,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          hintText: '12000',
                          hintStyle: textTheme.headlineLarge?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'price_contribute.quick_amounts_label'.tr(),
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preset in const ['10000', '12000', '16000', '80000'])
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onQuickAmountTap(preset),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      child: Center(
                        widthFactor: 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs + 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            formatCop(int.parse(preset)),
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paso 3: Ubicación por permiso GPS o selección precisa en mapa (y destino cuando la categoría es taxi).
class _Step3ZoneAndNoteSelection extends StatelessWidget {
  const _Step3ZoneAndNoteSelection({
    required this.wizard,
    required this.zonesAsync,
    required this.activeZone,
    required this.activeDestinationZone,
    required this.cityName,
    required this.municipalityCode,
    required this.languageCode,
    required this.noteController,
    required this.onRequestGpsPermission,
    required this.onDenyGpsPermission,
    required this.onToggleManualMap,
    required this.onZoneTapped,
    required this.onMapPointTapped,
    required this.onPickDestinationOnMap,
    required this.onNoteChanged,
  });

  final PriceContributionWizardState wizard;
  final AsyncValue<List<MunicipalityZone>> zonesAsync;
  final MunicipalityZone? activeZone;
  final MunicipalityZone? activeDestinationZone;
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
  final ValueChanged<List<MunicipalityZone>> onPickDestinationOnMap;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      borderRadius: AppRadius.xl,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          zonesAsync.when(
            loading: () => const Column(
              children: [
                VjSkeletonBox(height: 140, borderRadius: AppRadius.lg),
              ],
            ),
            error: (err, st) => Text(
              'price_verdict.load_error'.tr(),
              style: textTheme.bodySmall,
            ),
            data: (zones) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZoneMapPickerCard(
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
                if (wizard.requiresDestination) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'price_verdict.taxi_destination_label'.tr(),
                    style: textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'price_verdict.taxi_destination_sheet_subtitle'.tr(
                      namedArgs: {'city': cityName},
                    ),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: activeDestinationZone != null
                          ? AppColors.primarySoft
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: wizard.destinationError
                            ? AppColors.semaphoreRed
                            : (activeDestinationZone != null
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: activeDestinationZone != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeDestinationZone
                                        ?.localizedName(languageCode) ??
                                    'price_verdict.taxi_destination_placeholder'
                                        .tr(),
                                style: textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                  color: activeDestinationZone != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (activeDestinationZone != null &&
                                  activeDestinationZone!
                                      .localizedSectorHint(languageCode)
                                      .isNotEmpty)
                                Text(
                                  activeDestinationZone!
                                      .localizedSectorHint(languageCode),
                                  style: textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => onPickDestinationOnMap(zones),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: Text(
                            'price_verdict.pick_point_on_map_btn'.tr(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wizard.destinationError) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'price_contribute.error_destination_required'.tr(),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.semaphoreRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ],
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

/// Paso 4: Resumen de los datos antes de confirmar.
class _Step4ReviewAndConfirm extends StatelessWidget {
  const _Step4ReviewAndConfirm({
    required this.wizard,
    required this.category,
    required this.zone,
    required this.destinationZone,
    required this.cityName,
    required this.languageCode,
    required this.isDemoMode,
    required this.onEditStep,
  });

  final PriceContributionWizardState wizard;
  final PriceCategory? category;
  final MunicipalityZone? zone;
  final MunicipalityZone? destinationZone;
  final String cityName;
  final String languageCode;
  final bool isDemoMode;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categoryName =
        category?.localizedName(languageCode) ?? wizard.selectedCategoryId;
    final unitName = category?.localizedUnit(languageCode) ?? '';
    final zoneName =
        zone?.localizedFullLabel(languageCode) ?? wizard.selectedZoneId;
    final destName = destinationZone?.localizedName(languageCode);
    final locationSummary = destName != null
        ? '$cityName · ${zone?.localizedName(languageCode) ?? wizard.selectedZoneId} → $destName'
        : '$cityName · $zoneName';
    final formattedAmount = wizard.parsedAmount != null
        ? formatCop(wizard.parsedAmount!)
        : wizard.rawAmount;
    final note = wizard.sanitizedNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VjCard(
          borderRadius: AppRadius.xl,
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (isDemoMode
                        ? 'price_contribute.step4_subtitle'
                        : 'price_contribute.live_step4_subtitle')
                    .tr(),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(
                label: 'price_verdict.category_field_label'.tr(),
                value: categoryName,
                subtitle: unitName,
                onEdit: () => onEditStep(0),
              ),
              const Divider(height: AppSpacing.lg),
              _SummaryRow(
                label: 'price_contribute.amount_label'.tr(),
                value: formattedAmount,
                onEdit: () => onEditStep(1),
              ),
              const Divider(height: AppSpacing.lg),
              _SummaryRow(
                label: destName != null
                    ? 'price_contribute.route_summary_label'.tr()
                    : 'price_verdict.zone_field_label'.tr(),
                value: locationSummary,
                onEdit: () => onEditStep(2),
              ),
              if (note != null) ...[
                const Divider(height: AppSpacing.lg),
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
            color: AppColors.primarySoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primaryBorder),
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
                  (isDemoMode
                          ? 'price_contribute.demo_sync_disclaimer'
                          : 'price_contribute.live_sync_disclaimer')
                      .tr(),
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

/// Estado final cuando el aporte ya se guardó.
class _CompletedContributionView extends StatelessWidget {
  const _CompletedContributionView({
    required this.record,
    required this.category,
    required this.zone,
    required this.destinationZone,
    required this.cityName,
    required this.languageCode,
    required this.isDemoMode,
    required this.onAnotherContribution,
    required this.onFinish,
  });

  final PriceContributionRecord record;
  final PriceCategory? category;
  final MunicipalityZone? zone;
  final MunicipalityZone? destinationZone;
  final String cityName;
  final String languageCode;
  final bool isDemoMode;
  final VoidCallback onAnotherContribution;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categoryName =
        category?.localizedName(languageCode) ?? record.categoryId;
    final zoneName = zone?.localizedFullLabel(languageCode) ?? record.zoneId;
    final destName = destinationZone?.localizedName(languageCode);
    final locationLabel = destName != null
        ? '$cityName · ${zone?.localizedName(languageCode) ?? record.zoneId} → $destName'
        : '$cityName · $zoneName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VjCard(
          borderRadius: AppRadius.xl,
          elevated: true,
          backgroundColor: AppColors.primarySoft.withValues(alpha: 0.6),
          borderColor: AppColors.primaryBorder,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.brandNavy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                (isDemoMode
                        ? 'price_contribute.success_title'
                        : 'price_contribute.live_success_title')
                    .tr(),
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                (isDemoMode
                        ? 'price_contribute.demo_sync_disclaimer'
                        : 'price_contribute.live_saved_disclaimer')
                    .tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                categoryName,
                style: textTheme.titleSmall,
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
                locationLabel,
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

IconData _iconForContributeCategory(PriceCategory? category) {
  switch (category?.groupKey) {
    case 'transport':
      return Icons.local_taxi_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'lodging':
      return Icons.bed_outlined;
    case 'services':
      return Icons.local_laundry_service_outlined;
    default:
      return Icons.sell_outlined;
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
      color: selected
          ? AppColors.primarySoft.withValues(alpha: 0.75)
          : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: selected
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    _iconForContributeCategory(category),
                    size: 20,
                    color: selected ? Colors.white : AppColors.brandNavy,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.localizedName(languageCode),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      Text(
                        category.localizedUnit(languageCode),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted,
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
