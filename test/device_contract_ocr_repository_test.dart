import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/contracts/data/device_contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/data/local_contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/data/pdf_contract_text_extractor.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_capture_provider.dart';

/// Texto que devuelve el OCR falso; simula lo que leería ML Kit en una foto.
const String _fakeOcrText =
    'CLÁUSULA PRIMERA: Contrato sintético de arrendamiento en Valledupar por \$900.000 COP.';

/// Crea una carpeta temporal que imita la caché de la app (con subcarpeta `file_picker`).
Future<Directory> _createCacheDir() async {
  final dir = await Directory.systemTemp.createTemp('vj13_paso_b_');
  addTearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
  return dir;
}

File _writeFile(Directory dir, String relativePath, List<int> bytes) {
  final file = File('${dir.path}${Platform.pathSeparator}$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes, flush: true);
  return file;
}

void main() {
  group('DeviceContractOcrRepository (VJ-13 Paso B, RN-10)', () {
    test('camera: runs OCR on the JPG and deletes the image_picker file afterwards', () async {
      final cache = await _createCacheDir();
      final photo = _writeFile(cache, 'scaled_image_picker123.jpg', List<int>.filled(2048, 7));
      final ocrCalls = <String>[];

      final repo = DeviceContractOcrRepository(
        pickCameraImage: () async => photo.path,
        recognizeImageText: (path) async {
          ocrCalls.add(path);
          expect(File(path).existsSync(), isTrue, reason: 'OCR runs before deletion');
          return _fakeOcrText;
        },
        clearFilePickerCache: () async {},
        cacheDirectory: cache,
      );

      final result = await repo.captureFromCamera(languageCode: 'es');

      expect(result, isNotNull);
      expect(result!.source, ContractInputSource.cameraPhoto);
      expect(result.fileName, 'scaled_image_picker123.jpg');
      expect(result.fileSizeBytes, 2048);
      expect(result.extractedText, _fakeOcrText);
      expect(ocrCalls, <String>[photo.path]);
      expect(result.wasTempFileDeleted, isTrue);
      expect(photo.existsSync(), isFalse);
    });

    test('camera: deletes the image_picker file even when OCR fails', () async {
      final cache = await _createCacheDir();
      final photo = _writeFile(cache, 'image_picker456.jpg', List<int>.filled(512, 1));

      final repo = DeviceContractOcrRepository(
        pickCameraImage: () async => photo.path,
        recognizeImageText: (_) async => throw StateError('ML Kit failure'),
        clearFilePickerCache: () async {},
        cacheDirectory: cache,
      );

      await expectLater(
        repo.captureFromCamera(languageCode: 'es'),
        throwsA(isA<StateError>()),
      );
      expect(photo.existsSync(), isFalse);
    });

    test('camera: on cancel returns null and removes image_picker leftovers only', () async {
      final cache = await _createCacheDir();
      final leftover = _writeFile(cache, 'image_picker789.jpg', <int>[]);
      final unrelated = _writeFile(cache, 'otro_archivo.jpg', <int>[1, 2, 3]);

      final repo = DeviceContractOcrRepository(
        pickCameraImage: () async => null,
        recognizeImageText: (_) async => fail('OCR must not run on cancel'),
        clearFilePickerCache: () async {},
        cacheDirectory: cache,
      );

      final result = await repo.captureFromCamera(languageCode: 'es');

      expect(result, isNull);
      expect(leftover.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    });

    test('file picker: reads TXT as UTF-8, deletes the copy and clears file_picker cache', () async {
      final cache = await _createCacheDir();
      final txt = File(
        '${cache.path}${Platform.pathSeparator}file_picker${Platform.pathSeparator}1700'
        '${Platform.pathSeparator}contrato.txt',
      );
      txt.parent.createSync(recursive: true);
      txt.writeAsStringSync(_fakeOcrText);
      var cacheClears = 0;

      final repo = DeviceContractOcrRepository(
        pickContractFile: () async =>
            PickedContractFile(name: 'contrato.txt', path: txt.path),
        recognizeImageText: (_) async => fail('TXT must not go through OCR'),
        clearFilePickerCache: () async => cacheClears++,
        cacheDirectory: cache,
      );

      final result = await repo.pickDocumentFile(languageCode: 'es');

      expect(result, isNotNull);
      expect(result!.source, ContractInputSource.documentFile);
      expect(result.extractedText, _fakeOcrText);
      expect(result.wasTempFileDeleted, isTrue);
      expect(txt.existsSync(), isFalse);
      expect(cacheClears, greaterThanOrEqualTo(1));
    });

    test('file picker: runs OCR on PNG and deletes the cached copy', () async {
      final cache = await _createCacheDir();
      final png = _writeFile(cache, 'file_picker/1701/pagina.png', List<int>.filled(1024, 3));

      final repo = DeviceContractOcrRepository(
        pickContractFile: () async =>
            PickedContractFile(name: 'pagina.png', path: png.path),
        recognizeImageText: (_) async => _fakeOcrText,
        clearFilePickerCache: () async {},
        cacheDirectory: cache,
      );

      final result = await repo.pickDocumentFile(languageCode: 'es');

      expect(result!.extractedText, _fakeOcrText);
      expect(png.existsSync(), isFalse);
    });

    test('file picker: PDF is extracted locally, deleted from cache (RN-10) and reaches readyForAnalysis', () async {
      final cache = await _createCacheDir();
      const pdfContent = '%PDF-1.4\n'
          '1 0 obj << /Length 110 >>\n'
          'stream\n'
          'BT /F1 12 Tf 72 720 Td '
          '(CLAUSULA PRIMERA: Contrato de arrendamiento urbano en Valledupar por 900.000 COP.) Tj ET\n'
          'endstream\n'
          'endobj\n'
          '%%EOF';
      final pdf = _writeFile(
        cache,
        'file_picker/1702/arriendo.pdf',
        latin1.encode(pdfContent),
      );

      final repo = DeviceContractOcrRepository(
        pickContractFile: () async =>
            PickedContractFile(name: 'arriendo.pdf', path: pdf.path),
        recognizeImageText: (_) async => fail('PDF must not go through image OCR'),
        clearFilePickerCache: () async {},
        cacheDirectory: cache,
      );

      final container = ProviderContainer(
        overrides: [contractOcrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(contractCaptureProvider.notifier)
          .pickDocumentFile(languageCode: 'es');
      final state = container.read(contractCaptureProvider);

      expect(pdf.existsSync(), isFalse);
      expect(state.status, ContractCaptureStatus.readyForAnalysis);
      expect(state.error, isNull);
      expect(
        state.text,
        contains('CLAUSULA PRIMERA: Contrato de arrendamiento urbano'),
      );
    });

    test('pdf_contract_text_extractor decodes FlateDecode streams and ToUnicode CMaps', () {
      const cmapStream = 'beginbfchar\n'
          '<01> <0043>\n'
          '<02> <004F>\n'
          '<03> <0050>\n'
          'endbfchar';
      const contentStream = 'BT\n'
          '[(CONTRATO DE ARRIENDO EN ) -220 <010203>] TJ\n'
          'T*\n'
          '(LEY 820 DE 2003 VIGENTE.) Tj\n'
          'ET';
      final compressedContent = zlib.encode(latin1.encode(contentStream));

      final builder = BytesBuilder()
        ..add(latin1.encode('%PDF-1.4\n1 0 obj <<>>\nstream\n$cmapStream\nendstream\nendobj\n'))
        ..add(latin1.encode('2 0 obj << /Filter /FlateDecode >>\nstream\n'))
        ..add(compressedContent)
        ..add(latin1.encode('\nendstream\nendobj\n%%EOF'));

      final extracted = extractTextFromPdfBytes(builder.toBytes());
      expect(extracted, contains('CONTRATO DE ARRIENDO EN COP'));
      expect(extracted, contains('LEY 820 DE 2003 VIGENTE.'));
    });

    test('pdf_contract_text_extractor joins runs on the same Tm Y coordinate without splitting words', () {
      const contentStream = 'BT 1 0 0 1 70.94 631.06 Tm [(A)] TJ ET\n'
          'BT 1 0 0 1 77.78 631.06 Tm [(RENDATARIO (s):)] TJ ET\n'
          'BT 1 0 0 1 166.82 631.06 Tm [( )] TJ ET\n'
          'BT 1 0 0 1 70.94 619.00 Tm [(así c)] TJ ET\n'
          'BT 1 0 0 1 92.10 619.00 Tm [(omo por la Ley 820 de 2003.)] TJ ET';
      final pdfBytes = Uint8List.fromList(
        latin1.encode(
          '%PDF-1.4\n1 0 obj <<>>\nstream\n$contentStream\nendstream\nendobj\n%%EOF',
        ),
      );

      final extracted = extractTextFromPdfBytes(pdfBytes);
      expect(
        extracted,
        'ARENDATARIO (s):\nasí como por la Ley 820 de 2003.',
      );
    });

    test('file picker: oversized image is not processed and is deleted', () async {
      final cache = await _createCacheDir();
      final big = _writeFile(
        cache,
        'file_picker/1703/foto_grande.jpg',
        List<int>.filled(maxContractFileSizeBytes + 1, 0),
      );

      final repo = DeviceContractOcrRepository(
        pickContractFile: () async =>
            PickedContractFile(name: 'foto_grande.jpg', path: big.path),
        recognizeImageText: (_) async => fail('Oversized files must not run OCR'),
        clearFilePickerCache: () async {},
        cacheDirectory: cache,
      );

      final result = await repo.pickDocumentFile(languageCode: 'es');

      expect(result!.fileSizeBytes, maxContractFileSizeBytes + 1);
      expect(result.extractedText, isEmpty);
      expect(validateContractFileSize(result.fileSizeBytes), ContractCaptureError.fileTooLarge);
      expect(big.existsSync(), isFalse);
    });

    test('file picker: cancel returns null without touching the cache', () async {
      var cacheClears = 0;
      final repo = DeviceContractOcrRepository(
        pickContractFile: () async => null,
        clearFilePickerCache: () async => cacheClears++,
      );

      expect(await repo.pickDocumentFile(languageCode: 'es'), isNull);
      expect(cacheClears, 0);
    });

    test('discardDocument deletes a remaining file_picker copy through the notifier', () async {
      final cache = await _createCacheDir();
      final txt = _writeFile(cache, 'file_picker/1704/contrato.txt', _fakeOcrText.codeUnits);
      var cacheClears = 0;

      final repo = DeviceContractOcrRepository(
        pickContractFile: () async =>
            PickedContractFile(name: 'contrato.txt', path: txt.path),
        clearFilePickerCache: () async => cacheClears++,
        cacheDirectory: cache,
      );
      final container = ProviderContainer(
        overrides: [contractOcrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(contractCaptureProvider.notifier);

      await notifier.pickDocumentFile(languageCode: 'es');
      expect(
        container.read(contractCaptureProvider).status,
        ContractCaptureStatus.readyForAnalysis,
      );

      // Simula que el plugin vuelve a dejar la copia en caché antes de descartar.
      txt.writeAsStringSync(_fakeOcrText);
      final clearsBeforeDiscard = cacheClears;

      await notifier.discardDocument();

      expect(txt.existsSync(), isFalse);
      expect(cacheClears, greaterThan(clearsBeforeDiscard));
      expect(container.read(contractCaptureProvider).text, isEmpty);
    });

    test('keeps the synthetic ES/EN samples for tests and emulator', () async {
      final repo = DeviceContractOcrRepository(clearFilePickerCache: () async {});

      expect(repo.getSyntheticSamples(), LocalContractOcrRepository.syntheticSamples);

      final sample = LocalContractOcrRepository.syntheticSamples.first;
      final en = await repo.loadSyntheticSample(sampleId: sample.id, languageCode: 'en');
      expect(en.source, ContractInputSource.syntheticSample);
      expect(en.extractedText, sample.contentEn);
      expect(en.wasTempFileDeleted, isTrue);
    });
  });
}
