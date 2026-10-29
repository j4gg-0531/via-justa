/// Gateway abstracto para comunicarse con el servicio de análisis de contratos (§4.4 de `docs/contrato-datos-v1.md`).
///
/// Recibe el texto extraído del contrato y el código de idioma (`es` | `en`),
/// y retorna el mapa JSON crudo devuelto por el servicio o lanza un [ContractAnalysisException].
///
/// **Regla de arquitectura:** Esta interfaz es Dart puro en `domain/`.
/// Solo los providers en `presentation/state/` conocen la implementación concreta (`data/`).
abstract class ContractAnalysisGateway {
  /// Envía el texto para análisis y retorna el JSON crudo del servicio.
  ///
  /// Lanza [ContractAnalysisException] ante fallos tipados de red, cuota, sesión, timeout o indisponibilidad.
  Future<Map<String, dynamic>> analyzeContractRaw({
    required String text,
    required String locale,
  });
}
