import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/features/map_colombia/presentation/pages/map_page.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_placeholder_page.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_selector_page.dart';
import 'package:via_justa/features/onboarding/presentation/pages/login_page.dart';
import 'package:via_justa/features/onboarding/presentation/pages/profile_selection_page.dart';
import 'package:via_justa/features/splash/presentation/pages/splash_page.dart';

/// Todas las rutas de la app viven aquí.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const map = '/map';
  static const department = '/department/:code';
  static const municipality = '/municipality/:code';

  static String departmentPath(String code) => '/department/$code';
  static String municipalityPath(String code) => '/municipality/$code';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const ProfileSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.map,
        builder: (context, state) => const MapPage(),
      ),
      GoRoute(
        path: AppRoutes.department,
        builder: (context, state) => MunicipalitySelectorPage(
          departmentCode: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.municipality,
        builder: (context, state) => MunicipalityPlaceholderPage(
          code: state.pathParameters['code']!,
        ),
      ),
    ],
  );
});