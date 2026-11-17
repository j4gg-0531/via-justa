import 'dart:typed_data';

import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';

/// Foto publicada asociada a la ficha de un negocio.
class BusinessPhotoItem {
  const BusinessPhotoItem({
    required this.id,
    required this.storagePath,
    this.position = 0,
    this.isCover = false,
    this.bytes,
  });

  final String id;
  final String storagePath;
  final int position;
  final bool isCover;
  final Uint8List? bytes;
}

/// Plato o servicio destacado en la ficha de un negocio.
class BusinessDishItem {
  const BusinessDishItem({
    required this.id,
    required this.name,
    required this.priceCop,
    this.description,
  });

  final String id;
  final String name;
  final int priceCop;
  final String? description;

  String get formattedPriceCop => formatCopAmount(priceCop);
}

/// Franja horaria por día lista para presentar en la vista sin lógica adicional.
class BusinessDaySchedule {
  const BusinessDaySchedule({
    required this.dayKey,
    required this.rangesText,
    required this.isOpen,
  });

  final String dayKey;
  final String rangesText;
  final bool isOpen;
}

/// Formatea un monto entero en pesos colombianos (ej. `15000` -> `$15.000 COP`).
String formatCopAmount(int amountCop) {
  final digits = amountCop.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return '\$${buffer.toString()} COP';
}

/// Construye la lista ordenada de horarios (`mon..sun`) a partir del JSON de horarios.
List<BusinessDaySchedule> buildBusinessSchedule(Map<String, dynamic>? rawHours) {
  if (rawHours == null || rawHours.isEmpty) {
    return const <BusinessDaySchedule>[];
  }
  final schedule = <BusinessDaySchedule>[];
  var anyOpen = false;

  for (final day in BusinessDraft.days) {
    final dynamic rawRanges = rawHours[day];
    final parts = <String>[];
    if (rawRanges is List) {
      for (final dynamic item in rawRanges) {
        if (item is Map) {
          final open = (item['open'] as String?)?.trim() ?? '';
          final close = (item['close'] as String?)?.trim() ?? '';
          if (open.isNotEmpty && close.isNotEmpty) {
            parts.add('$open – $close');
          }
        }
      }
    }
    if (parts.isNotEmpty) {
      anyOpen = true;
    }
    schedule.add(
      BusinessDaySchedule(
        dayKey: day,
        rangesText: parts.join(', '),
        isOpen: parts.isNotEmpty,
      ),
    );
  }

  return anyOpen ? schedule : const <BusinessDaySchedule>[];
}

/// Entidad inmutable que representa la ficha completa de un negocio (VJ-17).
class BusinessDetail {
  const BusinessDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.municipalityCode,
    required this.description,
    required this.address,
    this.ownerId,
    this.descriptionEs = '',
    this.descriptionEn = '',
    this.latitude,
    this.longitude,
    this.phone,
    this.whatsapp,
    this.orderUrl,
    this.whatsappUrl,
    this.telUrl,
    this.mapsUrl,
    this.canCall = false,
    this.canWhatsapp = false,
    this.canDirections = false,
    this.canOrderExternal = false,
    this.externalOrderDisclaimer = '',
    this.schedule = const <BusinessDaySchedule>[],
    this.photos = const <BusinessPhotoItem>[],
    this.dishes = const <BusinessDishItem>[],
    this.ratingAverage,
    this.ratingCount = 0,
    this.myRating,
    this.isOwner = false,
  });

  factory BusinessDetail.fromBusiness(Business business, {String localeCode = 'es'}) {
    final desc = business.localizedDescription(localeCode);
    final hasOrder =
        business.hasExternalOrder ||
        (business.orderUrl != null && business.orderUrl!.trim().isNotEmpty);
    final hasWa =
        business.hasWhatsapp ||
        (business.whatsappUrl != null &&
            business.whatsappUrl!.trim().isNotEmpty);
    final hasMaps =
        (business.mapsUrl != null && business.mapsUrl!.trim().isNotEmpty) ||
        (business.latitude != null && business.longitude != null);
    final hasCall =
        (business.telUrl != null && business.telUrl!.trim().isNotEmpty) ||
        business.phone.trim().isNotEmpty;

    return BusinessDetail(
      id: business.id,
      ownerId: business.ownerId,
      name: business.name,
      type: business.type,
      category: business.category,
      municipalityCode: business.municipalityCode,
      description: desc,
      descriptionEs: business.descriptionEs.isNotEmpty
          ? business.descriptionEs
          : desc,
      descriptionEn: business.descriptionEn.isNotEmpty
          ? business.descriptionEn
          : desc,
      address: business.address,
      latitude: business.latitude,
      longitude: business.longitude,
      phone: business.phone.trim().isEmpty ? null : business.phone.trim(),
      whatsapp: business.whatsapp,
      orderUrl: business.orderUrl,
      whatsappUrl: business.whatsappUrl,
      telUrl: business.telUrl,
      mapsUrl: business.mapsUrl,
      canCall: hasCall,
      canWhatsapp: hasWa,
      canDirections: hasMaps,
      canOrderExternal: hasOrder,
      ratingCount: 0,
    );
  }

  final String id;
  final String? ownerId;
  final String name;
  final String type;
  final BusinessCategory category;
  final String municipalityCode;
  final String description;
  final String descriptionEs;
  final String descriptionEn;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? whatsapp;
  final String? orderUrl;
  final String? whatsappUrl;
  final String? telUrl;
  final String? mapsUrl;
  final bool canCall;
  final bool canWhatsapp;
  final bool canDirections;
  final bool canOrderExternal;
  final String externalOrderDisclaimer;
  final List<BusinessDaySchedule> schedule;
  final List<BusinessPhotoItem> photos;
  final List<BusinessDishItem> dishes;
  final double? ratingAverage;
  final int ratingCount;
  final int? myRating;
  final bool isOwner;

  bool get hasRatings => ratingCount > 0 && ratingAverage != null;

  String get formattedRatingAverage =>
      ratingAverage == null ? '' : ratingAverage!.toStringAsFixed(1).replaceAll('.', ',');

  /// Devuelve la descripción localizada según el idioma activo, con respaldo a español.
  String localizedDescription(String localeCode) {
    final isEn = localeCode.toLowerCase().startsWith('en');
    if (isEn && descriptionEn.trim().isNotEmpty) {
      return descriptionEn.trim();
    }
    if (descriptionEs.trim().isNotEmpty) {
      return descriptionEs.trim();
    }
    return description.trim();
  }
}
