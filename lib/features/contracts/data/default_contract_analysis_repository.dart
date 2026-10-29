import 'package:via_justa/features/contracts/data/demo_contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/data/supabase_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Implementación estándar de [ContractAnalysisRepository] para `VJ-14`.
///
/// Delega la llamada de transporte en un [ContractAnalysisGateway] abstracto y realiza
/// el parseo defensivo con [ContractAnalysisResult.fromMap].
/// Si la respuesta no cumple con el esquema estricto, lanza [ContractAnalysisException]
/// con código [ContractAnalysisError.aiResponseInvalid].
class DefaultContractAnalysisRepository implements ContractAnalysisRepository {
  DefaultContractAnalysisRepository({
    required this.gateway,
    ContractAnalysisRepository? demoFallback,
  }) : _demoFallback = demoFallback ?? const DemoContractAnalysisRepository();

  final ContractAnalysisGateway gateway;
  final ContractAnalysisRepository _demoFallback;

  @override
  Future<ContractAnalysis> getDemoSampleAnalysis() {
    return _demoFallback.getDemoSampleAnalysis();
  }

  @override
  Future<ContractAnalysisResult> analyzeContract({
    required String text,
    required String locale,
  }) async {
    final rawMap = await gateway.analyzeContractRaw(
      text: text,
      locale: locale,
    );

    try {
      final isDemo = rawMap['is_demo'] as bool? ?? (gateway is! SupabaseContractAnalysisGateway);
      return ContractAnalysisResult.fromMap(rawMap, isDemo: isDemo);
    } on FormatException catch (e) {
      throw ContractAnalysisException(
        ContractAnalysisError.aiResponseInvalid,
        e.message,
      );
    }
  }
}
