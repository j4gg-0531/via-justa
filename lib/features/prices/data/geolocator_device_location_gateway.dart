import 'package:geolocator/geolocator.dart';
import 'package:via_justa/features/prices/domain/device_location.dart';

/// Adaptador de [DeviceLocationGateway] respaldado por `geolocator`.
class GeolocatorDeviceLocationGateway implements DeviceLocationGateway {
  const GeolocatorDeviceLocationGateway();

  @override
  Future<DeviceLocationResult> fetchCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return DeviceLocationResult(
        status: DeviceLocationStatus.granted,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return const DeviceLocationResult(
        status: DeviceLocationStatus.unavailable,
      );
    }
  }
}
