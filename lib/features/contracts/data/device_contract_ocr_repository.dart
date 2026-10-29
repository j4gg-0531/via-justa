import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:via_justa/features/contracts/data/local_contract_ocr_repository.dart';
import 'package:via_justa/features/contracts/domain/contract_capture.dart';
import 'package:via_justa/features/contracts/domain/contract_ocr_repository.dart';

/// Archivo elegido con el selector del sistema, ya copiado por el plugin a una ruta local.
class PickedContractFile {
  const PickedContractFile({required this.name, required this.path});

  /// Nombre original del archivo (con extensión), usado para validar el formato.
  final String name;

  /// Ruta local de la copia temporal en caché que deja `file_picker` (se borra por `RN-10`).
  final String path;
}

/// Abre la cámara y retorna la ruta del JPG temporal, o `null` si el usuario cancela.
typedef CameraImagePicker = Future<String?> Function();

/// Abre el selector de archivos y retorna el archivo elegido, o `null` si el usuario cancela.
typedef ContractFilePicker = Future<PickedContractFile?> Function();

/// Ejecuta OCR local sobre la imagen en [imagePath] y retorna el texto reconocido.
typedef ImageTextRecognizer = Future<String> Function(String imagePath);

/// Limpia la carpeta de caché que administra el selector de archivos.
typedef PickerCacheCleaner = Future<void> Function();

/// Extensiones que se muestran en el selector. `pdf` se incluye a propósito para que el
/// usuario reciba el aviso "Próximamente" en vez de no ver su archivo.
const List<String> contractPickerExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'txt',
  'pdf',
];

/// Implementación real de [ContractOcrRepository] (`VJ-13` Paso B).
///
/// - Cámara: `image_picker` (intent del sistema; no requiere permiso `CAMERA`).
/// - Archivos: `file_picker` (selector del sistema/SAF; no requiere permisos de almacenamiento).
/// - OCR: `google_mlkit_text_recognition` en el dispositivo (alfabeto latino, sin red).
/// - `RN-10`: el archivo temporal que dejan los plugins se borra en `finally`, haya éxito o error,
///   y se limpia la caché de `file_picker`.
///
/// Los contratos sintéticos (ES/EN) se delegan a [LocalContractOcrRepository] para que las
/// pruebas y el emulador sigan funcionando sin cámara ni archivos reales.
///
/// Los colaboradores de plataforma son inyectables para probar la lógica sin canales nativos.
class DeviceContractOcrRepository implements ContractOcrRepository {
  DeviceContractOcrRepository({
    CameraImagePicker? pickCameraImage,
    ContractFilePicker? pickContractFile,
    ImageTextRecognizer? recognizeImageText,
    PickerCacheCleaner? clearFilePickerCache,
    this.cacheDirectory,
    LocalContractOcrRepository? syntheticRepository,
  }) : _pickCameraImage = pickCameraImage ?? _pickImageWithCamera,
       _pickContractFile = pickContractFile ?? _pickFileWithSystemPicker,
       _recognizeImageText = recognizeImageText ?? _recognizeWithMlKit,
       _clearFilePickerCache = clearFilePickerCache ?? FilePicker.clearTemporaryFiles,
       _syntheticRepository = syntheticRepository ?? LocalContractOcrRepository();

  final CameraImagePicker _pickCameraImage;
  final ContractFilePicker _pickContractFile;
  final ImageTextRecognizer _recognizeImageText;
  final PickerCacheCleaner _clearFilePickerCache;
  /// Carpeta de caché donde image_picker deja sus archivos; inyectable para pruebas.
  final Directory? cacheDirectory;
  final LocalContractOcrRepository _syntheticRepository;

  /// Prefijos de los archivos que `image_picker` crea en la caché de la app al usar la cámara.
  static const List<String> _imagePickerCachePrefixes = <String>[
    'image_picker',
    'scaled_image_picker',
  ];

  @override
  List<SyntheticContractSample> getSyntheticSamples() =>
      _syntheticRepository.getSyntheticSamples();

  @override
  Future<ContractDocumentCaptureResult> loadSyntheticSample({
    required String sampleId,
    required String languageCode,
  }) {
    return _syntheticRepository.loadSyntheticSample(
      sampleId: sampleId,
      languageCode: languageCode,
    );
  }

  @override
  Future<ContractDocumentCaptureResult?> captureFromCamera({
    required String languageCode,
  }) async {
    final String? photoPath;
    try {
      photoPath = await _pickCameraImage();
    } catch (_) {
      _deleteCameraLeftovers();
      rethrow;
    }
    if (photoPath == null) {
      // Al cancelar, image_picker puede dejar el JPG vacío que preparó para la cámara.
      _deleteCameraLeftovers();
      return null;
    }
    return _extractAndDelete(
      source: ContractInputSource.cameraPhoto,
      fileName: _baseName(photoPath),
      filePath: photoPath,
      fromFilePicker: false,
    );
  }

  @override
  Future<ContractDocumentCaptureResult?> pickDocumentFile({
    required String languageCode,
  }) async {
    final PickedContractFile? picked;
    try {
      picked = await _pickContractFile();
    } catch (_) {
      await _safeClearFilePickerCache();
      rethrow;
    }
    if (picked == null) {
      return null;
    }
    return _extractAndDelete(
      source: ContractInputSource.documentFile,
      fileName: picked.name,
      filePath: picked.path,
      fromFilePicker: true,
    );
  }

  @override
  Future<bool> deleteTemporaryFileIfPresent(String? tempFilePath) async {
    final deleted = _deleteFileSync(tempFilePath);
    if (tempFilePath != null && tempFilePath.contains('file_picker')) {
      await _safeClearFilePickerCache();
    }
    return deleted;
  }

  /// Lee el texto (TXT) o ejecuta OCR (JPG/PNG) solo si el formato y el tamaño son válidos.
  /// El archivo temporal se borra SIEMPRE en `finally` (`RN-10`).
  Future<ContractDocumentCaptureResult> _extractAndDelete({
    required ContractInputSource source,
    required String fileName,
    required String filePath,
    required bool fromFilePicker,
  }) async {
    var sizeBytes = 0;
    var text = '';
    var deleted = false;
    try {
      final file = File(filePath);
      sizeBytes = file.existsSync() ? file.lengthSync() : 0;
      final canRead =
          validateContractFileExtension(fileName) == null &&
          validateContractFileSize(sizeBytes) == null;
      if (canRead) {
        text = extractFileExtension(fileName) == 'txt'
            ? utf8.decode(file.readAsBytesSync(), allowMalformed: true)
            : await _recognizeImageText(filePath);
      }
    } finally {
      deleted = _deleteFileSync(filePath);
      if (fromFilePicker) {
        await _safeClearFilePickerCache();
      }
    }

    return ContractDocumentCaptureResult(
      source: source,
      fileName: fileName,
      fileSizeBytes: sizeBytes,
      extractedText: text,
      tempFilePath: filePath,
      wasTempFileDeleted: deleted,
    );
  }

  Future<void> _safeClearFilePickerCache() async {
    try {
      await _clearFilePickerCache();
    } catch (_) {
      // Sin selector disponible (p. ej. pruebas); el archivo puntual ya se borró.
    }
  }

  /// Borra los JPG que `image_picker` deja en la caché de la app (cancelación o error).
  void _deleteCameraLeftovers() {
    try {
      final dir = cacheDirectory ?? _resolveAppCacheDirectory();
      if (!dir.existsSync()) {
        return;
      }
      for (final entity in dir.listSync()) {
        if (entity is! File) {
          continue;
        }
        final name = _baseName(entity.path);
        final isImagePickerFile = _imagePickerCachePrefixes.any(name.startsWith);
        if (isImagePickerFile) {
          _deleteFileSync(entity.path);
        }
      }
    } catch (_) {
      // La limpieza de restos es de mejor esfuerzo.
    }
  }

  /// En Android, `Directory.systemTemp` apunta a `<datos-app>/code_cache`, mientras que
  /// `image_picker` escribe en `<datos-app>/cache`. Sin agregar `path_provider`, se deduce
  /// la carpeta hermana `cache`; en otras plataformas se usa la carpeta temporal del sistema.
  static Directory _resolveAppCacheDirectory() {
    final systemTemp = Directory.systemTemp;
    if (_baseName(systemTemp.path) == 'code_cache') {
      return Directory('${systemTemp.parent.path}${Platform.pathSeparator}cache');
    }
    return systemTemp;
  }

  static bool _deleteFileSync(String? path) {
    if (path == null || path.trim().isEmpty) {
      return true;
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      return !file.existsSync();
    } catch (_) {
      return false;
    }
  }

  static String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  static Future<String?> _pickImageWithCamera() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return photo?.path;
  }

  static Future<PickedContractFile?> _pickFileWithSystemPicker() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: contractPickerExtensions,
    );
    if (picked == null) {
      return null;
    }
    final path = picked.path;
    if (path == null) {
      throw const FileSystemException('El selector no entregó una ruta local');
    }
    return PickedContractFile(name: picked.name, path: path);
  }

  static Future<String> _recognizeWithMlKit(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return recognized.text;
    } finally {
      await recognizer.close();
    }
  }
}
