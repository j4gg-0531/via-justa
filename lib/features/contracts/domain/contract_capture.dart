/// Origen de captura o entrada del texto de un contrato en `VJ-13`.
enum ContractInputSource {
  /// Fotografía capturada con la cámara del dispositivo (JPG/PNG).
  cameraPhoto,

  /// Imagen o archivo de texto seleccionado del almacenamiento (JPG, PNG, TXT).
  documentFile,

  /// Contrato sintético de prueba incluido para demostración y pruebas seguras.
  syntheticSample,

  /// Texto escrito o pegado manualmente por el usuario.
  manualEntry,
}

/// Estados del flujo de captura y preparación local de contratos (`VJ-13`).
/// El flujo termina en [readyForAnalysis]; no existe estado `analyzing` en `VJ-13`.
enum ContractCaptureStatus {
  /// Sin documento cargado.
  idle,

  /// Leyendo el archivo o ejecutando OCR local en el dispositivo.
  readingDocument,

  /// Texto extraído, validado y listo para ser analizado en `VJ-14`.
  readyForAnalysis,

  /// Error de validación (formato, tamaño, ilegible o exceso de 15.000 caracteres).
  error,
}

/// Códigos de error tipados para la captura y validación local de contratos.
enum ContractCaptureError {
  /// Formato no soportado en el MVP (solo se admiten JPG, JPEG, PNG y TXT).
  unsupportedFormat,

  /// Los archivos PDF están marcados como "Próximamente" porque ML Kit OCR procesa imágenes.
  pdfComingSoon,

  /// El archivo supera el tamaño máximo permitido de 10 MB.
  fileTooLarge,

  /// El texto extraído está vacío o es demasiado corto/ilegible (< 20 caracteres).
  emptyOrIllegibleText,

  /// El texto supera el límite de 15.000 caracteres; se advierte y exige recorte manual sin truncar.
  exceedsMaxLength,

  /// Falla inesperada al leer el archivo o ejecutar el OCR local.
  readFailed,
}

/// Tamaño máximo de archivo permitido para captura de contratos: 10 MB.
const int maxContractFileSizeBytes = 10 * 1024 * 1024;

/// Mínimo de caracteres útiles para considerar legible un contrato extraído.
const int minContractCharacters = 20;

/// Límite máximo de caracteres permitido para el texto del contrato: 15.000 caracteres.
/// Si se supera, no se trunca en silencio: se advierte al usuario y se exige recortarlo.
const int maxContractCharacters = 15000;

/// Extensiones admitidas en el MVP para captura de contratos (`VJ-13`).
const Set<String> supportedContractExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'txt',
};

/// Extrae la extensión en minúsculas (sin punto) a partir del nombre o ruta de un archivo.
String extractFileExtension(String fileNameOrPath) {
  final trimmed = fileNameOrPath.trim();
  final dotIndex = trimmed.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == trimmed.length - 1) {
    return '';
  }
  return trimmed.substring(dotIndex + 1).toLowerCase();
}

/// Valida que la extensión del archivo corresponda a los formatos del MVP (`JPG`, `PNG`, `TXT`).
/// Si el archivo es `PDF`, retorna [ContractCaptureError.pdfComingSoon].
ContractCaptureError? validateContractFileExtension(String fileNameOrPath) {
  final ext = extractFileExtension(fileNameOrPath);
  if (ext.isEmpty) {
    return ContractCaptureError.unsupportedFormat;
  }
  if (ext == 'pdf') {
    return ContractCaptureError.pdfComingSoon;
  }
  if (!supportedContractExtensions.contains(ext)) {
    return ContractCaptureError.unsupportedFormat;
  }
  return null;
}

/// Valida que el tamaño del archivo esté entre 1 byte y 10 MB ([maxContractFileSizeBytes]).
ContractCaptureError? validateContractFileSize(int sizeInBytes) {
  if (sizeInBytes <= 0) {
    return ContractCaptureError.emptyOrIllegibleText;
  }
  if (sizeInBytes > maxContractFileSizeBytes) {
    return ContractCaptureError.fileTooLarge;
  }
  return null;
}

/// Normaliza saltos de línea y espacios extremos del texto extraído por OCR
/// **sin truncar jamás su contenido**.
String normalizeExtractedContractText(String rawText) {
  final unifiedNewlines = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final collapsedBlankLines = unifiedNewlines.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return collapsedBlankLines.trim();
}

/// Valida la longitud del texto del contrato (entre [minContractCharacters] y [maxContractCharacters]).
/// Si supera los 15.000 caracteres, devuelve [ContractCaptureError.exceedsMaxLength]
/// para exigir recorte manual sin truncar en silencio.
ContractCaptureError? validateContractText(String text) {
  final normalized = normalizeExtractedContractText(text);
  if (normalized.length < minContractCharacters) {
    return ContractCaptureError.emptyOrIllegibleText;
  }
  if (normalized.length > maxContractCharacters) {
    return ContractCaptureError.exceedsMaxLength;
  }
  return null;
}

/// Contrato sintético de prueba bilingüe (ES/EN) sin datos personales reales
/// (cumple la política de privacidad de datos y RN-10).
class SyntheticContractSample {
  const SyntheticContractSample({
    required this.id,
    required this.fileName,
    required this.titleEs,
    required this.titleEn,
    required this.descriptionEs,
    required this.descriptionEn,
    required this.contentEs,
    required this.contentEn,
  });

  final String id;
  final String fileName;
  final String titleEs;
  final String titleEn;
  final String descriptionEs;
  final String descriptionEn;
  final String contentEs;
  final String contentEn;

  String localizedTitle(String languageCode) =>
      languageCode == 'en' ? titleEn : titleEs;

  String localizedDescription(String languageCode) =>
      languageCode == 'en' ? descriptionEn : descriptionEs;

  String localizedContent(String languageCode) =>
      languageCode == 'en' ? contentEn : contentEs;
}

/// Resultado de una captura o extracción local de texto de contrato.
class ContractDocumentCaptureResult {
  const ContractDocumentCaptureResult({
    required this.source,
    required this.fileName,
    required this.fileSizeBytes,
    required this.extractedText,
    this.tempFilePath,
    this.wasTempFileDeleted = false,
  });

  final ContractInputSource source;
  final String fileName;
  final int fileSizeBytes;
  final String extractedText;

  /// Ruta del archivo temporal creado en caché durante la captura/OCR (si aplica).
  final String? tempFilePath;

  /// Indica si el archivo temporal de caché fue eliminado tras el OCR conforme a `RN-10`.
  final bool wasTempFileDeleted;

  ContractDocumentCaptureResult copyWith({
    ContractInputSource? source,
    String? fileName,
    int? fileSizeBytes,
    String? extractedText,
    String? tempFilePath,
    bool? wasTempFileDeleted,
  }) {
    return ContractDocumentCaptureResult(
      source: source ?? this.source,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      extractedText: extractedText ?? this.extractedText,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      wasTempFileDeleted: wasTempFileDeleted ?? this.wasTempFileDeleted,
    );
  }
}
