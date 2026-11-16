/// Guardián puro de validación de URIs e Intents salientes (Corrección H-04 / OWASP M4 y M8).
///
/// Impide:
/// - Abrir esquemas inseguros (`http://`, `javascript:`, `file://`, `content://`, `intent://`).
/// - Inyección de códigos USSD/MMI (`*`, `#`, `,`, `;`) en llamadas telefónicas (`tel:`).
/// - Coordenadas fuera del territorio colombiano o valores `NaN`/`Infinity` en rutas de Google Maps.
class ExternalUriGuard {
  const ExternalUriGuard._();

  static const double minColombiaLatitude = -4.5;
  static const double maxColombiaLatitude = 13.5;
  static const double minColombiaLongitude = -82.0;
  static const double maxColombiaLongitude = -66.0;

  static final RegExp _e164OrNationalPhonePattern = RegExp(r'^\+?[0-9]{7,15}$');
  static final RegExp _formattingSeparators = RegExp(r'[\s\-\(\)\.]');

  /// Verifica si las coordenadas están dentro de los límites continentales/insulares de Colombia.
  static bool isValidColombiaCoordinate({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }
    return latitude >= minColombiaLatitude &&
        latitude <= maxColombiaLatitude &&
        longitude >= minColombiaLongitude &&
        longitude <= maxColombiaLongitude;
  }

  /// Construye un URI `https://www.google.com/maps/dir/` seguro si las coordenadas son válidas.
  static Uri? buildSafeGoogleMapsDirectionsUri({
    required double latitude,
    required double longitude,
  }) {
    if (!isValidColombiaCoordinate(latitude: latitude, longitude: longitude)) {
      return null;
    }
    final destination =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    return Uri.https('www.google.com', '/maps/dir/', <String, String>{
      'api': '1',
      'destination': destination,
    });
  }

  /// Construye un URI `tel:` seguro rechazando caracteres de control o códigos USSD (`*`, `#`).
  static Uri? buildSafeTelUri(String? rawPhone) {
    if (rawPhone == null) return null;
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return null;

    // Si contiene caracteres distintos a dígitos, '+' inicial o separadores comunes,
    // se rechaza en vez de recortar silenciosamente (evita inyección USSD como *#06#).
    final compact = trimmed.replaceAll(_formattingSeparators, '');
    if (!_e164OrNationalPhonePattern.hasMatch(compact)) {
      return null;
    }
    return Uri(scheme: 'tel', path: compact);
  }

  /// Valida cualquier URI externo antes de invocar `launchUrl`.
  static bool isAllowedExternalUri(Uri? uri) {
    if (uri == null) return false;
    switch (uri.scheme.toLowerCase()) {
      case 'https':
        return uri.host.isNotEmpty &&
            !uri.host.contains(' ') &&
            uri.userInfo.isEmpty;
      case 'tel':
        return _e164OrNationalPhonePattern.hasMatch(uri.path);
      case 'geo':
        return uri.path.isNotEmpty || uri.query.isNotEmpty;
      default:
        return false;
    }
  }
}
