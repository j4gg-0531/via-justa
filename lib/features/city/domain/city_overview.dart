import 'package:via_justa/core/security/external_uri_guard.dart';

/// Secciones curadas oficiales admitidas por `public.city_content`.
enum CityContentSection {
  welcome('welcome'),
  context('context'),
  culture('culture'),
  places('places'),
  gastronomy('gastronomy'),
  emergency('emergency');

  const CityContentSection(this.apiValue);

  /// Valor textual enviado y recibido desde la base de datos.
  final String apiValue;

  /// Convierte un texto proveniente del backend en su sección de dominio.
  static CityContentSection? fromApiValue(String? raw) {
    final clean = raw?.trim().toLowerCase();
    for (final value in CityContentSection.values) {
      if (value.apiValue == clean) return value;
    }
    return null;
  }
}

/// Estado temporal de un evento evaluado frente a su ventana real.
enum CityEventTemporalStatus {
  active('active'),
  upcoming('upcoming'),
  past('past');

  const CityEventTemporalStatus(this.apiValue);

  /// Valor textual retornado por `public.get_city_events_status`.
  final String apiValue;

  /// Convierte un texto proveniente del backend en su estado temporal.
  static CityEventTemporalStatus? fromApiValue(String? raw) {
    final clean = raw?.trim().toLowerCase();
    for (final value in CityEventTemporalStatus.values) {
      if (value.apiValue == clean) return value;
    }
    return null;
  }
}

/// Normaliza cualquier código de idioma a `'es'` o `'en'` (contrato de RPC).
String normalizeCityLocale(String? localeCode) {
  final clean = localeCode?.trim().toLowerCase() ?? '';
  return clean.startsWith('en') ? 'en' : 'es';
}

/// Valida que un enlace de fuente o medio cultural use estrictamente `https://`
/// y cumpla las reglas de [ExternalUriGuard].
Uri? resolveSafeCitySourceUri(String? rawUrl) {
  final clean = rawUrl?.trim() ?? '';
  if (clean.isEmpty) return null;
  final uri = Uri.tryParse(clean);
  if (uri == null || uri.scheme.toLowerCase() != 'https') {
    return null;
  }
  return ExternalUriGuard.isAllowedExternalUri(uri) ? uri : null;
}

/// Ficha cultural curada y verificable de un municipio piloto (`VJ-15`).
class CityContentItem {
  const CityContentItem({
    required this.id,
    required this.municipalityCode,
    required this.slug,
    required this.section,
    required this.requestedLocale,
    required this.resolvedLocale,
    required this.isLocaleFallback,
    required this.title,
    required this.body,
    this.imagePath,
    this.imageLicense,
    required this.sourceCitation,
    this.sourceUrl,
    this.sortOrder = 0,
    this.isDemo = false,
  });

  final String id;
  final String municipalityCode;
  final String slug;
  final CityContentSection section;
  final String requestedLocale;
  final String resolvedLocale;
  final bool isLocaleFallback;
  final String title;
  final String body;
  final String? imagePath;
  final String? imageLicense;
  final String sourceCitation;
  final String? sourceUrl;
  final int sortOrder;
  final bool isDemo;

  /// URI segura (`https://`) lista para abrir la fuente verificada, o `null`.
  Uri? get safeSourceUri => resolveSafeCitySourceUri(sourceUrl);

  /// Indica si existe una ruta de imagen acompañada de licencia explícita.
  bool get hasLicensedImage =>
      (imagePath?.trim().isNotEmpty ?? false) &&
      (imageLicense?.trim().isNotEmpty ?? false);

  /// URI remota segura de la imagen solo cuando cuenta con licencia válida.
  Uri? get safeLicensedImageUri =>
      hasLicensedImage ? resolveSafeCitySourceUri(imagePath) : null;

  /// Ruta de asset local segura (`assets/images/...`) solo cuando cuenta con
  /// licencia explícita y no contiene saltos de directorio.
  String? get safeLicensedAssetPath {
    if (!hasLicensedImage) return null;
    final clean = imagePath!.trim();
    if (!clean.startsWith('assets/images/') || clean.contains('..')) {
      return null;
    }
    return clean;
  }
}

/// Evento municipal con estado temporal verificado y atribución de fuente.
class CityEvent {
  const CityEvent({
    required this.id,
    required this.municipalityCode,
    required this.name,
    this.descriptionEs,
    this.descriptionEn,
    this.venue,
    required this.startsAt,
    required this.endsAt,
    required this.temporalStatus,
    required this.isCurrentlyActive,
    this.isDemo = false,
    this.sourceCitation,
  });

  final String id;
  final String municipalityCode;
  final String name;
  final String? descriptionEs;
  final String? descriptionEn;
  final String? venue;
  final DateTime startsAt;
  final DateTime endsAt;
  final CityEventTemporalStatus temporalStatus;
  final bool isCurrentlyActive;
  final bool isDemo;
  final String? sourceCitation;

  /// Devuelve la descripción en el idioma solicitado, o respaldo en el otro
  /// idioma si falta la traducción.
  String? descriptionForLocale(String localeCode) {
    final es = descriptionEs?.trim() ?? '';
    final en = descriptionEn?.trim() ?? '';
    if (normalizeCityLocale(localeCode) == 'en') {
      if (en.isNotEmpty) return en;
      return es.isNotEmpty ? es : null;
    }
    if (es.isNotEmpty) return es;
    return en.isNotEmpty ? en : null;
  }

  /// Indica si se solicitó inglés pero se muestra la descripción en español.
  bool isDescriptionFallbackForLocale(String localeCode) {
    if (normalizeCityLocale(localeCode) != 'en') return false;
    final es = descriptionEs?.trim() ?? '';
    final en = descriptionEn?.trim() ?? '';
    return en.isEmpty && es.isNotEmpty;
  }

  /// Formatea el rango real de fechas en hora de Colombia (UTC-5) sin requerir
  /// inicialización externa de tablas regionales.
  String formattedDateRange({required String localeCode}) {
    final isEn = normalizeCityLocale(localeCode) == 'en';
    final start = startsAt.toUtc().subtract(const Duration(hours: 5));
    final end = endsAt.toUtc().subtract(const Duration(hours: 5));

    final months = isEn ? _monthsEn : _monthsEs;
    final startMonth = months[start.month - 1];
    final endMonth = months[end.month - 1];

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return isEn
          ? '$startMonth ${start.day}, ${start.year}'
          : '${start.day} $startMonth ${start.year}';
    }

    if (start.year == end.year && start.month == end.month) {
      return isEn
          ? '$startMonth ${start.day}–${end.day}, ${start.year}'
          : '${start.day}–${end.day} $startMonth ${start.year}';
    }

    if (start.year == end.year) {
      return isEn
          ? '$startMonth ${start.day} – $endMonth ${end.day}, ${start.year}'
          : '${start.day} $startMonth – ${end.day} $endMonth ${start.year}';
    }

    return isEn
        ? '$startMonth ${start.day}, ${start.year} – $endMonth ${end.day}, ${end.year}'
        : '${start.day} $startMonth ${start.year} – ${end.day} $endMonth ${end.year}';
  }

  static const List<String> _monthsEs = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static const List<String> _monthsEn = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

/// Ficha consolidada de la vista de ciudad retornada por `get_city_overview`.
class CityOverview {
  const CityOverview({
    required this.municipalityCode,
    required this.municipalityName,
    required this.departmentCode,
    required this.isPilot,
    required this.requestedLocale,
    required this.hasLocaleFallback,
    required this.content,
    required this.events,
  });

  final String municipalityCode;
  final String municipalityName;
  final String departmentCode;
  final bool isPilot;
  final String requestedLocale;
  final bool hasLocaleFallback;
  final List<CityContentItem> content;
  final List<CityEvent> events;
}
