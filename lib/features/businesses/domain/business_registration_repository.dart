import 'package:via_justa/features/businesses/domain/business_draft.dart';

abstract interface class BusinessRegistrationRepository {
  Future<String> publish({
    required BusinessDraft draft,
    required String requestId,
    required String ownerId,
    required String municipalityCode,
  });

  /// Cancela la preparación o devuelve el ID si el servidor ya la publicó.
  Future<String?> discard({required String requestId, required String ownerId});
}

abstract interface class BusinessPhotoRepository {
  Future<BusinessPhoto?> pickPhoto();
}
