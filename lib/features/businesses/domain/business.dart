/// Categoría comercial para clasificación en el directorio.
enum BusinessCategory {
  /// Restaurantes, cafeterías y comida típica
  food,

  /// Taxis, buses intermunicipales y transporte urbano
  transport,

  /// Hoteles, hostales y alojamientos
  lodging,

  /// Trámites, papelerías, asesorías y servicios profesionales
  services,
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
    this.ownerId,
    this.isVerified = false,
    this.description = '',
    this.descriptionEs = '',
    this.descriptionEn = '',
  });

  final String id;
  final String name;
  final BusinessCategory category;
  final String address;
  final String phone;
  final String municipalityCode;
  final String? ownerId;
  final bool isVerified;
  final String description;
  final String descriptionEs;
  final String descriptionEn;

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
