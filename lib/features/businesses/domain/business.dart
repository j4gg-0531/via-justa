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
    this.isVerified = true,
    this.description = '',
  });

  final String id;
  final String name;
  final BusinessCategory category;
  final String address;
  final String phone;
  final String municipalityCode;
  final bool isVerified;
  final String description;
}
