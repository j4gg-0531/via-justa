import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/contracts/data/demo_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/data/supabase_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_analysis_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contractAnalysisGatewayProvider Configuration (Paso 1)', () {
    test('defaults to DemoContractAnalysisGateway when client is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final gateway = container.read(contractAnalysisGatewayProvider);
      expect(gateway, isA<DemoContractAnalysisGateway>());
    });

    test('uses SupabaseContractAnalysisGateway when client is provided', () {
      final dummyClient = SupabaseClient('http://127.0.0.1:59999', 'fake-anon-key');
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(dummyClient),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(contractAnalysisGatewayProvider);
      expect(gateway, isA<SupabaseContractAnalysisGateway>());
    });
  });

  group('SupabaseContractAnalysisGateway No Silent Fallback (Paso 1)', () {
    test('throws ContractAnalysisException on network failure instead of returning demo data', () async {
      final unreachableClient = SupabaseClient(
        'http://127.0.0.1:59999',
        'fake-anon-key',
      );
      final gateway = SupabaseContractAnalysisGateway(unreachableClient);

      await expectLater(
        gateway.analyzeContractRaw(
          text: 'Contrato de arrendamiento de vivienda urbana...',
          locale: 'es',
        ),
        throwsA(isA<ContractAnalysisException>()),
      );
    });
  });
}
