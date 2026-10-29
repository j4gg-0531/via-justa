import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/contracts/data/local_contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/domain/contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';
import 'package:via_justa/features/contracts/presentation/widgets/contract_capture_section.dart';

class _FakeContractOcrRepository implements ContractOcrRepository {
  _FakeContractOcrRepository({
    this.nextCameraResult,
    this.nextFileResult,
  });

  ContractDocumentCaptureResult? nextCameraResult;
  ContractDocumentCaptureResult? nextFileResult;
  final List<String> deletedTempPaths = <String>[];

  @override
  List<SyntheticContractSample> getSyntheticSamples() =>
      LocalContractOcrRepository.syntheticSamples;

  @override
  Future<ContractDocumentCaptureResult?> captureFromCamera({
    required String languageCode,
  }) async {
    return nextCameraResult;
  }

  @override
  Future<ContractDocumentCaptureResult?> pickDocumentFile({
    required String languageCode,
  }) async {
    return nextFileResult;
  }

  @override
  Future<ContractDocumentCaptureResult> loadSyntheticSample({
    required String sampleId,
    required String languageCode,
  }) async {
    final sample = LocalContractOcrRepository.syntheticSamples.firstWhere(
      (s) => s.id == sampleId,
      orElse: () => LocalContractOcrRepository.syntheticSamples.first,
    );
    final content = sample.localizedContent(languageCode);
    return ContractDocumentCaptureResult(
      source: ContractInputSource.syntheticSample,
      fileName: sample.fileName,
      fileSizeBytes: content.length,
      extractedText: content,
      tempFilePath: '/tmp/fake_${sample.fileName}',
      wasTempFileDeleted: true,
    );
  }

  @override
  Future<bool> deleteTemporaryFileIfPresent(String? tempFilePath) async {
    if (tempFilePath != null && tempFilePath.isNotEmpty) {
      deletedTempPaths.add(tempFilePath);
      final file = File(tempFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    return true;
  }
}

void main() {
  group('Domain contract capture validators (VJ-13 Paso A)', () {
    test('accepts JPG, JPEG, PNG and TXT; marks PDF as pdfComingSoon and rejects others', () {
      expect(validateContractFileExtension('foto_contrato.jpg'), isNull);
      expect(validateContractFileExtension('FOTO_CONTRATO.JPEG'), isNull);
      expect(validateContractFileExtension('pagina_1.png'), isNull);
      expect(validateContractFileExtension('clausulas.txt'), isNull);

      // Ajuste obligatorio 1: PDF queda "Próximamente"
      expect(
        validateContractFileExtension('arriendo.pdf'),
        ContractCaptureError.pdfComingSoon,
      );
      expect(
        validateContractFileExtension('ARRIENDO.PDF'),
        ContractCaptureError.pdfComingSoon,
      );

      // Otros formatos no soportados
      expect(
        validateContractFileExtension('contrato.docx'),
        ContractCaptureError.unsupportedFormat,
      );
      expect(
        validateContractFileExtension('sin_extension'),
        ContractCaptureError.unsupportedFormat,
      );
    });

    test('validates file size up to 10 MB', () {
      expect(validateContractFileSize(1024), isNull);
      expect(validateContractFileSize(maxContractFileSizeBytes), isNull);
      expect(
        validateContractFileSize(0),
        ContractCaptureError.emptyOrIllegibleText,
      );
      expect(
        validateContractFileSize(maxContractFileSizeBytes + 1),
        ContractCaptureError.fileTooLarge,
      );
    });

    test('normalizes text without silent truncation and enforces 20..15000 char limits', () {
      const shortText = 'Texto muy corto';
      expect(
        validateContractText(shortText),
        ContractCaptureError.emptyOrIllegibleText,
      );

      final validText = 'Cláusula de arrendamiento urbano válida. ' * 10;
      expect(validateContractText(validText), isNull);

      // Exactamente 15.000 caracteres es válido
      final exactLimitText = 'A' * maxContractCharacters;
      expect(validateContractText(exactLimitText), isNull);

      // Ajuste obligatorio 4: 15.001 caracteres advierte exceedsMaxLength y NO trunca en silencio
      final overLimitText = 'B' * (maxContractCharacters + 45);
      final normalized = normalizeExtractedContractText(overLimitText);
      expect(normalized.length, maxContractCharacters + 45);
      expect(
        validateContractText(overLimitText),
        ContractCaptureError.exceedsMaxLength,
      );
    });

  });

  group('RN-10 temporary cache file deletion and LocalContractOcrRepository', () {
    test('LocalContractOcrRepository deletes temporary OCR file immediately in finally block', () async {
      final tempDir = await Directory.systemTemp.createTemp('vj13_rn10_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final repo = LocalContractOcrRepository(tempDirectory: tempDir);
      final result = await repo.captureFromCamera(languageCode: 'es');

      expect(result, isNotNull);
      expect(result!.wasTempFileDeleted, isTrue);
      expect(result.tempFilePath, isNotNull);
      expect(File(result.tempFilePath!).existsSync(), isFalse);
    });

    test('ContractCaptureNotifier deletes real temp file after OCR and on discardDocument (RN-10)', () async {
      final tempDir = await Directory.systemTemp.createTemp('vj13_notifier_rn10_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final tempFile = File('${tempDir.path}${Platform.pathSeparator}scan_temp.jpg');
      await tempFile.writeAsString('Contenido temporal de imagen OCR');
      expect(tempFile.existsSync(), isTrue);

      final fakeRepo = _FakeContractOcrRepository(
        nextCameraResult: ContractDocumentCaptureResult(
          source: ContractInputSource.cameraPhoto,
          fileName: 'scan_temp.jpg',
          fileSizeBytes: 512,
          extractedText:
              'CLÁUSULA PRIMERA: Contrato sintético de arrendamiento en Valledupar por \$900.000 COP.',
          tempFilePath: tempFile.path,
          wasTempFileDeleted: false,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // 1. Capturar desde cámara -> debe borrar el archivo temporal inmediatamente tras el OCR
      await container
          .read(contractCaptureProvider.notifier)
          .captureFromCamera(languageCode: 'es');

      final afterCapture = container.read(contractCaptureProvider);
      expect(afterCapture.status, ContractCaptureStatus.readyForAnalysis);
      expect(afterCapture.wasTempFileDeleted, isTrue);
      expect(tempFile.existsSync(), isFalse);
      expect(fakeRepo.deletedTempPaths, contains(tempFile.path));

      // 2. Simular que se recrea un archivo temporal y llamar a discardDocument() -> debe borrarlo y limpiar memoria
      await tempFile.writeAsString(' Segundo archivo temporal ');
      expect(tempFile.existsSync(), isTrue);

      await container.read(contractCaptureProvider.notifier).discardDocument();
      final afterDiscard = container.read(contractCaptureProvider);

      expect(afterDiscard.status, ContractCaptureStatus.idle);
      expect(afterDiscard.text, isEmpty);
      expect(tempFile.existsSync(), isFalse);
    });
  });

  group('ContractCaptureNotifier state transitions with fake repository', () {
    test('rejects PDF with pdfComingSoon and oversized files with fileTooLarge', () async {
      final fakeRepo = _FakeContractOcrRepository(
        nextFileResult: const ContractDocumentCaptureResult(
          source: ContractInputSource.documentFile,
          fileName: 'contrato_escaneado.pdf',
          fileSizeBytes: 2048,
          extractedText: 'Texto de prueba suficientemente largo para pasar.',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(contractCaptureProvider.notifier)
          .pickDocumentFile(languageCode: 'es');

      expect(
        container.read(contractCaptureProvider).status,
        ContractCaptureStatus.error,
      );
      expect(
        container.read(contractCaptureProvider).error,
        ContractCaptureError.pdfComingSoon,
      );

      // Archivo demasiado grande (> 10 MB)
      fakeRepo.nextFileResult = const ContractDocumentCaptureResult(
        source: ContractInputSource.documentFile,
        fileName: 'foto_alta_resolucion.png',
        fileSizeBytes: maxContractFileSizeBytes + 500,
        extractedText: 'Texto válido de contrato de arrendamiento urbano.',
      );

      await container
          .read(contractCaptureProvider.notifier)
          .pickDocumentFile(languageCode: 'es');

      expect(
        container.read(contractCaptureProvider).error,
        ContractCaptureError.fileTooLarge,
      );
    });

    test('warns on > 15,000 characters without truncating and recovers to readyForAnalysis when trimmed', () {
      final fakeRepo = _FakeContractOcrRepository();
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractCaptureProvider.notifier);
      notifier.startManualEntry();

      final overLimit = 'C' * 15050;
      notifier.updateContractText(overLimit);

      final errorState = container.read(contractCaptureProvider);
      expect(errorState.status, ContractCaptureStatus.error);
      expect(errorState.error, ContractCaptureError.exceedsMaxLength);
      // No se trunca en silencio: conserva los 15.050 caracteres
      expect(errorState.text.length, 15050);
      expect(errorState.excessCharacters, 50);
      expect(errorState.isReadyForAnalysis, isFalse);

      // Cuando el usuario recorta el texto a <= 15.000 caracteres, pasa a readyForAnalysis
      final trimmed = overLimit.substring(0, 14900);
      notifier.updateContractText(trimmed);

      final readyState = container.read(contractCaptureProvider);
      expect(readyState.status, ContractCaptureStatus.readyForAnalysis);
      expect(readyState.error, isNull);
      expect(readyState.isReadyForAnalysis, isTrue);
    });

    test('loads synthetic contract samples in ES and EN reaching readyForAnalysis', () async {
      final fakeRepo = _FakeContractOcrRepository();
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractCaptureProvider.notifier);
      await notifier.loadSyntheticSample(
        'synthetic_lease_deposit',
        languageCode: 'es',
      );
      expect(
        container.read(contractCaptureProvider).status,
        ContractCaptureStatus.readyForAnalysis,
      );
      expect(
        container.read(contractCaptureProvider).text,
        contains('CONTRATO SINTÉTICO'),
      );

      await notifier.loadSyntheticSample(
        'synthetic_lease_deposit',
        languageCode: 'en',
      );
      expect(
        container.read(contractCaptureProvider).text,
        contains('SYNTHETIC URBAN RESIDENTIAL LEASE'),
      );
    });

    test('notifier manages consent decision before camera/file capture (RN-10)', () async {
      final fakeRepo = _FakeContractOcrRepository(
        nextCameraResult: const ContractDocumentCaptureResult(
          source: ContractInputSource.cameraPhoto,
          fileName: 'captura.jpg',
          fileSizeBytes: 200,
          extractedText:
              'CLÁUSULA PRIMERA: Contrato sintético con consentimiento propio verificado.',
        ),
      );
      final container = ProviderContainer(
        overrides: [contractOcrRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(contractCaptureProvider.notifier);

      // 1. Antes de tener consentimiento, solicitar cámara no abre la cámara; pide confirmación
      notifier.requestCameraCapture(languageCode: 'es');
      expect(
        container.read(contractCaptureProvider).pendingConsentSource,
        ContractInputSource.cameraPhoto,
      );
      expect(container.read(contractCaptureProvider).hasGivenConsent, isFalse);

      // 2. Si el usuario cancela, se limpia la solicitud
      notifier.cancelConsent();
      expect(container.read(contractCaptureProvider).pendingConsentSource, isNull);
      expect(container.read(contractCaptureProvider).hasGivenConsent, isFalse);

      // 3. Volver a solicitar y confirmar consentimiento -> se ejecuta la cámara y se guarda en sesión
      notifier.requestCameraCapture(languageCode: 'es');
      await notifier.confirmConsentAndProceed(languageCode: 'es');

      expect(container.read(contractCaptureProvider).hasGivenConsent, isTrue);
      expect(container.read(contractCaptureProvider).pendingConsentSource, isNull);
      expect(
        container.read(contractCaptureProvider).status,
        ContractCaptureStatus.readyForAnalysis,
      );

      // 4. Con consentimiento previo, la siguiente solicitud no vuelve a preguntar
      await notifier.requestCameraCapture(languageCode: 'es');
      expect(container.read(contractCaptureProvider).pendingConsentSource, isNull);
    });
  });

  group('ContractCaptureSection widget test (360x780 @ 1.5x text scale)', () {
    testWidgets('renders synthetic samples, editable OCR text and disabled Analyze button without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeRepo = _FakeContractOcrRepository();
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ContractCaptureSection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cargar un contrato sintético tocando su tarjeta (MaterialApp por defecto usa 'en')
      final sampleTitle =
          LocalContractOcrRepository.syntheticSamples.first.titleEn;
      await tester.ensureVisible(find.text(sampleTitle));
      await tester.tap(find.text(sampleTitle));
      await tester.pumpAndSettle();

      expect(
        container.read(contractCaptureProvider).status,
        ContractCaptureStatus.readyForAnalysis,
      );
      expect(find.byType(TextField), findsOneWidget);

      // El botón Analizar existe pero está deshabilitado (VJ-14)
      final analyzeBtnFinder = find.widgetWithText(
        VjButton,
        'contract_capture.analyze_disabled_cta',
      );
      expect(analyzeBtnFinder, findsOneWidget);
      final analyzeBtn = tester.widget<VjButton>(analyzeBtnFinder);
      expect(analyzeBtn.onPressed, isNull);

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows on-device consent dialog before camera capture and cancels cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeRepo = _FakeContractOcrRepository();
      final container = ProviderContainer(
        overrides: [
          contractOcrRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ContractCaptureSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cameraBtnFinder = find.widgetWithText(
        OutlinedButton,
        'contract_capture.action_camera',
      );
      expect(cameraBtnFinder, findsOneWidget);
      await tester.tap(cameraBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('contract_capture.consent_dialog_title'),
        findsOneWidget,
      );

      final cancelBtnFinder = find.widgetWithText(
        TextButton,
        'contract_capture.consent_cancel',
      );
      expect(cancelBtnFinder, findsOneWidget);
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(contractCaptureProvider).pendingConsentSource, isNull);
    });
  });
}
