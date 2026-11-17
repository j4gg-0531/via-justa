import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_validator.dart';

class DeviceBusinessPhotoRepository implements BusinessPhotoRepository {
  DeviceBusinessPhotoRepository({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<BusinessPhoto?> pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const BusinessRegistrationFailure('photoInvalid');
    }
    final bytes = await file.readAsBytes();
    final extension = businessImageExtension(bytes);
    if (extension == null) {
      throw const BusinessRegistrationFailure('photoInvalid');
    }
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const BusinessRegistrationFailure('photoInvalid');
    }
    return BusinessPhoto(
      bytes: bytes,
      extension: extension,
      mimeType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
    );
  }
}
