import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_validator.dart';

/// Contrato para abrir enlaces externos fuera de la aplicación (navegador, WhatsApp, mapas, teléfono).
abstract interface class BusinessExternalLauncher {
  Future<bool> launchExternalUri(Uri uri);
}

/// Construye y valida el enlace HTTPS de menú y pedidos configurado por el dueño.
Uri? resolveBusinessOrderUri(BusinessDetail detail) {
  if (!detail.canOrderExternal) return null;
  final raw = detail.orderUrl?.trim() ?? '';
  if (raw.isEmpty || !isValidBusinessOrderUrl(raw)) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

/// Construye el enlace de WhatsApp (`https://wa.me/...`) con mensaje sugerido en español o inglés.
Uri? buildBusinessWhatsappUri({
  required String? whatsapp,
  String? prebuiltWhatsappUrl,
  String businessName = '',
  String localeCode = 'es',
}) {
  final prebuilt = prebuiltWhatsappUrl?.trim() ?? '';
  if (prebuilt.isNotEmpty) {
    final parsed = Uri.tryParse(prebuilt);
    if (parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host == 'wa.me' &&
        parsed.pathSegments.isNotEmpty) {
      final existingText = parsed.queryParameters['text']?.trim() ?? '';
      if (existingText.isNotEmpty) {
        return parsed;
      }
      final digitsFromPath = parsed.pathSegments.first;
      if (RegExp(r'^[1-9][0-9]{9,14}$').hasMatch(digitsFromPath)) {
        return Uri.https('wa.me', '/$digitsFromPath', {
          'text': suggestedBusinessWhatsappMessage(
            businessName: businessName,
            localeCode: localeCode,
          ),
        });
      }
    }
  }

  final digits = normalizeBusinessPhone(whatsapp ?? '', whatsapp: true);
  if (!RegExp(r'^[1-9][0-9]{9,14}$').hasMatch(digits)) {
    return null;
  }

  return Uri.https('wa.me', '/$digits', {
    'text': suggestedBusinessWhatsappMessage(
      businessName: businessName,
      localeCode: localeCode,
    ),
  });
}

/// Mensaje sugerido al abrir el chat de WhatsApp con un negocio desde Vía Justa.
String suggestedBusinessWhatsappMessage({
  required String businessName,
  String localeCode = 'es',
}) {
  final cleanName = businessName
      .replaceAll(RegExp(r'[<>\x00-\x1f]'), '')
      .trim();
  final isEn = localeCode.toLowerCase().startsWith('en');
  if (cleanName.isEmpty) {
    return isEn
        ? 'Hello, I saw your business on Vía Justa and would like more information.'
        : 'Hola, vi tu negocio en Vía Justa y quisiera más información.';
  }
  final truncated = cleanName.length > 120
      ? cleanName.substring(0, 120)
      : cleanName;
  return isEn
      ? 'Hello $truncated, I saw your listing on Vía Justa and would like more information.'
      : 'Hola $truncated, vi tu ficha en Vía Justa y quisiera más información.';
}

/// Resuelve el enlace de WhatsApp para la ficha de un negocio si está autorizado.
Uri? resolveBusinessWhatsappUri(
  BusinessDetail detail, {
  String localeCode = 'es',
}) {
  if (!detail.canWhatsapp) return null;
  return buildBusinessWhatsappUri(
    whatsapp: detail.whatsapp,
    prebuiltWhatsappUrl: detail.whatsappUrl,
    businessName: detail.name,
    localeCode: localeCode,
  );
}

/// Construye el enlace de indicaciones en Google Maps a partir de coordenadas o URL prevalidada.
Uri? buildBusinessDirectionsUri({
  double? latitude,
  double? longitude,
  String? prebuiltMapsUrl,
}) {
  final prebuilt = prebuiltMapsUrl?.trim() ?? '';
  if (prebuilt.isNotEmpty) {
    final parsed = Uri.tryParse(prebuilt);
    if (parsed != null &&
        parsed.scheme == 'https' &&
        (parsed.host == 'www.google.com' || parsed.host == 'maps.google.com')) {
      return parsed;
    }
  }

  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return null;
  }

  final lat = latitude.toStringAsFixed(6);
  final lng = longitude.toStringAsFixed(6);
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );
}

/// Resuelve el enlace de Google Maps para la ficha de un negocio si cuenta con ubicación válida.
Uri? resolveBusinessDirectionsUri(BusinessDetail detail) {
  if (!detail.canDirections) return null;
  return buildBusinessDirectionsUri(
    latitude: detail.latitude,
    longitude: detail.longitude,
    prebuiltMapsUrl: detail.mapsUrl,
  );
}

/// Resuelve el enlace de contacto rápido (WhatsApp o llamada telefónica) para una tarjeta del directorio.
Uri? resolveBusinessCardContactUri(
  Business business, {
  String localeCode = 'es',
}) {
  if (business.hasWhatsapp ||
      (business.whatsappUrl != null &&
          business.whatsappUrl!.trim().isNotEmpty)) {
    final waUri = buildBusinessWhatsappUri(
      whatsapp: business.whatsapp,
      prebuiltWhatsappUrl: business.whatsappUrl,
      businessName: business.name,
      localeCode: localeCode,
    );
    if (waUri != null) return waUri;
  }

  final prebuiltTel = business.telUrl?.trim() ?? '';
  if (prebuiltTel.startsWith('tel:')) {
    final parsed = Uri.tryParse(prebuiltTel);
    if (parsed != null) return parsed;
  }

  final digits = normalizeBusinessPhone(business.phone);
  if (RegExp(r'^\+?[0-9]{7,15}$').hasMatch(digits)) {
    return Uri(scheme: 'tel', path: digits);
  }
  return null;
}
