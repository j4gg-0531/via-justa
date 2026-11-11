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
import 'package:via_justa/core/widgets/vj_dashed_box.dart';
import 'package:via_justa/core/widgets/vj_text_field.dart';
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('contract_capture.consent_dialog_title'.tr()),
        content: Text('contract_capture.consent_dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              notifier.cancelConsent();
            },
            child: Text('contract_capture.consent_cancel'.tr()),
          ),
          VjButton(
            label: 'contract_capture.consent_continue'.tr(),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              notifier.confirmConsentAndProceed(languageCode: languageCode);
            },
          ),
        ],
      ),
    );
  }

  void _showAiConsentDialog(
    BuildContext context,
    ContractAnalysisNotifier notifier,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('contract_analysis.ai_consent_dialog_title'.tr()),
        content: Text('contract_analysis.ai_consent_dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              notifier.cancelAiConsent();
            },
            child: Text('contract_analysis.ai_consent_cancel'.tr()),
          ),
          VjButton(
            label: 'contract_analysis.ai_consent_continue'.tr(),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              notifier.confirmAiConsentAndProceed();
            },
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // Barra superior limpia con botón atrás y título
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 48),
                        child: Text(
                          'scan.app_bar_title'.tr(),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Encabezado principal
              Text(
                'scan.headline'.tr(),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'scan.subtitle'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Selector visual de dos tarjetas: Precio vs Contrato
              Row(
                children: [
                  Expanded(
                    child: _ModeSelectorCard(
                      title: 'scan.tab_price'.tr(),
                      description: 'scan.price_card_desc'.tr(),
                      icon: Icons.sell_outlined,
                      selected: selectedMode == ScanMode.price,
                      onTap: () => modeNotifier.selectMode(ScanMode.price),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ModeSelectorCard(
                      title: 'scan.tab_contract'.tr(),
                      description: 'scan.contract_card_desc'.tr(),
                      icon: Icons.description_outlined,
                      selected: selectedMode == ScanMode.contract,
                      onTap: () => modeNotifier.selectMode(ScanMode.contract),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Contenido interactivo según el modo seleccionado
              if (selectedMode == ScanMode.contract)
                _ContractContentSection(
                  captureState: captureState,
                  analysisState: analysisState,
                  captureNotifier: captureNotifier,
                  analysisNotifier: analysisNotifier,
                  textController: _contractTextController,
                  languageCode: languageCode,
                )
              else
                _PriceContentSection(
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

              const SizedBox(height: AppSpacing.lg),

              // Banner inferior de seguridad y confianza
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        selectedMode == ScanMode.contract
                            ? 'scan.reassurance_contract'.tr()
                            : 'scan.reassurance_price'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.35,
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

/// Tarjeta selectora visual superior (Precio vs Contrato) con borde activo azul.
class _ModeSelectorCard extends StatelessWidget {
  const _ModeSelectorCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return VjCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
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
        // Caja punteada para subir foto o archivo TXT (PDF marcado Próximamente)
        VjDashedBox(
          child: Column(
            children: [
              Text(
                'scan.upload_box_title'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'scan.upload_box_hint'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              ActionChip(
                avatar: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: Text(
                  'contract_capture.pdf_coming_soon_chip'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.background,
                side: const BorderSide(color: AppColors.border),
                onPressed: captureNotifier.notifyPdfComingSoon,
              ),
              const SizedBox(height: AppSpacing.sm),
              VjButton(
                label: 'scan.upload_box_action'.tr(),
                leadingIcon: Icons.file_upload_outlined,
                onPressed: captureState.status ==
                        ContractCaptureStatus.readingDocument
                    ? null
                    : () => captureNotifier.requestFilePicker(
                          languageCode: languageCode,
                        ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Botón secundario para tomar foto con la cámara
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: captureState.status ==
                    ContractCaptureStatus.readingDocument
                ? null
                : () => captureNotifier.requestCameraCapture(
                      languageCode: languageCode,
                    ),
            icon: const Icon(
              Icons.camera_alt_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
            label: Text(
              'scan.action_take_photo_now'.tr(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // Opción sutil para redactar o pegar texto manualmente
        Center(
          child: TextButton.icon(
            onPressed: captureNotifier.startManualEntry,
            icon:
                const Icon(Icons.edit_note, size: 18, color: AppColors.primary),
            label: Text(
              'scan.manual_text_toggle'.tr(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),

        // Estado de lectura OCR
        if (captureState.status == ContractCaptureStatus.readingDocument) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'contract_capture.status_reading'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Aviso de error de captura (formato no soportado, PDF próximamente, > 10 MB, texto vacío o exceso de longitud)
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
            child: Row(
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
          ),
        ],

        // Editor de texto cuando ya se cargó o escribió contenido
        if (captureState.showTextEditor) ...[
          const SizedBox(height: AppSpacing.md),
          VjCard(
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
                      VjBadge(label: 'contract_capture.status_ready'.tr()),
                    if (captureState.wasTempFileDeleted)
                      VjBadge(
                        label: 'contract_capture.rn10_temp_deleted_badge'.tr(),
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
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'contract_analysis.analyzing_status'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
          ),
        ],

        // Error de análisis con reintento
        if (analysisState.hasError && analysisState.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.semaphoreRed, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'contract_analysis.error_title'.tr(),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector de categoría comparable
          Text(
            'price_verdict.category_field_label'.tr(),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Row(
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
            data: (categories) => Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    avatar: Icon(
                      _iconForGroup(category.groupKey),
                      size: 16,
                      color: scanState.selectedCategoryId == category.id
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    label: Text(category.localizedName(languageCode)),
                    selected: scanState.selectedCategoryId == category.id,
                    onSelected: (selected) {
                      if (selected) notifier.selectCategory(category.id);
                    },
                    selectedColor: AppColors.primarySoft,
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      color: scanState.selectedCategoryId == category.id
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: scanState.selectedCategoryId == category.id
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. Ubicación dinámica: Origen + Destino si es Taxi, o Ubicación única para el resto
          if (scanState.isTaxiCategory) ...[
            Text(
              'price_verdict.taxi_origin_label'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LocationSelectorRow(
              icon: Icons.my_location,
              label: '$cityName · $originZoneName',
              actionLabel: 'scan.change_zone_action'.tr(),
              onTap: zones.isEmpty
                  ? null
                  : () => _openOriginPicker(context, notifier, zones),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'price_verdict.taxi_destination_label'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LocationSelectorRow(
              icon: Icons.flag_outlined,
              label: destinationZoneName,
              isHighlighted: activeDestinationZone != null,
              hasError: scanState.destinationError,
              actionLabel: 'price_verdict.pick_point_on_map_btn'.tr(),
              onTap: zones.isEmpty
                  ? null
                  : () => _openDestinationPicker(context, notifier, zones),
            ),
            if (scanState.destinationError) ...[
              const SizedBox(height: 4),
              Text(
                'price_contribute.error_destination_required'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.semaphoreRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ] else ...[
            Text(
              'price_verdict.establishment_location_label'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LocationSelectorRow(
              icon: Icons.location_on_outlined,
              label: '$cityName · $originZoneName',
              actionLabel: 'scan.change_zone_action'.tr(),
              onTap: zones.isEmpty
                  ? null
                  : () => _openOriginPicker(context, notifier, zones),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // 3. Campo de monto observado en COP
          VjTextField(
            label: 'price_verdict.amount_field_label'.tr(),
            controller: amountController,
            keyboardType: TextInputType.number,
            onChanged: notifier.setRawAmount,
            errorText: scanState.amountError
                ? 'price_verdict.amount_error_invalid'.tr()
                : null,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 4. Botón principal de evaluar precio
          VjButton(
            label: 'price_verdict.evaluate_cta'.tr(),
            leadingIcon: Icons.analytics_outlined,
            onPressed:
                scanState.verdictAsync.isLoading ? null : onEvaluatePressed,
          ),
        ],
      ),
    );
  }
}

class _LocationSelectorRow extends StatelessWidget {
  const _LocationSelectorRow({
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onTap,
    this.isHighlighted = true,
    this.hasError = false,
  });

  final IconData icon;
  final String label;
  final String actionLabel;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasError
              ? AppColors.semaphoreRed
              : (isHighlighted ? AppColors.border : AppColors.primary),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: hasError ? AppColors.semaphoreRed : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                color: isHighlighted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
