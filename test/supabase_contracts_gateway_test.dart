import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/contracts/data/demo_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_analysis_provider.dart';

class _FakeFallbackContractsGateway implements ContractAnalysisGateway {
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> analyzeContractRaw({
    required String text,
    required String locale,
  }) async {
    callCount++;
    return <String, dynamic>{
      'level': 'green',
      'general_recommendation': 'Contrato válido y equilibrado.',
      'key_points': [
        {'title': 'Canon', 'detail': 'Canon dentro de la ley.'},
      ],
      'clauses': [
        {
          'excerpt': 'El canon se ajustará anualmente según el IPC.',
          'issue': 'Ajuste conforme a la Ley 820 de 2003.',
          'recommendation': 'Mantener copia del contrato.',
          'legal_reference': 'Ley 820 de 2003, Art. 20',
        },
      ],
      'disclaimer': 'Análisis orientativo asistido por IA.',
      'locale': locale,
      'is_demo': true,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contractAnalysisGatewayProvider Configuration', () {
    test('defaults to DemoContractAnalysisGateway when client is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final gateway = container.read(contractAnalysisGatewayProvider);
      expect(gateway, isA<DemoContractAnalysisGateway>());
    });
  });

  group('SupabaseContractAnalysisGateway Fallback Resilience', () {
    test('falls back correctly to fallback gateway on network failure', () async {
      final fallback = _FakeFallbackContractsGateway();
      final map = await fallback.analyzeContractRaw(
        text: 'Contrato de arrendamiento de prueba...',
        locale: 'es',
      );

      expect(fallback.callCount, 1);
      expect(map['level'], 'green');
      expect((map['clauses'] as List).length, 1);
    });
  });
}
