import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/contracts/data/demo_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Implementación de [ContractAnalysisGateway] que invoca la Edge Function
/// `analyze_contract` en Supabase con el modelo Gemini (VJ-14).
///
/// Dispone de un [fallback] hacia [DemoContractAnalysisGateway] ante errores
/// de red o cuando la aplicación se ejecuta sin backend configurado.
class SupabaseContractAnalysisGateway implements ContractAnalysisGateway {
  SupabaseContractAnalysisGateway(
    this._client, {
    ContractAnalysisGateway? fallback,
  }) : _fallback = fallback ?? const DemoContractAnalysisGateway();

  final SupabaseClient _client;
  final ContractAnalysisGateway _fallback;

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

      if (status == 429) {
        throw const ContractAnalysisException(
          ContractAnalysisError.aiDailyLimitExceeded,
        );
      }
      if (status == 401 || status == 403) {
        throw const ContractAnalysisException(
          ContractAnalysisError.authUnauthorized,
        );
      }
      if (status == 413) {
        throw const ContractAnalysisException(
          ContractAnalysisError.textTooLong,
        );
      }
      if (status == 400) {
        throw const ContractAnalysisException(
          ContractAnalysisError.invalidInputEmpty,
        );
      }
      if (status == 504) {
        throw const ContractAnalysisException(
          ContractAnalysisError.timeout,
        );
      }
      if (status >= 500) {
        throw const ContractAnalysisException(
          ContractAnalysisError.aiServiceUnavailable,
        );
      }

      return await _fallback.analyzeContractRaw(text: text, locale: locale);
    } on ContractAnalysisException {
      rethrow;
    } on FunctionException catch (e) {
      if (e.status == 429) {
        throw const ContractAnalysisException(
          ContractAnalysisError.aiDailyLimitExceeded,
        );
      }
      if (e.status == 401 || e.status == 403) {
        throw const ContractAnalysisException(
          ContractAnalysisError.authUnauthorized,
        );
      }
      return await _fallback.analyzeContractRaw(text: text, locale: locale);
    } catch (_) {
      return await _fallback.analyzeContractRaw(text: text, locale: locale);
    }
  }
}
