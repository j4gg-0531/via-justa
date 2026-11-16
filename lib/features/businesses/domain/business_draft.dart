import 'dart:typed_data';

enum BusinessField {
  name,
  descriptionEs,
  descriptionEn,
  address,
  phone,
  whatsapp,
  orderUrl,
}

enum BusinessType { restaurant, hotel, service, handicraft, transport }

class BusinessPhoto {
  const BusinessPhoto({
    required this.bytes,
    required this.extension,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String extension;
  final String mimeType;
}

class BusinessDishDraft {
  const BusinessDishDraft({this.name = '', this.price = ''});
  final String name;
  final String price;
}

class BusinessDayHours {
  const BusinessDayHours({
    this.enabled = false,
    this.open = '08:00',
    this.close = '18:00',
  });
  final bool enabled;
  final String open;
  final String close;
}

/// Borrador inmutable del formulario. Los horarios usan claves del contrato SQL.
class BusinessDraft {
  const BusinessDraft({
    this.fields = const {},
    this.type = BusinessType.restaurant,
    this.latitude,
    this.longitude,
    this.zoneId,
    this.whatsappConsent = false,
    this.publicationConsent = false,
    this.hours = const {},
    this.dishes = const [],
    this.photos = const [],
  });
  static const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final Map<BusinessField, String> fields;
  final BusinessType type;
  final double? latitude;
  final double? longitude;
  final String? zoneId;
  final bool whatsappConsent;
  final bool publicationConsent;
  final Map<String, BusinessDayHours> hours;
  final List<BusinessDishDraft> dishes;
  final List<BusinessPhoto> photos;

  String text(BusinessField field) => fields[field] ?? '';

  BusinessDraft copyWith({
    Map<BusinessField, String>? fields,
    BusinessType? type,
    double? latitude,
    double? longitude,
    String? zoneId,
    bool? whatsappConsent,
    bool? publicationConsent,
    Map<String, BusinessDayHours>? hours,
    List<BusinessDishDraft>? dishes,
    List<BusinessPhoto>? photos,
  }) => BusinessDraft(
    fields: Map.unmodifiable(fields ?? this.fields),
    type: type ?? this.type,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    zoneId: zoneId ?? this.zoneId,
    whatsappConsent: whatsappConsent ?? this.whatsappConsent,
    publicationConsent: publicationConsent ?? this.publicationConsent,
    hours: Map.unmodifiable(hours ?? this.hours),
    dishes: List.unmodifiable(dishes ?? this.dishes),
    photos: List.unmodifiable(photos ?? this.photos),
  );
}

class BusinessRegistrationFailure implements Exception {
  const BusinessRegistrationFailure(this.key);
  final String key;
}
