import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/domain/contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_analysis_provider.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';
import 'package:via_justa/features/contracts/presentation/widgets/contract_analysis_result_view.dart';
import 'package:via_justa/features/contracts/presentation/widgets/contract_capture_section.dart';

class _FakeOcrRepository implements ContractOcrRepository {
  @override
  Future<ContractDocumentCaptureResult> captureFromCamera({
    required String languageCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ContractDocumentCaptureResult?> pickDocumentFile({
    required String languageCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  List<SyntheticContractSample> getSyntheticSamples() {
    return const [
      SyntheticContractSample(
        id: 'synth-1',
        fileName: 'contrato_arriendo_sintetico.txt',
        titleEs: 'Arriendo de vivienda urbana (Valledupar)',
        titleEn: 'Urban Residential Lease (Valledupar)',
        descriptionEs: 'Contrato sintético estándar de arriendo.',
        descriptionEn: 'Standard synthetic lease contract.',
        contentEs:
            r'PRIMERA. Canon mensual: $1.200.000 COP.\nSEGUNDA. Prórroga automática por 12 meses.\nTERCERA. Penalidad por mora: 5% diario.',
        contentEn:
            r'FIRST. Monthly rent: $1,200,000 COP.\nSECOND. Automatic renewal for 12 months.\nTHIRD. Late fee: 5% daily.',
      ),
    ];
  }

  @override
  Future<ContractDocumentCaptureResult> loadSyntheticSample({
    required String sampleId,
    required String languageCode,
  }) async {
    final sample = getSyntheticSamples().first;
    final content = sample.localizedContent(languageCode);
    return ContractDocumentCaptureResult(
      source: ContractInputSource.syntheticSample,
      fileName: sample.fileName,
      fileSizeBytes: content.length,
      extractedText: content,
      wasTempFileDeleted: true,
    );
  }

  @override
  Future<bool> deleteTemporaryFileIfPresent(String? tempFilePath) async {
    return true;
  }
}

class _ControllableGateway implements ContractAnalysisGateway {
  _ControllableGateway({
    this.exceptionToThrow,
  });

  Map<String, dynamic>? responseToReturn;
  ContractAnalysisException? exceptionToThrow;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> analyzeContractRaw({
    required String text,
    required String locale,
  }) async {
    callCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseToReturn ??
        {
          'level': 'yellow',
          'general_recommendation': 'Revisa la cláusula de mora antes de firmar.',
          'key_points': [
            {
              'title': 'Canon pactado',
              'detail': r'$1.200.000 COP mensuales.',
            }
          ],
          'clauses': [
            {
              'excerpt': 'Penalidad por mora: 5% diario.',
              'issue': 'Tasa excesiva que supera límites legales.',
              'legal_reference': 'Ley 820 de 2003, Art. 20',
              'recommendation': 'Solicita ajustar la mora al interés bancario corriente.',
            }
          ],
          'disclaimer': 'Aviso orientativo educativo.',
          'locale': locale,
          'is_demo': true,
        };
  }
}

Widget _wrapWidget({
  required Widget child,
  required ProviderContainer container,
  double textScaleFactor = 1.0,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 780),
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContractAnalysisResultView widget tests (VJ-14 Paso C)', () {
    testWidgets('renders green level result with demo banner and without legalReference',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const greenResult = ContractAnalysisResult(
        level: ContractAnalysisLevel.green,
        generalRecommendation: 'El contrato está balanceado y no presenta alertas.',
        keyPoints: [
          ContractKeyPoint(
            title: 'Plazo de ejecución',
            detail: '6 meses prorrogables.',
          ),
        ],
        clauses: [
          ContractAnalyzedClause(
            excerpt: 'Las partes acuerdan entregas parciales mensuales.',
            issue: 'Cláusula habitual sin desequilibrio detectado.',
            recommendation: 'Verifica los calendarios de entrega acordados.',
            legalReference: null, // Nullable legal reference
          ),
        ],
        disclaimer: 'Aviso orientativo oficial.',
        locale: 'es',
        isDemo: true,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWidget(
          child: const ContractAnalysisResultView(result: greenResult),
          container: container,
          textScaleFactor: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      // Banner de demostración visible
      expect(find.text('contract_analysis.demo_banner_title'), findsOneWidget);
      // Semáforo de nivel verde
      expect(find.text('contract_analysis.level_green'), findsOneWidget);
      // Recomendación general y punto clave
      expect(find.text('El contrato está balanceado y no presenta alertas.'), findsOneWidget);
      expect(find.text('Plazo de ejecución'), findsOneWidget);
      expect(find.text('6 meses prorrogables.'), findsOneWidget);

      // Cláusula
      expect(find.text('“Las partes acuerdan entregas parciales mensuales.”'), findsOneWidget);
      // Como legalReference es null, no debe renderizar el label de referencia legal
      expect(find.text('contract_analysis.clause_legal_ref_label'), findsNothing);

      // Aviso orientativo
      expect(find.text('Aviso orientativo oficial.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders red level result without demo banner when isDemo is false and with legalReference',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const redResult = ContractAnalysisResult(
        level: ContractAnalysisLevel.red,
        generalRecommendation: 'Se recomienda no firmar sin renegociar cláusulas críticas.',
        keyPoints: [
          ContractKeyPoint(
            title: 'Garantía solicitada',
            detail: 'Depósito equivalente a 6 meses de canon.',
          ),
        ],
        clauses: [
          ContractAnalyzedClause(
            excerpt: 'El arrendatario renuncia a todo derecho de reclamación.',
            issue: 'Cláusula leonina y lesiva del orden público contractual.',
            recommendation: 'Exige la eliminación inmediata de esta estipulación.',
            legalReference: 'Código Civil Art. 1604 y Ley 820 Art. 16',
          ),
        ],
        disclaimer: 'Aviso orientativo legal.',
        locale: 'es',
        isDemo: false, // Not demo
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWidget(
          child: const ContractAnalysisResultView(result: redResult),
          container: container,
          textScaleFactor: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      // No debe haber banner de demostración si isDemo es false
      expect(find.text('contract_analysis.demo_banner_title'), findsNothing);

      // Semáforo nivel rojo
      expect(find.text('contract_analysis.level_red'), findsOneWidget);
      expect(find.text('Código Civil Art. 1604 y Ley 820 Art. 16'), findsOneWidget);
      expect(find.text('contract_analysis.clause_legal_ref_label'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('ContractCaptureSection and AI analysis flow (VJ-14 Paso C)', () {
    testWidgets('requires second consent on first analysis request; proceeds on confirm',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeOcr = _FakeOcrRepository();
      final gateway = _ControllableGateway();
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeOcr),
          contractAnalysisGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWidget(
          child: const ContractCaptureSection(),
          container: container,
          textScaleFactor: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Cargar contrato sintético para pasar a readyForAnalysis (en test locale es 'en')
      final sampleTitle = fakeOcr.getSyntheticSamples().first.titleEn;
      await tester.ensureVisible(find.text(sampleTitle));
      await tester.tap(find.text(sampleTitle));
      await tester.pumpAndSettle();

      expect(
        container.read(contractCaptureProvider).status,
        ContractCaptureStatus.readyForAnalysis,
      );

      // Botón Analizar con IA está habilitado
      final analyzeBtn = find.widgetWithText(
        VjButton,
        'contract_analysis.analyze_cta',
      );
      expect(analyzeBtn, findsOneWidget);
      await tester.ensureVisible(analyzeBtn);

      // 2. Tocar botón Analizar dispara el diálogo del SEGUNDO consentimiento (IA)
      await tester.tap(analyzeBtn);
      await tester.pumpAndSettle();

      expect(find.text('contract_analysis.ai_consent_dialog_title'), findsOneWidget);
      expect(find.text('contract_analysis.ai_consent_dialog_body'), findsOneWidget);
      expect(gateway.callCount, 0); // No llamó a red todavía

      // 3. Confirmar consentimiento
      final continueBtn = find.widgetWithText(
        VjButton,
        'contract_analysis.ai_consent_continue',
      );
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // El diálogo se cierra, se envía la petición y el gateway recibe la llamada
      expect(find.text('contract_analysis.ai_consent_dialog_title'), findsNothing);
      expect(gateway.callCount, 1);
      expect(container.read(contractAnalysisProvider).hasResult, isTrue);

      // El resultado estructurado se muestra en pantalla
      expect(find.byType(ContractAnalysisResultView), findsOneWidget);
      expect(find.text('contract_analysis.level_yellow'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('canceling second consent does not call gateway and keeps state clean',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeOcr = _FakeOcrRepository();
      final gateway = _ControllableGateway();
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeOcr),
          contractAnalysisGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWidget(
          child: const ContractCaptureSection(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Cargar contrato sintético
      final sampleTitle = fakeOcr.getSyntheticSamples().first.titleEn;
      await tester.ensureVisible(find.text(sampleTitle));
      await tester.tap(find.text(sampleTitle));
      await tester.pumpAndSettle();

      // Tocar Analizar
      final analyzeBtn = find.widgetWithText(
        VjButton,
        'contract_analysis.analyze_cta',
      );
      await tester.ensureVisible(analyzeBtn);
      await tester.tap(analyzeBtn);
      await tester.pumpAndSettle();

      expect(find.text('contract_analysis.ai_consent_dialog_title'), findsOneWidget);

      // Cancelar consentimiento
      await tester.tap(find.text('contract_analysis.ai_consent_cancel'));
      await tester.pumpAndSettle();

      expect(find.text('contract_analysis.ai_consent_dialog_title'), findsNothing);
      expect(gateway.callCount, 0);
      expect(container.read(contractAnalysisProvider).status, ContractAnalysisStatus.idle);
      expect(find.byType(ContractAnalysisResultView), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('displays error card and allows safe retry on networkUnavailable',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeOcr = _FakeOcrRepository();
      final gateway = _ControllableGateway(
        exceptionToThrow: const ContractAnalysisException(
          ContractAnalysisError.networkUnavailable,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeOcr),
          contractAnalysisGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWidget(
          child: const ContractCaptureSection(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Cargar contrato y solicitar análisis
      final sampleTitle = fakeOcr.getSyntheticSamples().first.titleEn;
      await tester.ensureVisible(find.text(sampleTitle));
      await tester.tap(find.text(sampleTitle));
      await tester.pumpAndSettle();

      final analyzeBtn = find.widgetWithText(
        VjButton,
        'contract_analysis.analyze_cta',
      );
      await tester.ensureVisible(analyzeBtn);
      await tester.tap(analyzeBtn);
      await tester.pumpAndSettle();

      // Confirmar consentimiento
      await tester.tap(find.widgetWithText(VjButton, 'contract_analysis.ai_consent_continue'));
      await tester.pumpAndSettle();

      // Ver error y botón de reintento
      expect(find.text('contract_analysis.error_title'), findsOneWidget);
      expect(find.text('contract_analysis.error_network'), findsOneWidget);
      final retryBtn = find.widgetWithText(VjButton, 'contract_analysis.action_retry');
      expect(retryBtn, findsOneWidget);

      // Corregir la respuesta del gateway y tocar reintentar
      gateway.exceptionToThrow = null;
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(gateway.callCount, 2);
      expect(container.read(contractAnalysisProvider).hasResult, isTrue);
      expect(find.byType(ContractAnalysisResultView), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
