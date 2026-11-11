import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Implementación de [ContractAnalysisGateway] que invoca la Edge Function
/// `analyze_contract` en Supabase con el modelo Gemini (VJ-14).
///
/// Cuando hay cliente de Supabase activo, cualquier error HTTP, de cuota o de red
/// se traduce a un [ContractAnalysisException] para mostrarse en la interfaz
/// con opción de reintento, sin caer silenciosamente en datos falsos.
class SupabaseContractAnalysisGateway implements ContractAnalysisGateway {
  const SupabaseContractAnalysisGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> analyzeContractRaw({
    required String text,
    required String locale,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'analyze_contract',
        body: {
          'contract_text': text,
          'locale': locale,
        },
      );

      final status = response.status;
      if (status == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        throw const ContractAnalysisException(
          ContractAnalysisError.aiResponseInvalid,
        );
      }

      if (status == 504) {
        throw const ContractAnalysisException(
          ContractAnalysisError.timeout,
        );
      }

      throw ContractAnalysisException(
        ContractAnalysisError.fromHttpStatusCode(status),
      );
    } on ContractAnalysisException {
      rethrow;
    } on FunctionException catch (e) {
      if (e.status == 504) {
        throw const ContractAnalysisException(
          ContractAnalysisError.timeout,
        );
      }
      throw ContractAnalysisException(
        ContractAnalysisError.fromHttpStatusCode(e.status),
      );
    } catch (_) {
      throw const ContractAnalysisException(
        ContractAnalysisError.networkUnavailable,
      );
    }
  }
}
