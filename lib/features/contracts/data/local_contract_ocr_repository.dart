import 'dart:convert';
import 'dart:io';

import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/domain/contract_ocr_repository.dart';

/// Implementación local de [ContractOcrRepository] para el Paso A de `VJ-13`.
///
/// Provee contratos sintéticos de prueba en español e inglés (sin datos personales reales,
/// conforme a `docs/fuentes-y-licencias.md` sección 4.2) y gestiona el borrado inmediato
/// de archivos temporales en caché tras el OCR y al descartar (`RN-10`).
class LocalContractOcrRepository implements ContractOcrRepository {
  LocalContractOcrRepository({this.tempDirectory});

  final Directory? tempDirectory;

  static const List<SyntheticContractSample> syntheticSamples =
      <SyntheticContractSample>[
    SyntheticContractSample(
      id: 'synthetic_lease_deposit',
      fileName: 'contrato_arriendo_deposito_sintetico.jpg',
      titleEs: 'Arriendo con depósito en efectivo (Art. 16 Ley 820)',
      titleEn: 'Lease with cash security deposit (Law 820 Art. 16)',
      descriptionEs:
          'Contrato sintético con exigencia de depósito de garantía y reajuste anual.',
      descriptionEn:
          'Synthetic lease requiring a cash deposit and annual rent adjustment.',
      contentEs: '''CONTRATO SINTÉTICO DE ARRENDAMIENTO DE VIVIENDA URBANA (PRUEBA SIN DATOS REALES)
Ciudad: Valledupar, Cesar · Inmueble de prueba: Apartaestudio Zona Centro.

CLÁUSULA PRIMERA — CANON MENSUAL: El arrendatario pagará un canon mensual de \$850.000 COP dentro de los primeros cinco (5) días de cada mes.

CLÁUSULA SEGUNDA — DEPÓSITO EN DINERO EFECTIVO: Para garantizar el cumplimiento de las obligaciones y el pago de servicios públicos, el arrendatario entrega en este acto un depósito en efectivo equivalente a dos (2) cánones mensuales (\$1.700.000 COP), el cual quedará en poder del arrendador.

CLÁUSULA TERCERA — REAJUSTE ANUAL: Cada doce (12) meses de ejecución del contrato, el canon se incrementará hasta en el 100% del IPC del año inmediatamente anterior certificado por el DANE (Ley 820 de 2003, Art. 20).''',
      contentEn: '''SYNTHETIC URBAN RESIDENTIAL LEASE AGREEMENT (TEST ONLY — NO REAL DATA)
City: Valledupar, Cesar · Sample property: Downtown Studio Apartment.

CLAUSE ONE — MONTHLY RENT: The tenant shall pay a monthly rent of \$850,000 COP within the first five (5) days of each month.

CLAUSE TWO — CASH SECURITY DEPOSIT: To guarantee compliance with obligations and utility bills, the tenant delivers a cash security deposit equal to two (2) monthly rents (\$1,700,000 COP) to be held by the landlord.

CLAUSE THREE — ANNUAL ADJUSTMENT: Every twelve (12) months of contract execution, the rent shall increase up to 100% of the previous year's CPI certified by DANE (Law 820 of 2003, Art. 20).''',
    ),
    SyntheticContractSample(
      id: 'synthetic_lease_excessive_increase',
      fileName: 'contrato_arriendo_incremento_sintetico.png',
      titleEs: 'Arriendo con reajuste semestral y penalidad (Art. 18 y 20)',
      titleEn: 'Lease with semi-annual increase & penalty (Art. 18 & 20)',
      descriptionEs:
          'Contrato sintético con incremento cada 6 meses y cláusula penal de 3 cánones.',
      descriptionEn:
          'Synthetic lease featuring a 6-month rent hike and 3-month penalty clause.',
      contentEs: '''CONTRATO SINTÉTICO DE ARRENDAMIENTO URBANO — CASO DE REVISIÓN (PRUEBA)
Ciudad: Valledupar, Cesar · Sector: Zona Norte.

CLÁUSULA PRIMERA — OBJETO Y PRECIO: El canon mensual inicial es de \$1.200.000 COP pagaderos mensualmente.

CLÁUSULA SEGUNDA — REAJUSTE SEMESTRAL AUTOMÁTICO: Las partes acuerdan que el canon de arrendamiento subirá un quince por ciento (15%) cada seis (6) meses sin importar la variación del IPC.

CLÁUSULA TERCERA — TERMINACIÓN ANTICIPADA: Si el arrendatario desocupa el inmueble antes del vencimiento, deberá pagar una sanción inmediata de tres (3) cánones mensuales adicionales sin derecho a preaviso.''',
      contentEn: '''SYNTHETIC URBAN LEASE AGREEMENT — REVIEW CASE (TEST ONLY)
City: Valledupar, Cesar · Area: North Zone.

CLAUSE ONE — PURPOSE AND RENT: The initial monthly rent is \$1,200,000 COP payable monthly.

CLAUSE TWO — AUTOMATIC SEMI-ANNUAL INCREASE: The parties agree that the monthly rent will increase by fifteen percent (15%) every six (6) months regardless of CPI variation.

CLAUSE THREE — EARLY TERMINATION: If the tenant vacates the property before expiration, they must pay an immediate penalty of three (3) monthly rents without notice rights.''',
    ),
    SyntheticContractSample(
      id: 'synthetic_services_standard',
      fileName: 'contrato_servicios_locales_sintetico.txt',
      titleEs: 'Acuerdo estándar de servicios y mantenimiento',
      titleEn: 'Standard local services & maintenance agreement',
      descriptionEs:
          'Contrato sintético con plazos claros, preaviso bilateral y obligaciones equilibradas.',
      descriptionEn:
          'Synthetic agreement with clear terms, bilateral notice, and balanced duties.',
      contentEs: '''ACUERDO SINTÉTICO DE PRESTACIÓN DE SERVICIOS LOCALES (PRUEBA)
Lugar: Valledupar, Cesar.

PRIMERA — ALCANCE: El prestador realizará el mantenimiento preventivo de aires acondicionados y redes eléctricas del local comercial.
SEGUNDA — VALOR Y FORMA DE PAGO: El valor total acordado es de \$280.000 COP, pagaderos al finalizar y recibir a satisfacción el servicio.
TERCERA — GARANTÍA Y TERMINACIÓN: El trabajo cuenta con treinta (30) días de garantía escrita. Cualquiera de las partes podrá dar por terminado el acuerdo con preaviso escrito de cinco (5) días hábiles sin penalidades ocultas.''',
      contentEn: '''SYNTHETIC LOCAL SERVICE AGREEMENT (TEST ONLY)
Location: Valledupar, Cesar.

FIRST — SCOPE: The provider shall perform preventive maintenance on air conditioning units and electrical wiring at the commercial premises.
SECOND — PRICE AND PAYMENT: The agreed total price is \$280,000 COP, payable upon satisfactory completion of the service.
THIRD — WARRANTY AND TERMINATION: The work includes a thirty (30) day written warranty. Either party may terminate the agreement with five (5) business days written notice without hidden penalties.''',
    ),
  ];

  @override
  List<SyntheticContractSample> getSyntheticSamples() => syntheticSamples;

  @override
  Future<ContractDocumentCaptureResult?> captureFromCamera({
    required String languageCode,
  }) async {
    final sample = syntheticSamples.first;
    final text = sample.localizedContent(languageCode);
    return _processWithTemporaryCacheFile(
      source: ContractInputSource.cameraPhoto,
      fileName: 'captura_camara_contrato.jpg',
      content: text,
    );
  }

  @override
  Future<ContractDocumentCaptureResult?> pickDocumentFile({
    required String languageCode,
  }) async {
    final sample = syntheticSamples[1];
    final text = sample.localizedContent(languageCode);
    return _processWithTemporaryCacheFile(
      source: ContractInputSource.documentFile,
      fileName: 'contrato_seleccionado.txt',
      content: text,
    );
  }

  @override
  Future<ContractDocumentCaptureResult> loadSyntheticSample({
    required String sampleId,
    required String languageCode,
  }) async {
    SyntheticContractSample selected = syntheticSamples.first;
    for (final sample in syntheticSamples) {
      if (sample.id == sampleId) {
        selected = sample;
        break;
      }
    }
    final text = selected.localizedContent(languageCode);
    return _processWithTemporaryCacheFile(
      source: ContractInputSource.syntheticSample,
      fileName: selected.fileName,
      content: text,
    );
  }

  /// Crea un archivo temporal en caché para el procesamiento OCR y garantiza su eliminación
  /// inmediata en el bloque `finally` conforme a la regla de privacidad `RN-10`.
  Future<ContractDocumentCaptureResult> _processWithTemporaryCacheFile({
    required ContractInputSource source,
    required String fileName,
    required String content,
  }) async {
    final dir = tempDirectory ?? Directory.systemTemp;
    final ext = extractFileExtension(fileName);
    final safeExt = ext.isEmpty ? 'txt' : ext;
    final tempFile = File(
      '${dir.path}${Platform.pathSeparator}vj_ocr_temp_${DateTime.now().microsecondsSinceEpoch}.$safeExt',
    );

    var deleted = false;
    var sizeBytes = 0;
    try {
      final encoded = utf8.encode(content);
      tempFile.writeAsBytesSync(encoded, flush: true);
      sizeBytes = tempFile.lengthSync();
    } finally {
      deleted = await deleteTemporaryFileIfPresent(tempFile.path);
    }

    return ContractDocumentCaptureResult(
      source: source,
      fileName: fileName,
      fileSizeBytes: sizeBytes,
      extractedText: content,
      tempFilePath: tempFile.path,
      wasTempFileDeleted: deleted,
    );
  }

  @override
  Future<bool> deleteTemporaryFileIfPresent(String? tempFilePath) async {
    if (tempFilePath == null || tempFilePath.trim().isEmpty) {
      return true;
    }
    try {
      final file = File(tempFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      return !file.existsSync();
    } catch (_) {
      return false;
    }
  }
}
