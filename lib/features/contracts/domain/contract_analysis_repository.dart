import 'package:via_justa/features/contracts/domain/contract_analysis.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Contrato abstracto para obtener el análisis orientativo de un contrato.
///
/// En VJ-04 provee ejemplos DEMO estáticos; en VJ-14 procesa contratos extraídos
/// delegando la comunicación en un gateway y parseando el resultado estructurado.
abstract class ContractAnalysisRepository {
  /// Obtiene el caso de demostración inicial con cláusulas de ejemplo en español e inglés (VJ-04).
  Future<ContractAnalysis> getDemoSampleAnalysis();

  /// Analiza el [text] de un contrato en el idioma especificado por [locale] (`es` o `en`).
  ///
  /// Retorna un [ContractAnalysisResult] validado según §4.4 de `docs/contrato-datos-v1.md`.
  /// Lanza [ContractAnalysisException] si el gateway falla o si la respuesta no cumple el esquema.
  Future<ContractAnalysisResult> analyzeContract({
    required String text,
    required String locale,
  });
}
