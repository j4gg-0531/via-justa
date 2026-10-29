import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/contracts/data/default_contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/data/demo_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';

/// Estados posibles del flujo de análisis de contratos en `VJ-14`.
enum ContractAnalysisStatus {
  /// Sin análisis solicitado aún o estado restablecido.
  idle,

  /// Análisis en curso mediante el gateway / Edge Function.
  analyzing,

  /// Análisis completado exitosamente con resultado estructurado disponible.
  result,

  /// Fallo durante el análisis (red, cuota, sesión, esquema o servidor).
  error,
}

/// Estado inmutable de la pantalla y widgets de análisis de contratos.
class ContractAnalysisState {
  const ContractAnalysisState({
    this.status = ContractAnalysisStatus.idle,
    this.result,
    this.error,
    this.errorMessage,
    this.hasGivenAiConsent = false,
    this.isAiConsentDialogVisible = false,
    this.pendingText,
    this.pendingLocale,
    this.lastAnalyzedText,
    this.lastAnalyzedLocale,
  });

  /// Estado de ciclo de vida actual.
  final ContractAnalysisStatus status;

  /// Resultado estructurado si [status] es [ContractAnalysisStatus.result].
  final ContractAnalysisResult? result;

  /// Error tipado si [status] es [ContractAnalysisStatus.error].
  final ContractAnalysisError? error;

  /// Mensaje adicional o detalle técnico para depuración.
  final String? errorMessage;

  /// Indica si el usuario ya otorgó el consentimiento de análisis con IA externa en la sesión actual.
  final bool hasGivenAiConsent;

  /// Indica si el diálogo de consentimiento de IA debe mostrarse en pantalla.
  final bool isAiConsentDialogVisible;

  /// Texto pendiente por analizar retenido mientras se resuelve el consentimiento.
  final String? pendingText;

  /// Idioma pendiente retenido mientras se resuelve el consentimiento.
  final String? pendingLocale;

  /// Último texto enviado a análisis para posibilitar reintentos seguros.
  final String? lastAnalyzedText;

  /// Último idioma enviado a análisis para posibilitar reintentos seguros.
  final String? lastAnalyzedLocale;

  /// Indica si la petición de análisis está en ejecución.
  bool get isAnalyzing => status == ContractAnalysisStatus.analyzing;

  /// Indica si se cuenta con un resultado válido listo para visualización.
  bool get hasResult => status == ContractAnalysisStatus.result && result != null;

  /// Indica si el análisis finalizó con error.
  bool get hasError => status == ContractAnalysisStatus.error;

  /// Indica si el error actual es transitorio y seguro de reintentar con el mismo texto.
  bool get canRetry =>
      hasError && (error?.isRetryable ?? false) && lastAnalyzedText != null;

  ContractAnalysisState copyWith({
    ContractAnalysisStatus? status,
    ContractAnalysisResult? result,
    ContractAnalysisError? error,
    String? errorMessage,
    bool? hasGivenAiConsent,
    bool? isAiConsentDialogVisible,
    String? pendingText,
    String? pendingLocale,
    String? lastAnalyzedText,
    String? lastAnalyzedLocale,
  }) {
    return ContractAnalysisState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
      errorMessage: errorMessage ?? this.errorMessage,
      hasGivenAiConsent: hasGivenAiConsent ?? this.hasGivenAiConsent,
      isAiConsentDialogVisible:
          isAiConsentDialogVisible ?? this.isAiConsentDialogVisible,
      pendingText: pendingText ?? this.pendingText,
      pendingLocale: pendingLocale ?? this.pendingLocale,
      lastAnalyzedText: lastAnalyzedText ?? this.lastAnalyzedText,
      lastAnalyzedLocale: lastAnalyzedLocale ?? this.lastAnalyzedLocale,
    );
  }
}

/// Orquestador del flujo de análisis de contratos con IA (`VJ-14`).
///
/// Responsabilidades:
/// 1. Gestiona el segundo consentimiento informado (salida del texto hacia IA de terceros).
/// 2. Bloquea peticiones duplicadas (doble toque) mientras [isAnalyzing] esté activo.
/// 3. Asigna un token secuencial (`_activeRequestId`) para descartar respuestas tardías u obsoletas.
/// 4. Se reinicia automáticamente cuando el documento es descartado en [contractCaptureProvider].
/// 5. Se reinicia al invocar [reset], por ejemplo desde `SessionController.signOut`.
class ContractAnalysisNotifier extends Notifier<ContractAnalysisState> {
  int _activeRequestId = 0;

  @override
  ContractAnalysisState build() {
    // Se suscribe reactivamente a contractCaptureProvider:
    // Si el documento se descarta o pasa a idle, se invalida y reinicia el análisis.
    ref.listen<ContractCaptureState>(
      contractCaptureProvider,
      (previous, next) {
        if (next.status == ContractCaptureStatus.idle &&
            previous?.status != ContractCaptureStatus.idle) {
          reset(clearConsent: false);
        }
      },
    );

    return const ContractAnalysisState();
  }

  /// Solicita el análisis con IA de [text] en [locale] (`es` o `en`).
  ///
  /// Si el usuario aún no ha otorgado el consentimiento de IA en la sesión,
  /// activa el diálogo [isAiConsentDialogVisible] y guarda los parámetros pendientes.
  void requestAnalysis({
    required String text,
    required String locale,
  }) {
    if (state.isAnalyzing) {
      return;
    }

    if (!state.hasGivenAiConsent) {
      state = state.copyWith(
        isAiConsentDialogVisible: true,
        pendingText: text,
        pendingLocale: locale,
      );
      return;
    }

    _executeAnalysis(text: text, locale: locale);
  }

  /// Confirma el consentimiento de IA y dispara el análisis pendiente.
  void confirmAiConsentAndProceed() {
    final text = state.pendingText;
    final locale = state.pendingLocale ?? 'es';

    state = state.copyWith(
      hasGivenAiConsent: true,
      isAiConsentDialogVisible: false,
      pendingText: null,
      pendingLocale: null,
    );

    if (text != null && text.isNotEmpty) {
      _executeAnalysis(text: text, locale: locale);
    }
  }

  /// Cancela el consentimiento de IA y descarta los parámetros pendientes.
  void cancelAiConsent() {
    state = state.copyWith(
      isAiConsentDialogVisible: false,
      pendingText: null,
      pendingLocale: null,
    );
  }

  /// Reintenta el último análisis solicitado si el error es seguro de reintentar.
  void retryAnalysis() {
    if (!state.canRetry) {
      return;
    }
    final text = state.lastAnalyzedText;
    final locale = state.lastAnalyzedLocale ?? 'es';
    if (text != null && text.isNotEmpty) {
      _executeAnalysis(text: text, locale: locale);
    }
  }

  /// Ejecuta directamente el análisis del [text] del contrato en el idioma [locale].
  ///
  /// Se mantiene para invocación programática directa y suites de pruebas unitarias.
  Future<void> analyzeContract({
    required String text,
    required String locale,
  }) async {
    await _executeAnalysis(text: text, locale: locale);
  }

  Future<void> _executeAnalysis({
    required String text,
    required String locale,
  }) async {
    if (state.isAnalyzing) {
      return;
    }

    final requestId = ++_activeRequestId;
    state = state.copyWith(
      status: ContractAnalysisStatus.analyzing,
      error: null,
      errorMessage: null,
      lastAnalyzedText: text,
      lastAnalyzedLocale: locale,
    );

    try {
      final repository = ref.read(contractAnalysisRepositoryProvider);
      final result = await repository.analyzeContract(
        text: text,
        locale: locale,
      );

      // Si la petición quedó obsoleta por un nuevo intento o cancelación, ignorar
      if (requestId != _activeRequestId) {
        return;
      }

      state = state.copyWith(
        status: ContractAnalysisStatus.result,
        result: result,
        error: null,
        errorMessage: null,
      );
    } on ContractAnalysisException catch (e) {
      if (requestId != _activeRequestId) {
        return;
      }
      state = state.copyWith(
        status: ContractAnalysisStatus.error,
        error: e.error,
        errorMessage: e.message,
      );
    } catch (e) {
      if (requestId != _activeRequestId) {
        return;
      }
      state = state.copyWith(
        status: ContractAnalysisStatus.error,
        error: ContractAnalysisError.aiServiceUnavailable,
      );
    }
  }

  /// Reinicia el estado a [ContractAnalysisStatus.idle] e invalida cualquier
  /// respuesta asíncrona pendiente.
  ///
  /// Si [clearConsent] es `true` (por ejemplo en cierre de sesión), revoca también
  /// el consentimiento de IA otorgado.
  void reset({bool clearConsent = false}) {
    _activeRequestId++;
    state = ContractAnalysisState(
      status: ContractAnalysisStatus.idle,
      hasGivenAiConsent: clearConsent ? false : state.hasGivenAiConsent,
    );
  }
}

/// Proveedor del gateway de transporte para análisis de contratos.
///
/// **Regla de arquitectura:** Solo los providers conocen la implementación concreta (`data/`).
final contractAnalysisGatewayProvider = Provider<ContractAnalysisGateway>((ref) {
  return const DemoContractAnalysisGateway();
});

/// Proveedor del repositorio de análisis de contratos.
final contractAnalysisRepositoryProvider = Provider<ContractAnalysisRepository>((ref) {
  final gateway = ref.watch(contractAnalysisGatewayProvider);
  return DefaultContractAnalysisRepository(gateway: gateway);
});

/// Proveedor de estado del análisis de contratos (`ContractAnalysisNotifier`).
final contractAnalysisProvider =
    NotifierProvider<ContractAnalysisNotifier, ContractAnalysisState>(
  ContractAnalysisNotifier.new,
);
