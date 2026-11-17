/// Categoría comercial para clasificación en el directorio.
enum BusinessCategory {
  /// Restaurantes, cafeterías y comida típica
  food,

  /// Taxis, buses intermunicipales y transporte urbano
  transport,

  /// Hoteles, hostales y alojamientos
  lodging,

  /// Trámites, papelerías, asesorías y servicios profesionales
  services;

  /// Valor de filtro enviado al catálogo SQL (`public.get_business_catalog`).
  String get catalogFilterValue {
    switch (this) {
      case BusinessCategory.food:
        return 'food';
      case BusinessCategory.transport:
        return 'transport';
      case BusinessCategory.lodging:
        return 'lodging';
      case BusinessCategory.services:
        return 'services';
    }
  }
}

/// Entidad inmutable que representa un comercio o servicio en el directorio.
class Business {
  const Business({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.phone,
    required this.municipalityCode,
    this.type = 'service',
    this.ownerId,
    this.isVerified = false,
    this.description = '',
    this.descriptionEs = '',
    this.descriptionEn = '',
    this.latitude,
    this.longitude,
    this.whatsapp,
    this.hasWhatsapp = false,
    this.whatsappUrl,
    this.telUrl,
    this.mapsUrl,
    this.orderUrl,
    this.hasExternalOrder = false,
    this.coverPhotoPath,
    this.photosCount = 0,
    this.dishesCount = 0,
    this.minDishPriceCop,
  });

  final String id;
  final String name;
  final BusinessCategory category;
  final String address;
  final String phone;
  final String municipalityCode;
  final String type;
  final String? ownerId;
  final bool isVerified;
  final String description;
  final String descriptionEs;
  final String descriptionEn;
  final double? latitude;
  final double? longitude;
  final String? whatsapp;
  final bool hasWhatsapp;
  final String? whatsappUrl;
  final String? telUrl;
  final String? mapsUrl;
  final String? orderUrl;
  final bool hasExternalOrder;
  final String? coverPhotoPath;
  final int photosCount;
  final int dishesCount;
  final int? minDishPriceCop;

  /// Devuelve la descripción según el idioma activo, con respaldo a español.
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
