/// Coordenadas centrales de referencia para Valledupar (municipio piloto 20001).
const double kValleduparCenterLat = 10.4742;
const double kValleduparCenterLng = -73.2436;

/// Categoría principal de elementos visibles en el mapa local del municipio (M08 / VJ-12).
enum PriceMapCategory {
  /// Reportes comunitarios de precios con semáforo
  prices,

  /// Servicios locales, negocios aprobados y salud (hospitales, clínicas, comercios)
  services,

  /// Puntos de orientación migratoria y consulados
  consulates,
}

/// Estado visual del marcador en el mapa local.
enum PricePinStatus {
  /// Precio dentro del rango de referencia (semáforo verde)
  fair,

  /// Precio moderadamente por encima de la referencia (semáforo ámbar)
  moderate,

  /// Precio con sobrecobro significativo (semáforo rojo)
  alert,

  /// Punto informativo de servicio, negocio o institución (sin semáforo de precio)
  info,
}

/// Tipo semántico de ícono para el marcador y la tarjeta del mapa local.
enum PriceMapPinKind {
  food,
  transport,
  lodging,
  hospital,
  assistance,
  consulate,
}

/// Rectángulo geográfico (bounding box) del área visible del mapa para acotar consultas.
class MapViewportBounds {
  const MapViewportBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}

/// Entidad inmutable que representa un marcador de precio, servicio o negocio en el mapa del municipio (M08 / VJ-12).
class PriceMapItem {
  const PriceMapItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pinKind,
    required this.status,
    required this.pinLabel,
    required this.badgeText,
    required this.normalizedX,
    required this.normalizedY,
    required this.municipalityCode,
    this.latitude = kValleduparCenterLat,
    this.longitude = kValleduparCenterLng,
    this.phone,
    this.whatsapp,
    this.address,
    this.sourceType = 'price_report',
    this.isDemo = true,
  });

  final String id;

  /// Nombre del punto, negocio, servicio o referencia de precio.
  final String name;

  /// Descripción corta del servicio, negocio o contexto del precio de referencia.
  final String description;

  final PriceMapCategory category;
  final PriceMapPinKind pinKind;
  final PricePinStatus status;

  /// Texto corto que se muestra en el globo del marcador (ej. "$12k", "$45k" o vacío si es solo ícono).
  final String pinLabel;

  /// Etiqueta de distancia, dirección o precio para la tarjeta inferior (ej. "2.4 km" o "$12.000").
  final String badgeText;

  /// Posición horizontal relativa (0.0 a 1.0) en el lienzo de respaldo.
  final double normalizedX;

  /// Posición vertical relativa (0.0 a 1.0) en el lienzo de respaldo.
  final double normalizedY;

  /// Código DIVIPOLA del municipio al que pertenece el punto.
  final String municipalityCode;

  /// Latitud WGS84 del marcador en el mapa real.
  final double latitude;

  /// Longitud WGS84 del marcador en el mapa real.
  final double longitude;

  /// Teléfono de contacto (opcional, para negocios y servicios).
  final String? phone;

  /// Número de WhatsApp con código de país (opcional, para negocios).
  final String? whatsapp;

  /// Dirección o referencia de ubicación (opcional).
  final String? address;

  /// Origen del registro (`'price_report'` o `'business'`).
  final String sourceType;

  /// Indica si el registro corresponde a un dato demostrativo (DEMO).
  final bool isDemo;

  /// Coordenada horizontal en rango de alineación [-1.0, 1.0].
  double get alignmentX => (normalizedX * 2) - 1;

  /// Coordenada vertical en rango de alineación [-1.0, 1.0].
  double get alignmentY => (normalizedY * 2) - 1;

  /// Indica si el elemento cuenta con un número telefónico o WhatsApp llamable.
  bool get hasCallableContact =>
      (phone != null && phone!.trim().isNotEmpty) ||
      (whatsapp != null && whatsapp!.trim().isNotEmpty);
}
