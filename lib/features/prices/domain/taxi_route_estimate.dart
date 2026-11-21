import 'dart:math' as math;

/// Identificador de categoría en catálogo SQL/DEMO para carreras mínimas urbanas en taxi.
const String kTaxiCategoryId = 'transport_taxi_minimal';

/// Monto sonda positivo enviado a `calculate_price_verdict` para consultar la mediana del trayecto.
const int kTaxiReferenceProbeCop = 10000;

/// Destino seleccionado en el mapa (punto libre tocado por el usuario o lugar existente).
class MapDestinationTarget {
  const MapDestinationTarget({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  final double latitude;
  final double longitude;
  final String? name;
}

/// Calcula la distancia geodésica en línea recta (km) mediante la fórmula de Haversine.
double calculateAirDistanceKm({
  required double originLatitude,
  required double originLongitude,
  required double destinationLatitude,
  required double destinationLongitude,
}) {
  const earthRadiusKm = 6371.0;
  final dLat = _degreesToRadians(destinationLatitude - originLatitude);
  final dLng = _degreesToRadians(destinationLongitude - originLongitude);
  final lat1 = _degreesToRadians(originLatitude);
  final lat2 = _degreesToRadians(destinationLatitude);

  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

/// Clasifica la distancia en el mismo rango de taxi definido en Supabase (`0_2_km`, `2_5_km`, `gt_5_km`).
String classifyTaxiDistanceRange(double distanceKm) {
  if (distanceKm <= 2.0) return '0_2_km';
  if (distanceKm <= 5.0) return '2_5_km';
  return 'gt_5_km';
}

/// Devuelve la clave de traducción legible para un código de rango de distancia de taxi.
String? taxiDistanceRangeTranslationKey(String? distanceRange) {
  switch (distanceRange) {
    case '0_2_km':
      return 'price_map.distance_range_short';
    case '2_5_km':
      return 'price_map.distance_range_medium';
    case 'gt_5_km':
      return 'price_map.distance_range_long';
    default:
      return null;
  }
}
