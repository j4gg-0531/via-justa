/// Regla pura de dominio (sin Flutter ni BuildContext) para resolver la redirección
/// de entrada en el router según el estado actual de la sesión.
String resolveSplashDestination({
  required bool isAuthenticated,
  required bool hasSelectedProfile,
  required bool hasSelectedPilotMunicipality,
}) {
  if (!isAuthenticated) {
    return '/welcome';
  }
  if (!hasSelectedProfile) {
    return '/onboarding';
  }
  if (!hasSelectedPilotMunicipality) {
    return '/departments';
  }
  return '/home';
}

/// Evalúa si `GoRouter` debe redirigir la ubicación actual (`matchedLocation`).
/// Retorna la ruta de destino cuando la ubicación es `/splash`, o `null` para
/// permitir la navegación solicitada sin bloqueos.
String? resolveSessionRedirect({
  required String matchedLocation,
  required bool isAuthenticated,
  required bool hasSelectedProfile,
  required bool hasSelectedPilotMunicipality,
}) {
  if (matchedLocation == '/splash') {
    return resolveSplashDestination(
      isAuthenticated: isAuthenticated,
      hasSelectedProfile: hasSelectedProfile,
      hasSelectedPilotMunicipality: hasSelectedPilotMunicipality,
    );
  }
  return null;
}
