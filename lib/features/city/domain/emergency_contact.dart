import 'package:via_justa/core/security/external_uri_guard.dart';

/// Contacto oficial de emergencia con marcación directa segura (`tel:`).
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.phoneNumber,
    required this.displayNumber,
    this.isUrgent = false,
  });

  final String id;
  final String titleKey;
  final String descriptionKey;
  final String phoneNumber;
  final String displayNumber;
  final bool isUrgent;

  /// URI `tel:` validado por [ExternalUriGuard] (incluye líneas cortas oficiales como `123`).
  Uri? get safeTelUri => ExternalUriGuard.buildSafeEmergencyTelUri(phoneNumber);
}

/// Directorio curado de líneas de emergencia para el piloto Valledupar (`20001`).
const List<EmergencyContact> kValleduparEmergencyContacts = <EmergencyContact>[
  EmergencyContact(
    id: 'national_123',
    titleKey: 'city.emergency_123_title',
    descriptionKey: 'city.emergency_123_desc',
    phoneNumber: '123',
    displayNumber: '123',
    isUrgent: true,
  ),
  EmergencyContact(
    id: 'tourism_police',
    titleKey: 'city.emergency_tourism_title',
    descriptionKey: 'city.emergency_tourism_desc',
    phoneNumber: '6055748800',
    displayNumber: '605 574 8800',
  ),
  EmergencyContact(
    id: 'red_cross',
    titleKey: 'city.emergency_redcross_title',
    descriptionKey: 'city.emergency_redcross_desc',
    phoneNumber: '6055712255',
    displayNumber: '605 571 2255',
  ),
  EmergencyContact(
    id: 'hospital_rosario',
    titleKey: 'city.emergency_hospital_title',
    descriptionKey: 'city.emergency_hospital_desc',
    phoneNumber: '6055748400',
    displayNumber: '605 574 8400',
  ),
];
