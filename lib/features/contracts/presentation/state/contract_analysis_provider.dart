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
  });

  /// Estado de ciclo de vida actual.
  final ContractAnalysisStatus status;

  /// Resultado estructurado si [status] es [ContractAnalysisStatus.result].
  final ContractAnalysisResult? result;

  /// Error tipado si [status] es [ContractAnalysisStatus.error].
  final ContractAnalysisError? error;

  /// Mensaje adicional o detalle técnico para depuración.
  final String? errorMessage;

  /// Indica si la petición de análisis está en ejecución.
  bool get isAnalyzing => status == ContractAnalysisStatus.analyzing;

  /// Indica si se cuenta con un resultado válido listo para visualización.
  bool get hasResult => status == ContractAnalysisStatus.result && result != null;

  /// Indica si el análisis finalizó con error.
  bool get hasError => status == ContractAnalysisStatus.error;

  ContractAnalysisState copyWith({
    ContractAnalysisStatus? status,
    ContractAnalysisResult? result,
    ContractAnalysisError? error,
    String? errorMessage,
  }) {
    return ContractAnalysisState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Orquestador del flujo de análisis de contratos con IA (`VJ-14`).
///
/// Responsabilidades:
/// 1. Bloquea peticiones duplicadas (doble toque) mientras [isAnalyzing] esté activo.
/// 2. Asigna un token secuencial (`_activeRequestId`) para descartar respuestas tardías u obsoletas.
/// 3. Se reinicia automáticamente cuando el documento es descartado en [contractCaptureProvider].
/// 4. Se reinicia al invocar [reset], por ejemplo desde `SessionController.signOut`.
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
          reset();
        }
      },
    );

    return const ContractAnalysisState();
  }

  /// Ejecuta el análisis del [text] del contrato en el idioma [locale] (`es` o `en`).
  ///
  /// Si ya se encuentra analizando, descarta silenciosamente la llamada para prevenir doble toque.
  /// Cualquier respuesta completada tras un nuevo request o tras invocar [reset] es ignorada.
  Future<void> analyzeContract({
    required String text,
    required String locale,
  }) async {
    if (state.isAnalyzing) {
      return;
    }

    final requestId = ++_activeRequestId;
    state = const ContractAnalysisState(status: ContractAnalysisStatus.analyzing);

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

      state = ContractAnalysisState(
        status: ContractAnalysisStatus.result,
        result: result,
      );
    } on ContractAnalysisException catch (e) {
      if (requestId != _activeRequestId) {
        return;
      }
      state = ContractAnalysisState(
        status: ContractAnalysisStatus.error,
        error: e.error,
        errorMessage: e.message,
      );
    } catch (e) {
      if (requestId != _activeRequestId) {
        return;
      }
      state = const ContractAnalysisState(
        status: ContractAnalysisStatus.error,
        error: ContractAnalysisError.aiServiceUnavailable,
      );
    }
  }

  /// Reinicia el estado a [ContractAnalysisStatus.idle] e invalida cualquier
  /// respuesta asíncrona pendiente.
  void reset() {
    _activeRequestId++;
    state = const ContractAnalysisState(status: ContractAnalysisStatus.idle);
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
