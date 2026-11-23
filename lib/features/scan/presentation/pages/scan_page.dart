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
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_dashed_box.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_analysis_provider.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';
import 'package:via_justa/features/contracts/presentation/widgets/contract_analysis_result_view.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_point_picker_sheet.dart';
import 'package:via_justa/features/scan/domain/scan_mode.dart';
import 'package:via_justa/features/scan/presentation/state/scan_providers.dart';

/// Pantalla Analizar (M06) · Interfaz unificada y limpia para revisar precios y contratos.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  late final TextEditingController _amountController;
  late final TextEditingController _contractTextController;

  @override
  void initState() {
    super.initState();
    final initialAmount = ref.read(priceScanProvider).rawAmount;
    _amountController = TextEditingController(text: initialAmount);
    final initialContractText = ref.read(contractCaptureProvider).text;
    _contractTextController = TextEditingController(text: initialContractText);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _contractTextController.dispose();
    super.dispose();
  }

  void _showConsentDialog(
    BuildContext context,
    ContractCaptureNotifier notifier,
    String languageCode,
  ) {
    showVjConfirmDialog(
      context: context,
      icon: Icons.shield_outlined,
      barrierDismissible: false,
      title: 'contract_capture.consent_dialog_title'.tr(),
      body: 'contract_capture.consent_dialog_body'.tr(),
      cancelLabel: 'contract_capture.consent_cancel'.tr(),
      confirmLabel: 'contract_capture.consent_continue'.tr(),
      onCancel: notifier.cancelConsent,
      onConfirm: () =>
          notifier.confirmConsentAndProceed(languageCode: languageCode),
    );
  }

  void _showAiConsentDialog(
    BuildContext context,
    ContractAnalysisNotifier notifier,
  ) {
    showVjConfirmDialog(
      context: context,
      icon: Icons.auto_awesome_outlined,
      barrierDismissible: false,
      title: 'contract_analysis.ai_consent_dialog_title'.tr(),
      body: 'contract_analysis.ai_consent_dialog_body'.tr(),
      cancelLabel: 'contract_analysis.ai_consent_cancel'.tr(),
      confirmLabel: 'contract_analysis.ai_consent_continue'.tr(),
      onCancel: notifier.cancelAiConsent,
      onConfirm: notifier.confirmAiConsentAndProceed,
    );
  }

  Future<void> _onEvaluatePressed() async {
    FocusScope.of(context).unfocus();
    final municipality = ref.read(selectedMunicipalityProvider);
    final code = municipality?.code ?? '20001';
    final ok = await ref
        .read(priceScanProvider.notifier)
        .submitEvaluation(municipalityCode: code);
    final hasError = ref.read(priceScanProvider).verdictAsync.hasError;
    if ((!ok && !hasError) || !mounted) return;
    try {
      context.push(AppRoutes.priceResult);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode = ref.watch(scanModeProvider);
    final modeNotifier = ref.read(scanModeProvider.notifier);
    final scanState = ref.watch(priceScanProvider);
    final zonesAsync = ref.watch(municipalityZonesProvider);
    final categoriesAsync = ref.watch(priceCategoriesProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final activeZone = ref.watch(activeVerdictZoneProvider);
    final activeDestinationZone = ref.watch(activeVerdictDestinationZoneProvider);
    final textTheme = Theme.of(context).textTheme;

    final captureState = ref.watch(contractCaptureProvider);
    final analysisState = ref.watch(contractAnalysisProvider);
    final captureNotifier = ref.read(contractCaptureProvider.notifier);
    final analysisNotifier = ref.read(contractAnalysisProvider.notifier);

    String languageCode;
    try {
      languageCode = context.locale.languageCode;
    } catch (_) {
      languageCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    ref.listen<ContractCaptureState>(contractCaptureProvider, (previous, next) {
      if (next.pendingConsentSource != null &&
          previous?.pendingConsentSource == null) {
        _showConsentDialog(context, captureNotifier, languageCode);
      }
    });

    ref.listen<ContractAnalysisState>(contractAnalysisProvider,
        (previous, next) {
      if (next.isAiConsentDialogVisible &&
          previous?.isAiConsentDialogVisible != true) {
        _showAiConsentDialog(context, analysisNotifier);
      }
    });

    if (_contractTextController.text != captureState.text) {
      _contractTextController.value = TextEditingValue(
        text: captureState.text,
        selection: TextSelection.collapsed(offset: captureState.text.length),
      );
    }

    final canPopRoute = GoRouter.maybeOf(context)?.canPop() ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Cabecera compacta sin duplicar títulos ni flecha innecesaria en pestaña raíz
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (canPopRoute) ...[
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: () => context.pop(),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                            semanticLabel: 'common.back'.tr(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      'scan.headline'.tr(),
                      style: textTheme.headlineMedium?.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 148),
                    child: VjBadge(
                      label: cityName,
                      icon: Icons.location_on_outlined,
                      variant: VjBadgeVariant.neutral,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Segmented control limpio animado: Precio vs Contrato
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeSegmentTab(
                        title: 'scan.tab_price'.tr(),
                        icon: Icons.sell_outlined,
                        selected: selectedMode == ScanMode.price,
                        onTap: () => modeNotifier.selectMode(ScanMode.price),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _ModeSegmentTab(
                        title: 'scan.tab_contract'.tr(),
                        icon: Icons.description_outlined,
                        selected: selectedMode == ScanMode.contract,
                        onTap: () =>
                            modeNotifier.selectMode(ScanMode.contract),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Transición suave entre Precio y Contrato
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey(selectedMode),
                  child: selectedMode == ScanMode.contract
                      ? _ContractContentSection(
                          captureState: captureState,
                          analysisState: analysisState,
                          captureNotifier: captureNotifier,
                          analysisNotifier: analysisNotifier,
                          textController: _contractTextController,
                          languageCode: languageCode,
                        )
                      : _PriceContentSection(
                          scanState: scanState,
                          zonesAsync: zonesAsync,
                          categoriesAsync: categoriesAsync,
                          cityName: cityName,
                          activeZone: activeZone,
                          activeDestinationZone: activeDestinationZone,
                          languageCode: languageCode,
                          amountController: _amountController,
                          onEvaluatePressed: _onEvaluatePressed,
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Línea discreta de confianza y privacidad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 17,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        selectedMode == ScanMode.contract
                            ? 'scan.reassurance_contract'.tr()
                            : 'scan.reassurance_price'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmento táctil animado superior (Precio / Contrato).
class _ModeSegmentTab extends StatelessWidget {
  const _ModeSegmentTab({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.brandNavy.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? AppColors.brandNavy
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? AppColors.brandNavy
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// Vista interactiva para contratos: subida de archivos/foto, OCR y análisis con IA.
class _ContractContentSection extends StatelessWidget {
  const _ContractContentSection({
    required this.captureState,
    required this.analysisState,
    required this.captureNotifier,
    required this.analysisNotifier,
    required this.textController,
    required this.languageCode,
  });

  final ContractCaptureState captureState;
  final ContractAnalysisState analysisState;
  final ContractCaptureNotifier captureNotifier;
  final ContractAnalysisNotifier analysisNotifier;
  final TextEditingController textController;
  final String languageCode;

  String _resolveCaptureErrorMessage(ContractCaptureState state) {
    switch (state.error) {
      case ContractCaptureError.unsupportedFormat:
        return 'contract_capture.error_unsupported_format'.tr();
      case ContractCaptureError.pdfComingSoon:
        return 'contract_capture.error_pdf_coming_soon'.tr();
      case ContractCaptureError.fileTooLarge:
        return 'contract_capture.error_file_too_large'.tr();
      case ContractCaptureError.emptyOrIllegibleText:
        return 'contract_capture.error_empty_or_illegible'.tr();
      case ContractCaptureError.exceedsMaxLength:
        return 'contract_capture.error_exceeds_max_length'.tr(
          namedArgs: {
            'count': '${state.characterCount}',
            'excess': '${state.excessCharacters}',
          },
        );
      case ContractCaptureError.readFailed:
        return 'contract_capture.error_read_failed'.tr();
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAnalyzeEnabled =
        captureState.isReadyForAnalysis && !analysisState.isAnalyzing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjeta unificada de captura de contratos: dropzone limpio + 2 acciones lado a lado
        VjCard(
          borderRadius: AppRadius.xl,
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: captureState.status ==
                        ContractCaptureStatus.readingDocument
                    ? null
                    : () => captureNotifier.requestFilePicker(
                          languageCode: languageCode,
                        ),
                child: VjDashedBox(
                  borderRadius: AppRadius.xl,
                  color: AppColors.primary.withValues(alpha: 0.40),
                  backgroundColor: AppColors.surfaceSubtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'scan.upload_box_title'.tr(),
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'scan.upload_box_hint'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final stacked =
                      constraints.maxWidth < 290 || textScale >= 1.55;
                  final isBusy =
                      captureState.status ==
                      ContractCaptureStatus.readingDocument;

                  final fileButton = VjButton(
                    label: 'scan.upload_box_action'.tr(),
                    leadingIcon: Icons.file_upload_outlined,
                    onPressed: isBusy
                        ? null
                        : () => captureNotifier.requestFilePicker(
                              languageCode: languageCode,
                            ),
                  );
                  final cameraButton = VjButton(
                    label: 'scan.action_take_photo_now'.tr(),
                    leadingIcon: Icons.camera_alt_outlined,
                    variant: VjButtonVariant.outlined,
                    onPressed: isBusy
                        ? null
                        : () => captureNotifier.requestCameraCapture(
                              languageCode: languageCode,
                            ),
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        fileButton,
                        const SizedBox(height: AppSpacing.sm),
                        cameraButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: fileButton),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: cameraButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton.icon(
                  onPressed: captureNotifier.startManualEntry,
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'scan.manual_text_toggle'.tr(),
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Estado de lectura OCR
        if (captureState.status == ContractCaptureStatus.readingDocument) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            borderRadius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const VjSkeletonBox(
                  width: 36,
                  height: 36,
                  borderRadius: AppRadius.md,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'contract_capture.status_reading'.tr(),
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const VjSkeletonBox(height: 10, width: 150),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Aviso de error de captura (formato no soportado, > 10 MB, texto vacío o exceso de longitud)
        if (captureState.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _resolveCaptureErrorMessage(captureState),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (captureState.error ==
                    ContractCaptureError.exceedsMaxLength) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: captureNotifier.trimToMaxLength,
                      icon: const Icon(Icons.content_cut, size: 16),
                      label: Text('contract_capture.trim_to_limit_cta'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Editor de texto cuando ya se cargó o escribió contenido
        if (captureState.showTextEditor) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            borderRadius: AppRadius.xl,
            elevated: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'contract_capture.editor_label'.tr(),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (captureState.isReadyForAnalysis)
                      VjBadge(
                        label: 'contract_capture.status_ready'.tr(),
                        variant: VjBadgeVariant.navy,
                      ),
                    if (captureState.wasTempFileDeleted)
                      VjBadge(
                        label: 'contract_capture.rn10_temp_deleted_badge'.tr(),
                        variant: VjBadgeVariant.neutral,
                      ),
                  ],
                ),
                if (captureState.fileName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    captureState.fileName!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: textController,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: captureNotifier.updateContractText,
                  decoration: InputDecoration(
                    hintText: 'contract_capture.editor_hint'.tr(),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'contract_capture.char_counter'.tr(
                        namedArgs: {
                          'count': '${captureState.characterCount}',
                          'max': '${captureState.maxCharacters}',
                        },
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        color: captureState.isOverCharacterLimit
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: captureNotifier.discardDocument,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('contract_capture.discard_cta'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                VjButton(
                  label: 'contract_analysis.analyze_cta'.tr(),
                  leadingIcon: Icons.auto_awesome_outlined,
                  onPressed: isAnalyzeEnabled
                      ? () => analysisNotifier.requestAnalysis(
                            text: captureState.text,
                            locale: languageCode,
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],

        // Estado de análisis con IA
        if (analysisState.isAnalyzing) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            borderRadius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
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
                            'contract_analysis.analyzing_status'.tr(),
                            style: textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'contract_analysis.analyzing_hint'.tr(),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const VjSkeletonBox(height: 12),
                const SizedBox(height: AppSpacing.xs),
                const VjSkeletonBox(height: 12, width: 220),
              ],
            ),
          ),
        ],

        // Error de análisis con reintento
        if (analysisState.hasError && analysisState.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            borderRadius: AppRadius.xl,
            backgroundColor: AppColors.semaphoreRedSoft,
            borderColor: AppColors.semaphoreRed.withValues(alpha: 0.45),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.error_title'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.semaphoreRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  analysisState.error!.translationKey.tr(),
                  style: textTheme.bodySmall,
                ),
                if (analysisState.canRetry) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: VjButton(
                      label: 'contract_analysis.action_retry'.tr(),
                      leadingIcon: Icons.refresh,
                      onPressed: analysisNotifier.retryAnalysis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Resultado estructurado del análisis con IA
        if (analysisState.hasResult) ...[
          const SizedBox(height: AppSpacing.md),
          ContractAnalysisResultView(result: analysisState.result!),
        ],
      ],
    );
  }
}

/// Formulario limpio de evaluación de precios: sin caja falsa de OCR, con Origen+Destino para Taxi
/// o Ubicación única del establecimiento para las demás categorías, seleccionadas en bottom sheet.
class _PriceContentSection extends ConsumerWidget {
  const _PriceContentSection({
    required this.scanState,
    required this.zonesAsync,
    required this.categoriesAsync,
    required this.cityName,
    required this.activeZone,
    required this.activeDestinationZone,
    required this.languageCode,
    required this.amountController,
    required this.onEvaluatePressed,
  });

  final PriceScanState scanState;
  final AsyncValue<List<MunicipalityZone>> zonesAsync;
  final AsyncValue<List<PriceCategory>> categoriesAsync;
  final String cityName;
  final MunicipalityZone? activeZone;
  final MunicipalityZone? activeDestinationZone;
  final String languageCode;
  final TextEditingController amountController;
  final VoidCallback onEvaluatePressed;

  IconData _iconForGroup(String groupKey) {
    switch (groupKey) {
      case 'transport':
        return Icons.local_taxi_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'lodging':
        return Icons.hotel_outlined;
      default:
        return Icons.local_laundry_service_outlined;
    }
  }

  Future<void> _openOriginPicker(
    BuildContext context,
    PriceScanNotifier notifier,
    List<MunicipalityZone> zones,
  ) async {
    final picked = await showMapPointPickerSheet(
      context: context,
      title: scanState.isTaxiCategory
          ? 'price_verdict.taxi_origin_label'.tr()
          : 'price_verdict.establishment_location_label'.tr(),
      subtitle: scanState.isTaxiCategory
          ? 'price_verdict.taxi_origin_sheet_subtitle'.tr(
              namedArgs: {'city': cityName},
            )
          : 'price_verdict.establishment_location_sheet_subtitle'.tr(
              namedArgs: {'city': cityName},
            ),
      zones: zones,
      initialZoneId: scanState.selectedZoneId,
      initialLatitude: scanState.originLatitude,
      initialLongitude: scanState.originLongitude,
      languageCode: languageCode,
      allowGpsButton: true,
    );
    if (picked != null) {
      notifier.selectOriginPoint(
        zoneId: picked.zoneId,
        latitude: picked.latitude,
        longitude: picked.longitude,
        normalizedX: picked.normalizedX,
        normalizedY: picked.normalizedY,
      );
    }
  }

  Future<void> _openDestinationPicker(
    BuildContext context,
    PriceScanNotifier notifier,
    List<MunicipalityZone> zones,
  ) async {
    final picked = await showMapPointPickerSheet(
      context: context,
      title: 'price_verdict.taxi_destination_label'.tr(),
      subtitle: 'price_verdict.taxi_destination_sheet_subtitle'.tr(
        namedArgs: {'city': cityName},
      ),
      zones: zones,
      initialZoneId: scanState.destinationZoneId ?? scanState.selectedZoneId,
      initialLatitude: scanState.destinationLatitude,
      initialLongitude: scanState.destinationLongitude,
      languageCode: languageCode,
      allowGpsButton: false,
    );
    if (picked != null) {
      notifier.selectDestinationPoint(
        zoneId: picked.zoneId,
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(priceScanProvider.notifier);
    final originZoneName =
        activeZone?.localizedName(languageCode) ?? scanState.selectedZoneId;
    final destinationZoneName = activeDestinationZone != null
        ? '$cityName · ${activeDestinationZone!.localizedName(languageCode)}'
        : 'price_verdict.taxi_destination_placeholder'.tr();
    final zones = zonesAsync.value ?? const <MunicipalityZone>[];

    void applyPreset(String preset) {
      notifier.setRawAmount(preset);
      amountController.value = TextEditingValue(
        text: preset,
        selection: TextSelection.collapsed(offset: preset.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Carrusel horizontal de categorías (una sola fila limpia, sin escalera vertical)
        categoriesAsync.when(
          loading: () => const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                VjSkeletonBox(
                  width: 112,
                  height: 44,
                  borderRadius: AppRadius.pill,
                ),
                SizedBox(width: AppSpacing.sm),
                VjSkeletonBox(
                  width: 124,
                  height: 44,
                  borderRadius: AppRadius.pill,
                ),
                SizedBox(width: AppSpacing.sm),
                VjSkeletonBox(
                  width: 108,
                  height: 44,
                  borderRadius: AppRadius.pill,
                ),
              ],
            ),
          ),
          error: (err, st) => VjCard(
            borderRadius: AppRadius.lg,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'price_verdict.load_error'.tr(),
                    style: textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(priceCategoriesProvider),
                  child: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
          data: (categories) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  _HorizontalCategoryPill(
                    icon: _iconForGroup(categories[i].groupKey),
                    label: categories[i].localizedName(languageCode),
                    selected: scanState.selectedCategoryId == categories[i].id,
                    onTap: () => notifier.selectCategory(categories[i].id),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 2. Tarjeta principal con ruta/zona compacta y monto protagonista estilo fintech
        VjCard(
          borderRadius: AppRadius.xl,
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de ubicación conectado (Ruta Origen -> Destino para Taxi o zona única)
              if (scanState.isTaxiCategory) ...[
                _ConnectedTaxiRouteCard(
                  originLabel: '$cityName · $originZoneName',
                  destinationLabel: destinationZoneName,
                  hasDestination: activeDestinationZone != null,
                  hasDestinationError: scanState.destinationError,
                  onOriginTap: zones.isEmpty
                      ? null
                      : () => _openOriginPicker(context, notifier, zones),
                  onDestinationTap: zones.isEmpty
                      ? null
                      : () => _openDestinationPicker(context, notifier, zones),
                ),
                if (scanState.destinationError) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.semaphoreRed,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'price_contribute.error_destination_required'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.semaphoreRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else
                _LocationSelectorRow(
                  icon: Icons.location_on_outlined,
                  eyebrow: 'price_verdict.establishment_location_label'.tr(),
                  label: '$cityName · $originZoneName',
                  actionLabel: 'scan.change_zone_action'.tr(),
                  onTap: zones.isEmpty
                      ? null
                      : () => _openOriginPicker(context, notifier, zones),
                ),

              const SizedBox(height: AppSpacing.md),

              // Bloque protagonista de monto en COP con montos rápidos
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scanState.amountError
                      ? AppColors.semaphoreRedSoft.withValues(alpha: 0.45)
                      : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: scanState.amountError
                        ? AppColors.semaphoreRed
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'price_verdict.amount_field_label'.tr().toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: notifier.setRawAmount,
                      style: textTheme.headlineLarge?.copyWith(
                        fontSize: 30,
                        color: AppColors.brandNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: textTheme.headlineLarge?.copyWith(
                          fontSize: 30,
                          color: AppColors.textMuted,
                        ),
                        prefixText: r'$ ',
                        prefixStyle: textTheme.titleLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        suffixText: ' COP',
                        suffixStyle: textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final preset in const [
                          ('10000', r'$10k'),
                          ('18000', r'$18k'),
                          ('25000', r'$25k'),
                          ('50000', r'$50k'),
                        ])
                          _QuickAmountChip(
                            label: preset.$2,
                            selected: scanState.rawAmount == preset.$1,
                            onTap: () => applyPreset(preset.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (scanState.amountError) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.semaphoreRed,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'price_verdict.amount_error_invalid'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.semaphoreRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // 4. Botón principal de evaluar precio
              VjButton(
                label: 'price_verdict.evaluate_cta'.tr(),
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed:
                    scanState.verdictAsync.isLoading ? null : onEvaluatePressed,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Píldora horizontal táctil de categoría comparable en el escáner de precios.
class _HorizontalCategoryPill extends StatelessWidget {
  const _HorizontalCategoryPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brandNavy : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.brandNavy : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

/// Tarjeta compacta conectada Origen -> Destino para cotizaciones de taxi.
class _ConnectedTaxiRouteCard extends StatelessWidget {
  const _ConnectedTaxiRouteCard({
    required this.originLabel,
    required this.destinationLabel,
    required this.hasDestination,
    required this.hasDestinationError,
    required this.onOriginTap,
    required this.onDestinationTap,
  });

  final String originLabel;
  final String destinationLabel;
  final bool hasDestination;
  final bool hasDestinationError;
  final VoidCallback? onOriginTap;
  final VoidCallback? onDestinationTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: hasDestinationError
              ? AppColors.semaphoreRed
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOriginTap,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'price_verdict.taxi_origin_label'.tr(),
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            originLabel,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'scan.change_zone_action'.tr(),
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: AppSpacing.xl + 8),
          InkWell(
            onTap: onDestinationTap,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.lg),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: hasDestinationError
                          ? AppColors.semaphoreRed
                          : (hasDestination
                              ? AppColors.brandNavy
                              : AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'price_verdict.taxi_destination_label'.tr(),
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            destinationLabel,
                            style: textTheme.bodyMedium?.copyWith(
                              color: hasDestination
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: hasDestination
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'price_verdict.pick_point_on_map_btn'.tr(),
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip rápido de monto de referencia dentro de la caja protagonista COP.
class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 52),
          child: Center(
            widthFactor: 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.brandNavy : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected ? AppColors.brandNavy : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSelectorRow extends StatelessWidget {
  const _LocationSelectorRow({
    required this.icon,
    required this.eyebrow,
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String label;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eyebrow,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(
                actionLabel,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
