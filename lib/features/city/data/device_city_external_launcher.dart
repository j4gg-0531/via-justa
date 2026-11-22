import 'package:url_launcher/url_launcher.dart';
import 'package:via_justa/core/security/external_uri_guard.dart';
import 'package:via_justa/features/city/domain/city_external_launcher.dart';

/// Adaptador que abre fuentes culturales verificadas (`https://`) en el
/// navegador externo del dispositivo usando `url_launcher`.
class DeviceCityExternalLauncher implements CityExternalLauncher {
  const DeviceCityExternalLauncher();

  @override
  Future<bool> launchExternalUri(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'https' ||
        !ExternalUriGuard.isAllowedExternalUri(uri)) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
