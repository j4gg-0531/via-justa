/// Reglas puras de navegación por sesión (Dart puro: sin Flutter, sin
/// `BuildContext`, sin Riverpod). El router solo las consulta; aquí se decide
/// qué rutas son públicas, cuáles exigen sesión y cuál es el primer paso que le
/// falta completar al usuario.
///
/// Las rutas se escriben como texto para no importar `app_router.dart` (que
/// depende de Flutter). `test/session_navigation_rule_test.dart` verifica que
/// coincidan con las constantes de `AppRoutes`.
library;

/// Estado de la sesión visto por el router.
///
/// `unknown` existe para el arranque: mientras se restaura la sesión guardada
/// no se puede decidir, y el usuario permanece en `/splash` en lugar de ver
/// `/welcome` un instante y luego saltar a `/home`.
enum SessionNavigationStatus {
  /// Todavía no se sabe si hay sesión (restauración en curso).
  unknown,

  /// Se confirmó que no hay sesión.
  unauthenticated,

  /// Hay una sesión activa (real o DEMO).
  authenticated,
}

/// Grupos de rutas según lo que exigen para entrar.
enum NavigationRouteKind {
  /// `/splash`: pantalla de arranque mientras se resuelve la sesión.
  splash,

  /// `/welcome`, `/login`, `/register`: solo para quien no tiene sesión.
  publicEntry,

  /// `/onboarding`: elegir tipo de perfil. Exige sesión.
  profileSetup,

  /// `/departments`, `/department/:code`, `/municipality/:code`: explorar y
  /// elegir municipio. Exige sesión y perfil, pero no municipio: quien ya
  /// eligió uno puede volver a explorar sin ser expulsado.
  municipalitySetup,

  /// Pestañas del shell y rutas de precios. Exige sesión, perfil y municipio
  /// piloto. Cualquier ruta no reconocida cae aquí (la opción más segura).
  main,
}

const String _splash = '/splash';
const String _welcome = '/welcome';
const String _login = '/login';
const String _register = '/register';
const String _onboarding = '/onboarding';
const String _departmentMap = '/departments';
const String _departmentPrefix = '/department/';
const String _municipalityPrefix = '/municipality/';
const String _home = '/home';

/// Clasifica una ubicación (`GoRouterState.matchedLocation`) en su grupo.
NavigationRouteKind classifyRoute(String location) {
  if (location == _splash) return NavigationRouteKind.splash;
  if (location == _welcome || location == _login || location == _register) {
    return NavigationRouteKind.publicEntry;
  }
  if (location == _onboarding) return NavigationRouteKind.profileSetup;
  if (location == _departmentMap ||
      location.startsWith(_departmentPrefix) ||
      location.startsWith(_municipalityPrefix)) {
    return NavigationRouteKind.municipalitySetup;
  }
  return NavigationRouteKind.main;
}

/// Devuelve la ruta del primer paso que le falta completar al usuario.
///
/// Orden: sesión → perfil → municipio piloto → inicio. Con sesión `unknown`
/// devuelve `/splash` porque todavía no se puede decidir.
String resolveFirstIncompleteStep({
  required SessionNavigationStatus status,
  required bool hasSelectedProfile,
  required bool hasSelectedPilotMunicipality,
}) {
  switch (status) {
    case SessionNavigationStatus.unknown:
      return _splash;
    case SessionNavigationStatus.unauthenticated:
      return _welcome;
    case SessionNavigationStatus.authenticated:
      if (!hasSelectedProfile) return _onboarding;
      if (!hasSelectedPilotMunicipality) return _departmentMap;
      return _home;
  }
}

/// Decide si el router debe redirigir la ubicación actual.
///
/// Devuelve la ruta destino, o `null` para permitir la navegación pedida.
/// Nunca devuelve la misma ubicación recibida (evita bucles de redirección).
///
/// Reglas:
/// 1. `unknown`: se permanece en `/splash`; cualquier otra ruta va a `/splash`.
/// 2. `/splash` con sesión resuelta: va al primer paso incompleto.
/// 3. Sin sesión: solo rutas de entrada públicas; lo demás va a `/welcome`.
/// 4. Con sesión en una ruta de entrada pública: va al primer paso incompleto
///    (no siempre a `/home`).
/// 5. Con sesión: `/onboarding` siempre se permite; las rutas de municipio
///    exigen perfil; las rutas principales exigen perfil y municipio piloto.
String? resolveNavigationRedirect({
  required String location,
  required SessionNavigationStatus status,
  required bool hasSelectedProfile,
  required bool hasSelectedPilotMunicipality,
}) {
  final target = _resolveTarget(
    kind: classifyRoute(location),
    status: status,
    hasSelectedProfile: hasSelectedProfile,
    hasSelectedPilotMunicipality: hasSelectedPilotMunicipality,
  );
  if (target == null || target == location) return null;
  return target;
}

String? _resolveTarget({
  required NavigationRouteKind kind,
  required SessionNavigationStatus status,
  required bool hasSelectedProfile,
  required bool hasSelectedPilotMunicipality,
}) {
  String firstIncomplete() => resolveFirstIncompleteStep(
    status: status,
    hasSelectedProfile: hasSelectedProfile,
    hasSelectedPilotMunicipality: hasSelectedPilotMunicipality,
  );

  if (status == SessionNavigationStatus.unknown) return _splash;
  if (kind == NavigationRouteKind.splash) return firstIncomplete();

  if (status == SessionNavigationStatus.unauthenticated) {
    return kind == NavigationRouteKind.publicEntry ? null : _welcome;
  }

  switch (kind) {
    case NavigationRouteKind.splash:
    case NavigationRouteKind.publicEntry:
      return firstIncomplete();
    case NavigationRouteKind.profileSetup:
      return null;
    case NavigationRouteKind.municipalitySetup:
      return hasSelectedProfile ? null : _onboarding;
    case NavigationRouteKind.main:
      return hasSelectedProfile && hasSelectedPilotMunicipality
          ? null
          : firstIncomplete();
  }
}

/// Redirección del arranque usada hoy por `routerProvider`.
///
/// TRANSITORIO (VJ-09a, Paso A): conserva el comportamiento anterior —solo
/// redirige desde `/splash` con un estado binario— para que este paso no
/// cambie la navegación de la app. En el Paso B el router pasa a
/// [resolveNavigationRedirect] con estado tri-estado y esta función se elimina.
String? resolveSessionRedirect({
  required String matchedLocation,
  required bool isAuthenticated,
  required bool hasSelectedProfile,
  required bool hasSelectedPilotMunicipality,
}) {
  if (matchedLocation != _splash) return null;
  return resolveFirstIncompleteStep(
    status: isAuthenticated
        ? SessionNavigationStatus.authenticated
        : SessionNavigationStatus.unauthenticated,
    hasSelectedProfile: hasSelectedProfile,
    hasSelectedPilotMunicipality: hasSelectedPilotMunicipality,
  );
}
