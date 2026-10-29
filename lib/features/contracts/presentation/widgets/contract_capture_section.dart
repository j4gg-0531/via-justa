import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';

/// Sección interactiva de captura de contratos, OCR local, contratos sintéticos (ES/EN)
/// y edición manual de texto (`VJ-13` — Paso A).
///
/// El flujo termina en `ContractCaptureStatus.readyForAnalysis` con el botón de análisis
/// deshabilitado y rotulado como `Próximamente (VJ-14)`.
class ContractCaptureSection extends ConsumerStatefulWidget {
  const ContractCaptureSection({super.key});

  @override
  ConsumerState<ContractCaptureSection> createState() =>
      _ContractCaptureSectionState();
}

class _ContractCaptureSectionState
    extends ConsumerState<ContractCaptureSection> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final initialText = ref.read(contractCaptureProvider).text;
    _textController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _resolveErrorMessage(ContractCaptureState state) {
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
    final captureState = ref.watch(contractCaptureProvider);
    final samples = ref.watch(syntheticContractSamplesProvider);
    final notifier = ref.read(contractCaptureProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    if (_textController.text != captureState.text) {
      _textController.value = TextEditingValue(
        text: captureState.text,
        selection: TextSelection.collapsed(offset: captureState.text.length),
      );
    }

    String languageCode;
    try {
      languageCode = context.locale.languageCode;
    } catch (_) {
      languageCode =
          Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Aviso de privacidad RN-10 (no retención de archivos temporales ni texto)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'contract_capture.rn10_privacy_banner'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 2. Tarjeta de captura: Cámara, Archivo (JPG/PNG/TXT), PDF (Próximamente) y Entrada manual
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
                    'contract_capture.title'.tr(),
                    style: textTheme.titleMedium,
                  ),
                  VjBadge(label: 'contract_capture.formats_badge'.tr()),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'contract_capture.subtitle'.tr(),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),

              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: captureState.status ==
                            ContractCaptureStatus.readingDocument
                        ? null
                        : () => notifier.captureFromCamera(
                              languageCode: languageCode,
                            ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text('contract_capture.action_camera'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: captureState.status ==
                            ContractCaptureStatus.readingDocument
                        ? null
                        : () => notifier.pickDocumentFile(
                              languageCode: languageCode,
                            ),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: Text('contract_capture.action_file'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: notifier.startManualEntry,
                    icon: const Icon(Icons.edit_note_outlined, size: 18),
                    label: Text('contract_capture.action_manual'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: notifier.notifyPdfComingSoon,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text('contract_capture.pdf_coming_soon_chip'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 3. Selector de contratos sintéticos de prueba (ES/EN)
        VjCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'contract_capture.samples_title'.tr(),
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'contract_capture.samples_subtitle'.tr(),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final sample in samples)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _SyntheticSampleTile(
                    sample: sample,
                    languageCode: languageCode,
                    selected: captureState.selectedSampleId == sample.id,
                    onTap: () => notifier.loadSyntheticSample(
                      sample.id,
                      languageCode: languageCode,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 4. Estado de lectura / Error / Editor de texto y botón Analizar (deshabilitado VJ-14)
        if (captureState.status == ContractCaptureStatus.readingDocument) ...[
          const SizedBox(height: AppSpacing.lg),
          VjCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.primary,
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

        if (captureState.error != null) ...[
          const SizedBox(height: AppSpacing.lg),
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
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _resolveErrorMessage(captureState),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (captureState.showTextEditor) ...[
          const SizedBox(height: AppSpacing.lg),
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
                      style: textTheme.titleMedium,
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
                  controller: _textController,
                  minLines: 5,
                  maxLines: 10,
                  onChanged: notifier.updateContractText,
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
                  spacing: AppSpacing.md,
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
                        fontWeight: captureState.isOverCharacterLimit
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: notifier.discardDocument,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('contract_capture.discard_cta'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // En VJ-13 el flujo termina en readyForAnalysis; el botón Analizar queda deshabilitado para VJ-14.
                VjButton(
                  label: 'contract_capture.analyze_disabled_cta'.tr(),
                  leadingIcon: Icons.auto_awesome_outlined,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SyntheticSampleTile extends StatelessWidget {
  const _SyntheticSampleTile({
    required this.sample,
    required this.languageCode,
    required this.selected,
    required this.onTap,
  });

  final SyntheticContractSample sample;
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
                  selected
                      ? Icons.check_circle
                      : Icons.description_outlined,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sample.localizedTitle(languageCode),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sample.localizedDescription(languageCode),
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
