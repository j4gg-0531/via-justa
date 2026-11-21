/// Estado del acceso a la ubicación GPS del dispositivo.
enum DeviceLocationStatus {
  granted,
  serviceDisabled,
  permissionDenied,
  unavailable,
}

/// Resultado inmutable de consultar las coordenadas actuales del dispositivo.
class DeviceLocationResult {
  const DeviceLocationResult({
    required this.status,
    this.latitude,
    this.longitude,
  });

  final DeviceLocationStatus status;
  final double? latitude;
  final double? longitude;

  bool get isGranted =>
      status == DeviceLocationStatus.granted &&
      latitude != null &&
      longitude != null;

  /// Clave de error de localización cuando no se pudo obtener ubicación GPS.
  String? get errorKey {
    switch (status) {
      case DeviceLocationStatus.granted:
        return null;
      case DeviceLocationStatus.serviceDisabled:
        return 'gps_disabled';
      case DeviceLocationStatus.permissionDenied:
        return 'gps_permission_denied';
      case DeviceLocationStatus.unavailable:
        return 'gps_unavailable';
    }
  }
}

/// Contrato abstracto para obtener la posición GPS real del dispositivo.
abstract class DeviceLocationGateway {
  Future<DeviceLocationResult> fetchCurrentPosition();
}
