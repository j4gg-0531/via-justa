import 'package:via_justa/features/contracts/domain/contract_analysis.dart';

/// Contrato abstracto para obtener el análisis orientativo de un contrato.
/// En VJ-04 provee ejemplos DEMO; en VJ-14 se conectará a la Edge Function `analyze_contract` en Supabase.
abstract class ContractAnalysisRepository {
  /// Obtiene el caso de demostración con cláusulas de ejemplo en español e inglés.
  Future<ContractAnalysis> getDemoSampleAnalysis();
}
