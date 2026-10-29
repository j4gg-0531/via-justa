import 'package:via_justa/features/contracts/domain/contract_capture.dart';

/// Contrato abstracto para la captura de documentos (cámara, archivos `JPG`/`PNG`/`TXT`,
/// muestras sintéticas ES/EN) y extracción de texto por OCR local (`VJ-13`).
///
/// Cumple `RN-10`: todo archivo temporal en caché debe eliminarse inmediatamente
/// después de extraer el texto y al descartar el documento.
abstract class ContractOcrRepository {
  /// Retorna el catálogo de contratos sintéticos de prueba en español e inglés.
  List<SyntheticContractSample> getSyntheticSamples();

  /// Captura una foto de contrato desde la cámara (JPG/PNG), ejecuta el OCR local
  /// y elimina el archivo temporal del caché antes de retornar (`RN-10`).
  /// Retorna `null` si el usuario cancela la captura.
  Future<ContractDocumentCaptureResult?> captureFromCamera({
    required String languageCode,
  });

  /// Selecciona un archivo de contrato (`JPG`, `PNG`, `TXT` o detecta `PDF` para advertir),
  /// extrae su texto y elimina el archivo temporal del caché (`RN-10`).
  /// Retorna `null` si el usuario cancela la selección.
  Future<ContractDocumentCaptureResult?> pickDocumentFile({
    required String languageCode,
  });

  /// Carga un contrato sintético de prueba por su [sampleId] en el idioma activo (`es` o `en`).
  Future<ContractDocumentCaptureResult> loadSyntheticSample({
    required String sampleId,
    required String languageCode,
  });

  /// Elimina del caché cualquier archivo temporal asociado a [tempFilePath] (`RN-10`).
  /// Retorna `true` si el archivo fue eliminado o ya no existe en disco.
  Future<bool> deleteTemporaryFileIfPresent(String? tempFilePath);
}
