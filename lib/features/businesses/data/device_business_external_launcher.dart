import 'package:url_launcher/url_launcher.dart';
import 'package:via_justa/features/businesses/domain/business_external_actions.dart';

/// Adaptador de plataforma que abre enlaces externos de negocios con `url_launcher`.
class DeviceBusinessExternalLauncher implements BusinessExternalLauncher {
  const DeviceBusinessExternalLauncher();

  @override
  Future<bool> launchExternalUri(Uri uri) async {
    try {
      final mode = uri.scheme == 'tel'
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication;
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
