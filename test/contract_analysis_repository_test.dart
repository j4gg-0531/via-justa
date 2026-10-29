import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/contracts/data/default_contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/data/demo_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_analysis_provider.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';

class _FakeContractAnalysisGateway implements ContractAnalysisGateway {
  _FakeContractAnalysisGateway({
    this.nextResponse,
    this.nextException,
    this.completer,
  });

  Map<String, dynamic>? nextResponse;
  ContractAnalysisException? nextException;
  Completer<Map<String, dynamic>>? completer;
  int callCount = 0;
  final List<String> requestedTexts = <String>[];
  final List<String> requestedLocales = <String>[];

  @override
  Future<Map<String, dynamic>> analyzeContractRaw({
    required String text,
    required String locale,
  }) async {
    callCount++;
    requestedTexts.add(text);
    requestedLocales.add(locale);

    if (completer != null) {
      return completer!.future;
    }

    if (nextException != null) {
      throw nextException!;
    }

    return nextResponse ??
        <String, dynamic>{
          'level': 'green',
          'general_recommendation': 'Contrato válido y equilibrado.',
          'key_points': <Map<String, dynamic>>[
            {'title': 'Canon', 'detail': r'$1.000.000 COP'},
          ],
          'clauses': <Map<String, dynamic>>[
            {
              'excerpt': 'Uso exclusivo residencial.',
              'issue': 'Cláusula habitual.',
              'recommendation': 'Mantener como está pactado.',
              'legal_reference': null,
            },
          ],
          'disclaimer': 'Análisis orientativo de IA.',
          'locale': locale,
        };
  }
}

void main() {
  group('DefaultContractAnalysisRepository', () {
    test('calls gateway, parses valid JSON into ContractAnalysisResult and preserves demo analysis', () async {
      final fakeGateway = _FakeContractAnalysisGateway();
      final repository = DefaultContractAnalysisRepository(gateway: fakeGateway);

      final result = await repository.analyzeContract(
        text: 'Cláusula primera...',
        locale: 'es',
      );

      expect(fakeGateway.callCount, 1);
      expect(fakeGateway.requestedTexts, <String>['Cláusula primera...']);
      expect(fakeGateway.requestedLocales, <String>['es']);
      expect(result.level, ContractAnalysisLevel.green);
      expect(result.generalRecommendation, 'Contrato válido y equilibrado.');
      expect(result.keyPoints.length, 1);

      // Mantiene getDemoSampleAnalysis()
      final demo = await repository.getDemoSampleAnalysis();
      expect(demo.id, 'demo-lease-valledupar-01');
      expect(demo.points.length, 2);
    });

    test('rethrows ContractAnalysisException from gateway without wrapping', () async {
      final fakeGateway = _FakeContractAnalysisGateway(
        nextException: const ContractAnalysisException(
          ContractAnalysisError.aiDailyLimitExceeded,
          'Cuota diaria agotada',
        ),
      );
      final repository = DefaultContractAnalysisRepository(gateway: fakeGateway);

      await expectLater(
        repository.analyzeContract(text: 'Texto', locale: 'es'),
        throwsA(
          isA<ContractAnalysisException>().having(
            (e) => e.error,
            'error',
            ContractAnalysisError.aiDailyLimitExceeded,
          ),
        ),
      );
    });

    test('converts FormatException from malformed gateway response into aiResponseInvalid', () async {
      final fakeGateway = _FakeContractAnalysisGateway(
        nextResponse: <String, dynamic>{
          'level': 'unknown_color',
          'general_recommendation': '',
        },
      );
      final repository = DefaultContractAnalysisRepository(gateway: fakeGateway);

      await expectLater(
        repository.analyzeContract(text: 'Texto', locale: 'es'),
        throwsA(
          isA<ContractAnalysisException>().having(
            (e) => e.error,
            'error',
            ContractAnalysisError.aiResponseInvalid,
          ),
        ),
      );
    });
  });

  group('DemoContractAnalysisGateway', () {
    test('returns green, yellow and red scenarios with [DEMO] markings', () async {
      const greenGateway = DemoContractAnalysisGateway(
        scenario: DemoContractAnalysisScenario.successGreen,
      );
      final greenMap = await greenGateway.analyzeContractRaw(text: 'c', locale: 'es');
      expect(greenMap['level'], 'green');
      expect(greenMap['general_recommendation'], contains('[DEMO]'));

      const yellowGateway = DemoContractAnalysisGateway(
        scenario: DemoContractAnalysisScenario.successYellow,
      );
      final yellowMap = await yellowGateway.analyzeContractRaw(text: 'c', locale: 'en');
      expect(yellowMap['level'], 'yellow');
      expect(yellowMap['locale'], 'en');
      expect(yellowMap['general_recommendation'], contains('[DEMO]'));

      const redGateway = DemoContractAnalysisGateway(
        scenario: DemoContractAnalysisScenario.successRed,
      );
      final redMap = await redGateway.analyzeContractRaw(text: 'c', locale: 'es');
      expect(redMap['level'], 'red');
      expect(redMap['general_recommendation'], contains('[DEMO]'));
    });

    test('throws typed ContractAnalysisException for all error scenarios', () async {
      for (final scenario in [
        DemoContractAnalysisScenario.errorAuthUnauthorized,
        DemoContractAnalysisScenario.errorInvalidInputEmpty,
        DemoContractAnalysisScenario.errorTextTooLong,
        DemoContractAnalysisScenario.errorAiDailyLimitExceeded,
        DemoContractAnalysisScenario.errorAiServiceUnavailable,
        DemoContractAnalysisScenario.errorNetworkUnavailable,
        DemoContractAnalysisScenario.errorTimeout,
      ]) {
        final gateway = DemoContractAnalysisGateway(scenario: scenario);
        await expectLater(
          gateway.analyzeContractRaw(text: 'c', locale: 'es'),
          throwsA(isA<ContractAnalysisException>()),
        );
      }

      // errorAiResponseInvalid returns a malformed map
      const invalidGateway = DemoContractAnalysisGateway(
        scenario: DemoContractAnalysisScenario.errorAiResponseInvalid,
      );
      final invalidMap = await invalidGateway.analyzeContractRaw(text: 'c', locale: 'es');
      expect(invalidMap['level'], 'purple_unknown');
    });

    test('dynamically overrides scenario based on embedded text flags', () async {
      const gateway = DemoContractAnalysisGateway(
        scenario: DemoContractAnalysisScenario.successYellow,
      );

      final green = await gateway.analyzeContractRaw(text: 'Contrato #demo:green', locale: 'es');
      expect(green['level'], 'green');

      final red = await gateway.analyzeContractRaw(text: 'Contrato #demo:red', locale: 'es');
      expect(red['level'], 'red');

      await expectLater(
        gateway.analyzeContractRaw(text: 'Contrato #demo:limit_error', locale: 'es'),
        throwsA(
          isA<ContractAnalysisException>().having(
            (e) => e.error,
            'error',
            ContractAnalysisError.aiDailyLimitExceeded,
          ),
        ),
      );
    });
  });

  group('ContractAnalysisNotifier (presentation/state)', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(contractAnalysisProvider);
      expect(state.status, ContractAnalysisStatus.idle);
      expect(state.isAnalyzing, isFalse);
      expect(state.hasResult, isFalse);
      expect(state.hasError, isFalse);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('successful flow transitions idle -> analyzing -> result', () async {
      final fakeGateway = _FakeContractAnalysisGateway();
      final container = ProviderContainer(
        overrides: [
          contractAnalysisGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractAnalysisProvider.notifier);

      final future = notifier.analyzeContract(text: 'Texto válido', locale: 'es');
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.analyzing);
      expect(container.read(contractAnalysisProvider).isAnalyzing, isTrue);

      await future;

      final finalState = container.read(contractAnalysisProvider);
      expect(finalState.status, ContractAnalysisStatus.result);
      expect(finalState.hasResult, isTrue);
      expect(finalState.result?.level, ContractAnalysisLevel.green);
      expect(fakeGateway.callCount, 1);
    });

    test('error flow transitions idle -> analyzing -> error with typed code', () async {
      final fakeGateway = _FakeContractAnalysisGateway(
        nextException: const ContractAnalysisException(
          ContractAnalysisError.aiServiceUnavailable,
          'Falla de servidor',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contractAnalysisGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      await container.read(contractAnalysisProvider.notifier).analyzeContract(
            text: 'Texto',
            locale: 'es',
          );

      final state = container.read(contractAnalysisProvider);
      expect(state.status, ContractAnalysisStatus.error);
      expect(state.hasError, isTrue);
      expect(state.error, ContractAnalysisError.aiServiceUnavailable);
      expect(state.errorMessage, 'Falla de servidor');
    });

    test('blocks double-tap while analyzing (only one request is triggered)', () async {
      final completer = Completer<Map<String, dynamic>>();
      final fakeGateway = _FakeContractAnalysisGateway(completer: completer);
      final container = ProviderContainer(
        overrides: [
          contractAnalysisGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractAnalysisProvider.notifier);

      // Primer toque
      final f1 = notifier.analyzeContract(text: 'Texto 1', locale: 'es');
      expect(container.read(contractAnalysisProvider).isAnalyzing, isTrue);

      // Segundo toque rápido (doble toque bloqueado)
      final f2 = notifier.analyzeContract(text: 'Texto 2', locale: 'es');

      expect(fakeGateway.callCount, 1, reason: 'Solo debe ejecutarse una petición al gateway');

      completer.complete(<String, dynamic>{
        'level': 'green',
        'general_recommendation': 'Ok',
        'key_points': <Map<String, dynamic>>[
          {'title': 'T', 'detail': 'D'},
        ],
        'clauses': <Map<String, dynamic>>[
          {
            'excerpt': 'E',
            'issue': 'I',
            'recommendation': 'R',
            'legal_reference': null,
          },
        ],
        'disclaimer': 'Disc',
        'locale': 'es',
      });

      await Future.wait([f1, f2]);
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.result);
      expect(fakeGateway.callCount, 1);
    });

    test('discards delayed/obsolete response when a new request is launched or reset() is called', () async {
      final completer1 = Completer<Map<String, dynamic>>();

      final fakeGateway = _FakeContractAnalysisGateway();
      final container = ProviderContainer(
        overrides: [
          contractAnalysisGatewayProvider.overrideWithValue(fakeGateway),
          contractAnalysisRepositoryProvider.overrideWith((ref) {
            return DefaultContractAnalysisRepository(
              gateway: fakeGateway,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      // Configura el gateway para devolver completers según el request
      fakeGateway.completer = completer1;

      final notifier = container.read(contractAnalysisProvider.notifier);

      // 1. Inicia request 1 (lento)
      final f1 = notifier.analyzeContract(text: 'Request 1', locale: 'es');

      // 2. Usuario cancela/reinicia (reset incrementa token)
      notifier.reset();
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.idle);

      // 3. Completa request 1 tardíamente
      completer1.complete(<String, dynamic>{
        'level': 'red',
        'general_recommendation': 'Respuesta vieja que debe descartarse',
        'key_points': <Map<String, dynamic>>[
          {'title': 'T', 'detail': 'D'},
        ],
        'clauses': <Map<String, dynamic>>[
          {
            'excerpt': 'E',
            'issue': 'I',
            'recommendation': 'R',
            'legal_reference': null,
          },
        ],
        'disclaimer': 'D',
        'locale': 'es',
      });
      await f1;

      // El estado NO debió cambiar a result con la respuesta vieja
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.idle);
      expect(container.read(contractAnalysisProvider).result, isNull);
    });

    test('resets analysis state when contract document is discarded in contractCaptureProvider', () async {
      final fakeGateway = _FakeContractAnalysisGateway();
      final container = ProviderContainer(
        overrides: [
          contractAnalysisGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      // 1. Simula que hay un documento cargado y analizado
      container.read(contractCaptureProvider.notifier).updateContractText(
            'Contrato de arrendamiento válido con suficientes caracteres para análisis.' * 2,
          );
      await container.read(contractAnalysisProvider.notifier).analyzeContract(
            text: 'Texto',
            locale: 'es',
          );
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.result);

      // 2. Descarta el documento
      await container.read(contractCaptureProvider.notifier).discardDocument();

      // 3. contractAnalysisProvider debe reiniciarse a idle automáticamente
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.idle);
      expect(container.read(contractAnalysisProvider).result, isNull);
    });

    test('resets analysis state when SessionController.signOut is invoked', () async {
      final fakeGateway = _FakeContractAnalysisGateway();
      final container = ProviderContainer(
        overrides: [
          contractAnalysisGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      await container.read(contractAnalysisProvider.notifier).analyzeContract(
            text: 'Texto',
            locale: 'es',
          );
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.result);

      // Cierra sesión
      container.read(sessionControllerProvider).signOut();

      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.idle);
      expect(container.read(contractAnalysisProvider).result, isNull);
    });
  });
}
