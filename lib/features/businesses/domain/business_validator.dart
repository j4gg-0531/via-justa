import 'package:via_justa/features/businesses/domain/business_draft.dart';

String normalizeBusinessPhone(String value, {bool whatsapp = false}) =>
    value.replaceAll(RegExp(whatsapp ? r'[\s()+.\-]' : r'[\s().\-]'), '');

bool isValidBusinessOrderUrl(String value) {
  if (value.trim().isEmpty) return true;
  return value.trim().length <= 500 &&
      RegExp(
        r'''^https://[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+(:[0-9]{2,5})?(/[^\s<>"'`\\]*)?$''',
      ).hasMatch(value.trim());
}

String? validateBusinessStep(BusinessDraft draft, int step) {
  String text(BusinessField field) => draft.text(field).trim();
  switch (step) {
    case 0:
      final name = text(BusinessField.name);
      if (name.length < 3 ||
          name.length > 120 ||
          !RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(name) ||
          RegExp(r'[<>\x00-\x1f]').hasMatch(name) ||
          name.toLowerCase().startsWith('[demo]')) {
        return 'name';
      }
      for (final field in [
        BusinessField.descriptionEs,
        BusinessField.descriptionEn,
      ]) {
        final description = text(field);
        if (field == BusinessField.descriptionEn && description.isEmpty) {
          continue;
        }
        if (description.length < 20 ||
            description.length > 1000 ||
            RegExp(r'<[^>]*>').hasMatch(description)) {
          return 'description';
        }
      }
      return null;
    case 1:
      if (draft.latitude == null ||
          draft.longitude == null ||
          draft.zoneId == null ||
          !draft.latitude!.isFinite ||
          !draft.longitude!.isFinite ||
          draft.latitude!.abs() > 90 ||
          draft.longitude!.abs() > 180) {
        return 'location';
      }
      final address = text(BusinessField.address);
      if (address.length < 5 ||
          address.length > 200 ||
          RegExp(r'[<>\x00-\x1f]').hasMatch(address)) {
        return 'address';
      }
      final phone = normalizeBusinessPhone(text(BusinessField.phone));
      final whatsapp = normalizeBusinessPhone(
        text(BusinessField.whatsapp),
        whatsapp: true,
      );
      if (phone.isEmpty && whatsapp.isEmpty) return 'contact';
      if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
        return 'phone';
      }
      if (whatsapp.isNotEmpty &&
          !RegExp(r'^[1-9][0-9]{9,14}$').hasMatch(whatsapp)) {
        return 'whatsapp';
      }
      if (whatsapp.isNotEmpty && !draft.whatsappConsent) {
        return 'whatsappConsent';
      }
      return null;
    case 2:
      if (!isValidBusinessOrderUrl(text(BusinessField.orderUrl))) return 'url';
      if (draft.photos.length > 5) return 'photos';
      if (draft.dishes.length > 5) return 'dishes';
      for (final dish in draft.dishes) {
        final price = int.tryParse(dish.price);
        if (dish.name.trim().length < 2 ||
            dish.name.trim().length > 100 ||
            RegExp(r'[<>\x00-\x1f]').hasMatch(dish.name) ||
            price == null ||
            price < 500 ||
            price > 20000000) {
          return 'dish';
        }
      }
      final time = RegExp(r'^(?:(?:[01][0-9]|2[0-3]):[0-5][0-9]|24:00)$');
      for (final hours in draft.hours.values) {
        if (hours.enabled &&
            (!time.hasMatch(hours.open) ||
                !time.hasMatch(hours.close) ||
                hours.open == hours.close)) {
          return 'hours';
        }
      }
      return null;
    case 3:
      return draft.publicationConsent ? null : 'publicationConsent';
    default:
      throw RangeError.range(step, 0, 3);
  }
}

/// Inspección de firma, adicional a la decodificación real en el adaptador.
String? businessImageExtension(List<int> bytes) {
  if (bytes.length < 12 || bytes.length > 5 * 1024 * 1024) return null;
  if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'jpg';
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (List.generate(
    8,
    (index) => bytes[index] == png[index],
  ).every((value) => value)) {
    return 'png';
  }
  if (String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'webp';
  }
  return null;
}
