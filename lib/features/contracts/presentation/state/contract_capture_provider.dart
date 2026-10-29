import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/contracts/data/device_contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/domain/contract_ocr_repository.dart';

/// Proveedor del repositorio de captura y OCR local de contratos (`VJ-13`).
/// Único punto de la aplicación que referencia la implementación concreta:
/// cámara, selector de archivos y ML Kit reales, con contratos sintéticos para pruebas.
final contractOcrRepositoryProvider = Provider<ContractOcrRepository>((ref) {
  return DeviceContractOcrRepository();
});

/// Catálogo de contratos sintéticos de prueba (ES/EN) sin datos personales reales.
final syntheticContractSamplesProvider = Provider<List<SyntheticContractSample>>(
  (ref) {
    return ref.watch(contractOcrRepositoryProvider).getSyntheticSamples();
  },
);

/// Estado inmutable del flujo de captura, validación y edición local de contratos (`VJ-13`).
/// El flujo termina en [ContractCaptureStatus.readyForAnalysis].
class ContractCaptureState {
  const ContractCaptureState({
    required this.status,
    required this.text,
    this.source,
    this.selectedSampleId,
    this.fileName,
    this.fileSizeBytes,
    this.error,
    this.lastTempFilePath,
    this.wasTempFileDeleted = false,
    this.pendingConsentSource,
    this.hasGivenConsent = false,
  });

  const ContractCaptureState.initial()
      : status = ContractCaptureStatus.idle,
        text = '',
        source = null,
        selectedSampleId = null,
        fileName = null,
        fileSizeBytes = null,
        error = null,
        lastTempFilePath = null,
        wasTempFileDeleted = false,
        pendingConsentSource = null,
        hasGivenConsent = false;

  final ContractCaptureStatus status;
  final String text;
  final ContractInputSource? source;
  final String? selectedSampleId;
  final String? fileName;
  final int? fileSizeBytes;
  final ContractCaptureError? error;
  final String? lastTempFilePath;
  final bool wasTempFileDeleted;

  /// Origen de captura que espera confirmación de consentimiento propio (`RN-10`).
  final ContractInputSource? pendingConsentSource;

  /// Indica si el usuario ya otorgó el consentimiento de procesamiento local en la sesión.
  final bool hasGivenConsent;

  /// Indica si el diálogo de consentimiento local debe desplegarse en pantalla.
  bool get isConsentDialogVisible => pendingConsentSource != null;

  /// Cantidad actual de caracteres del texto en memoria.
  int get characterCount => text.length;

  /// Límite máximo de caracteres permitido sin truncamiento silencioso (`15.000`).
  int get maxCharacters => maxContractCharacters;

  /// Indica si el texto supera el límite de 15.000 caracteres y exige recorte manual.
  bool get isOverCharacterLimit => characterCount > maxContractCharacters;

  /// Cantidad de caracteres por encima del tope de 15.000 (0 si está dentro del límite).
  int get excessCharacters => isOverCharacterLimit
      ? characterCount - maxContractCharacters
      : 0;

  /// Indica si el editor de texto debe mostrarse en pantalla.
  bool get showTextEditor =>
      source != null ||
      text.isNotEmpty ||
      status == ContractCaptureStatus.readyForAnalysis ||
      error == ContractCaptureError.exceedsMaxLength;

  /// Indica si el contrato está validado y listo para el futuro análisis en `VJ-14`.
  bool get isReadyForAnalysis =>
      status == ContractCaptureStatus.readyForAnalysis &&
      error == null &&
      !isOverCharacterLimit &&
      characterCount >= minContractCharacters;
}

/// Controlador de estado para captura de contratos, OCR local y cumplimiento de `RN-10`.
class ContractCaptureNotifier extends Notifier<ContractCaptureState> {
  @override
  ContractCaptureState build() => const ContractCaptureState.initial();

  /// Solicita captura por cámara. El provider decide si debe presentarse el diálogo de
  /// consentimiento propio (`RN-10`) antes de invocar la cámara del sistema.
  Future<void> requestCameraCapture({required String languageCode}) async {
    if (!state.hasGivenConsent) {
      state = ContractCaptureState(
        status: state.status,
        text: state.text,
        source: state.source,
        selectedSampleId: state.selectedSampleId,
        fileName: state.fileName,
        fileSizeBytes: state.fileSizeBytes,
        error: state.error,
        lastTempFilePath: state.lastTempFilePath,
        wasTempFileDeleted: state.wasTempFileDeleted,
        pendingConsentSource: ContractInputSource.cameraPhoto,
        hasGivenConsent: state.hasGivenConsent,
      );
      return;
    }
    await captureFromCamera(languageCode: languageCode);
  }

  /// Solicita selección de archivo. El provider decide si debe presentarse el diálogo de
  /// consentimiento propio (`RN-10`) antes de abrir el selector del sistema.
  Future<void> requestFilePicker({required String languageCode}) async {
    if (!state.hasGivenConsent) {
      state = ContractCaptureState(
        status: state.status,
        text: state.text,
        source: state.source,
        selectedSampleId: state.selectedSampleId,
        fileName: state.fileName,
        fileSizeBytes: state.fileSizeBytes,
        error: state.error,
        lastTempFilePath: state.lastTempFilePath,
        wasTempFileDeleted: state.wasTempFileDeleted,
        pendingConsentSource: ContractInputSource.documentFile,
        hasGivenConsent: state.hasGivenConsent,
      );
      return;
    }
    await pickDocumentFile(languageCode: languageCode);
  }

  /// Cancela el diálogo de consentimiento sin abrir la cámara ni el selector de archivos.
  void cancelConsent() {
    state = ContractCaptureState(
      status: state.status,
      text: state.text,
      source: state.source,
      selectedSampleId: state.selectedSampleId,
      fileName: state.fileName,
      fileSizeBytes: state.fileSizeBytes,
      error: state.error,
      lastTempFilePath: state.lastTempFilePath,
      wasTempFileDeleted: state.wasTempFileDeleted,
      pendingConsentSource: null,
      hasGivenConsent: state.hasGivenConsent,
    );
  }

  /// Confirma el consentimiento de procesamiento local (`RN-10`) y ejecuta de inmediato
  /// la acción solicitada (cámara o selector de archivos).
  Future<void> confirmConsentAndProceed({required String languageCode}) async {
    final pendingSource = state.pendingConsentSource;
    state = ContractCaptureState(
      status: state.status,
      text: state.text,
      source: state.source,
      selectedSampleId: state.selectedSampleId,
      fileName: state.fileName,
      fileSizeBytes: state.fileSizeBytes,
      error: state.error,
      lastTempFilePath: state.lastTempFilePath,
      wasTempFileDeleted: state.wasTempFileDeleted,
      pendingConsentSource: null,
      hasGivenConsent: true,
    );

    if (pendingSource == ContractInputSource.cameraPhoto) {
      await captureFromCamera(languageCode: languageCode);
    } else if (pendingSource == ContractInputSource.documentFile) {
      await pickDocumentFile(languageCode: languageCode);
    }
  }

  /// Captura una foto de contrato desde la cámara, valida formato/tamaño/texto
  /// y elimina el archivo temporal del caché (`RN-10`).
  Future<void> captureFromCamera({required String languageCode}) async {
    final repo = ref.read(contractOcrRepositoryProvider);
    state = ContractCaptureState(
      status: ContractCaptureStatus.readingDocument,
      text: state.text,
      source: state.source,
      selectedSampleId: state.selectedSampleId,
      fileName: state.fileName,
      fileSizeBytes: state.fileSizeBytes,
      lastTempFilePath: state.lastTempFilePath,
      wasTempFileDeleted: state.wasTempFileDeleted,
      hasGivenConsent: state.hasGivenConsent,
    );

    try {
      final result = await repo.captureFromCamera(languageCode: languageCode);
      if (result == null) {
        state = state.text.isEmpty
            ? ContractCaptureState(
                status: ContractCaptureStatus.idle,
                text: '',
                hasGivenConsent: state.hasGivenConsent,
              )
            : ContractCaptureState(
                status: validateContractText(state.text) == null
                    ? ContractCaptureStatus.readyForAnalysis
                    : ContractCaptureStatus.error,
                text: state.text,
                source: state.source,
                selectedSampleId: state.selectedSampleId,
                fileName: state.fileName,
                fileSizeBytes: state.fileSizeBytes,
                error: validateContractText(state.text),
                lastTempFilePath: state.lastTempFilePath,
                wasTempFileDeleted: state.wasTempFileDeleted,
                hasGivenConsent: state.hasGivenConsent,
              );
        return;
      }
      await _applyCaptureResult(result, repo);
    } catch (_) {
      state = ContractCaptureState(
        status: ContractCaptureStatus.error,
        text: '',
        error: ContractCaptureError.readFailed,
        hasGivenConsent: state.hasGivenConsent,
      );
    }
  }

  /// Selecciona un archivo (`JPG`, `PNG`, `TXT`), valida formato/tamaño/texto
  /// y elimina el archivo temporal del caché (`RN-10`).
  Future<void> pickDocumentFile({required String languageCode}) async {
    final repo = ref.read(contractOcrRepositoryProvider);
    state = ContractCaptureState(
      status: ContractCaptureStatus.readingDocument,
      text: state.text,
      source: state.source,
      selectedSampleId: state.selectedSampleId,
      fileName: state.fileName,
      fileSizeBytes: state.fileSizeBytes,
      lastTempFilePath: state.lastTempFilePath,
      wasTempFileDeleted: state.wasTempFileDeleted,
      hasGivenConsent: state.hasGivenConsent,
    );

    try {
      final result = await repo.pickDocumentFile(languageCode: languageCode);
      if (result == null) {
        state = state.text.isEmpty
            ? ContractCaptureState(
                status: ContractCaptureStatus.idle,
                text: '',
                hasGivenConsent: state.hasGivenConsent,
              )
            : ContractCaptureState(
                status: validateContractText(state.text) == null
                    ? ContractCaptureStatus.readyForAnalysis
                    : ContractCaptureStatus.error,
                text: state.text,
                source: state.source,
                selectedSampleId: state.selectedSampleId,
                fileName: state.fileName,
                fileSizeBytes: state.fileSizeBytes,
                error: validateContractText(state.text),
                lastTempFilePath: state.lastTempFilePath,
                wasTempFileDeleted: state.wasTempFileDeleted,
                hasGivenConsent: state.hasGivenConsent,
              );
        return;
      }
      await _applyCaptureResult(result, repo);
    } catch (_) {
      state = ContractCaptureState(
        status: ContractCaptureStatus.error,
        text: '',
        error: ContractCaptureError.readFailed,
        hasGivenConsent: state.hasGivenConsent,
      );
    }
  }

  /// Carga un contrato sintético de prueba (ES/EN) detrás de [ContractOcrRepository].
  Future<void> loadSyntheticSample(
    String sampleId, {
    required String languageCode,
  }) async {
    final repo = ref.read(contractOcrRepositoryProvider);
    state = ContractCaptureState(
      status: ContractCaptureStatus.readingDocument,
      text: state.text,
      source: ContractInputSource.syntheticSample,
      selectedSampleId: sampleId,
      hasGivenConsent: state.hasGivenConsent,
    );

    try {
      final result = await repo.loadSyntheticSample(
        sampleId: sampleId,
        languageCode: languageCode,
      );
      await _applyCaptureResult(
        result,
        repo,
        selectedSampleId: sampleId,
      );
    } catch (_) {
      state = ContractCaptureState(
        status: ContractCaptureStatus.error,
        text: '',
        error: ContractCaptureError.readFailed,
        hasGivenConsent: state.hasGivenConsent,
      );
    }
  }

  /// Muestra el aviso de que el soporte de archivos PDF está marcado como "Próximamente".
  void notifyPdfComingSoon() {
    state = ContractCaptureState(
      status: ContractCaptureStatus.error,
      text: state.text,
      source: state.source,
      selectedSampleId: state.selectedSampleId,
      fileName: 'documento.pdf',
      fileSizeBytes: state.fileSizeBytes,
      error: ContractCaptureError.pdfComingSoon,
      lastTempFilePath: state.lastTempFilePath,
      wasTempFileDeleted: state.wasTempFileDeleted,
      hasGivenConsent: state.hasGivenConsent,
    );
  }

  /// Habilita la edición manual para pegar o redactar un contrato directamente.
  void startManualEntry() {
    if (state.text.isNotEmpty) {
      final textError = validateContractText(state.text);
      state = ContractCaptureState(
        status: textError == null
            ? ContractCaptureStatus.readyForAnalysis
            : ContractCaptureStatus.error,
        text: state.text,
        source: ContractInputSource.manualEntry,
        error: textError,
        wasTempFileDeleted: true,
        hasGivenConsent: state.hasGivenConsent,
      );
      return;
    }
    state = ContractCaptureState(
      status: ContractCaptureStatus.error,
      text: '',
      source: ContractInputSource.manualEntry,
      error: ContractCaptureError.emptyOrIllegibleText,
      wasTempFileDeleted: true,
      hasGivenConsent: state.hasGivenConsent,
    );
  }

  /// Actualiza el texto editable a mano **sin truncar en silencio**.
  /// Si supera los 15.000 caracteres, advierte con [ContractCaptureError.exceedsMaxLength]
  /// y exige que el usuario lo recorte antes de quedar en `readyForAnalysis`.
  void updateContractText(String updatedText) {
    final textError = validateContractText(updatedText);
    state = ContractCaptureState(
      status: textError == null
          ? ContractCaptureStatus.readyForAnalysis
          : ContractCaptureStatus.error,
      text: updatedText,
      source: state.source ?? ContractInputSource.manualEntry,
      selectedSampleId: state.selectedSampleId,
      fileName: state.fileName,
      fileSizeBytes: state.fileSizeBytes,
      error: textError,
      lastTempFilePath: state.lastTempFilePath,
      wasTempFileDeleted: state.wasTempFileDeleted,
      hasGivenConsent: state.hasGivenConsent,
    );
  }

  /// Descarta el documento actual, borra cualquier archivo temporal remanente del caché (`RN-10`)
  /// y limpia el texto de la memoria.
  Future<void> discardDocument() async {
    final repo = ref.read(contractOcrRepositoryProvider);
    final tempPath = state.lastTempFilePath;
    if (tempPath != null && tempPath.isNotEmpty) {
      await repo.deleteTemporaryFileIfPresent(tempPath);
    }
    state = ContractCaptureState(
      status: ContractCaptureStatus.idle,
      text: '',
      hasGivenConsent: state.hasGivenConsent,
    );
  }

  Future<void> _applyCaptureResult(
    ContractDocumentCaptureResult result,
    ContractOcrRepository repo, {
    String? selectedSampleId,
  }) async {
    // RN-10: Garantizar el borrado inmediato del archivo temporal en caché tras el OCR.
    final deleted = await repo.deleteTemporaryFileIfPresent(result.tempFilePath);
    final tempDeleted = result.wasTempFileDeleted || deleted;

    // 1. Validar formato (solo JPG, JPEG, PNG y TXT; PDF devuelve pdfComingSoon).
    final extError = validateContractFileExtension(result.fileName);
    if (extError != null) {
      state = ContractCaptureState(
        status: ContractCaptureStatus.error,
        text: '',
        source: result.source,
        selectedSampleId: selectedSampleId,
        fileName: result.fileName,
        fileSizeBytes: result.fileSizeBytes,
        error: extError,
        lastTempFilePath: result.tempFilePath,
        wasTempFileDeleted: tempDeleted,
        hasGivenConsent: state.hasGivenConsent,
      );
      return;
    }

    // 2. Validar tamaño (máximo 10 MB).
    final sizeError = validateContractFileSize(result.fileSizeBytes);
    if (sizeError != null) {
      state = ContractCaptureState(
        status: ContractCaptureStatus.error,
        text: '',
        source: result.source,
        selectedSampleId: selectedSampleId,
        fileName: result.fileName,
        fileSizeBytes: result.fileSizeBytes,
        error: sizeError,
        lastTempFilePath: result.tempFilePath,
        wasTempFileDeleted: tempDeleted,
        hasGivenConsent: state.hasGivenConsent,
      );
      return;
    }

    // 3. Normalizar saltos de línea sin truncar jamás el contenido.
    final normalizedText = normalizeExtractedContractText(result.extractedText);
    final textError = validateContractText(normalizedText);

    state = ContractCaptureState(
      status: textError == null
          ? ContractCaptureStatus.readyForAnalysis
          : ContractCaptureStatus.error,
      text: normalizedText,
      source: result.source,
      selectedSampleId: selectedSampleId,
      fileName: result.fileName,
      fileSizeBytes: result.fileSizeBytes,
      error: textError,
      lastTempFilePath: result.tempFilePath,
      wasTempFileDeleted: tempDeleted,
      hasGivenConsent: state.hasGivenConsent,
    );
  }
}

final contractCaptureProvider =
    NotifierProvider<ContractCaptureNotifier, ContractCaptureState>(
      ContractCaptureNotifier.new,
    );
