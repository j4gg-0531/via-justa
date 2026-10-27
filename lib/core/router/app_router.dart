import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/navigation/app_scaffold.dart';
import 'package:via_justa/features/auth/presentation/pages/login_page.dart';
import 'package:via_justa/features/auth/presentation/pages/register_page.dart';
import 'package:via_justa/features/auth/presentation/pages/welcome_page.dart';
import 'package:via_justa/features/businesses/presentation/pages/businesses_page.dart';
import 'package:via_justa/features/home/presentation/pages/home_page.dart';
import 'package:via_justa/features/map_colombia/presentation/pages/map_page.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_page.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_selector_page.dart';
import 'package:via_justa/features/onboarding/presentation/pages/profile_selection_page.dart';
import 'package:via_justa/features/profile/presentation/pages/profile_page.dart';
import 'package:via_justa/features/scan/presentation/pages/scan_page.dart';
import 'package:via_justa/features/splash/presentation/pages/splash_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Todas las rutas de la app viven aquí.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const department = '/department/:code';
  static const municipality = '/municipality/:code';

  // Rutas de las 5 ramas de la barra inferior persistente
  static const home = '/home';
  static const map = '/map';
  static const scan = '/scan';
  static const businesses = '/businesses';
  static const profile = '/profile';

  static String departmentPath(String code) => '/department/$code';
  static String municipalityPath(String code) => '/municipality/$code';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      // Rutas raíz (fuera de la barra de navegación)
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const ProfileSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.department,
        builder: (context, state) => MunicipalitySelectorPage(
          departmentCode: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.municipality,
        builder: (context, state) =>
            MunicipalityPage(code: state.pathParameters['code']!),
      ),

      // Experiencia principal: StatefulShellRoute con 5 ramas y estado independiente
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffold(navigationShell: navigationShell),
        branches: [
          // Rama 0: Inicio (M04 / M05 / M02 adaptado)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),

          // Rama 1: Mapa (M03 y navegación geográfica)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapPage(),
              ),
            ],
          ),

          // Rama 2: Escanear (M06 selector precio / contrato)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.scan,
                builder: (context, state) => const ScanPage(),
              ),
            ],
          ),

          // Rama 3: Negocios (M21 directorio de muestra en Valledupar)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.businesses,
                builder: (context, state) => const BusinessesPage(),
              ),
            ],
          ),

          // Rama 4: Perfil (M17 perfil, idioma, ubicación y ajustes)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
