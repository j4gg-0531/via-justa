import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/session/session_navigation_rule.dart';

/// Atajo para no repetir los cuatro parámetros en cada caso.
String? _redirect(
  String location, {
  required SessionNavigationStatus status,
  bool profile = false,
  bool pilot = false,
}) {
  return resolveNavigationRedirect(
    location: location,
    status: status,
    hasSelectedProfile: profile,
    hasSelectedPilotMunicipality: pilot,
  );
}

const _unknown = SessionNavigationStatus.unknown;
const _out = SessionNavigationStatus.unauthenticated;
const _in = SessionNavigationStatus.authenticated;

/// Rutas principales (pestañas del shell y precios).
const _mainRoutes = <String>[
  AppRoutes.home,
  AppRoutes.map,
  AppRoutes.scan,
  AppRoutes.businesses,
  AppRoutes.profile,
  AppRoutes.priceResult,
  AppRoutes.priceContribute,
];

const _publicRoutes = <String>[
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.register,
];

const _municipalityRoutes = <String>[
  AppRoutes.departmentMap,
  '/department/20',
  '/municipality/20001',
  '/municipality/20011',
];

void main() {
  group('rutas de la regla coinciden con AppRoutes', () {
    test('cada grupo usa las mismas rutas que el router', () {
      expect(classifyRoute(AppRoutes.splash), NavigationRouteKind.splash);
      for (final route in _publicRoutes) {
        expect(classifyRoute(route), NavigationRouteKind.publicEntry, reason: route);
      }
      expect(classifyRoute(AppRoutes.onboarding), NavigationRouteKind.profileSetup);
      expect(
        classifyRoute(AppRoutes.departmentPath('20')),
        NavigationRouteKind.municipalitySetup,
      );
      expect(
        classifyRoute(AppRoutes.municipalityPath('20001')),
        NavigationRouteKind.municipalitySetup,
      );
      for (final route in _mainRoutes) {
        expect(classifyRoute(route), NavigationRouteKind.main, reason: route);
      }
    });

    test('/departments no se confunde con el prefijo /department/', () {
      expect(classifyRoute('/departments'), NavigationRouteKind.municipalitySetup);
      expect(classifyRoute('/department'), NavigationRouteKind.main);
    });

    test('una ruta desconocida se trata como protegida', () {
      expect(classifyRoute('/ruta-inexistente'), NavigationRouteKind.main);
    });
  });

  group('resolveFirstIncompleteStep', () {
    test('sigue el orden sesión → perfil → municipio → inicio', () {
      String step(SessionNavigationStatus status, {bool profile = false, bool pilot = false}) {
        return resolveFirstIncompleteStep(
          status: status,
          hasSelectedProfile: profile,
          hasSelectedPilotMunicipality: pilot,
        );
      }

      expect(step(_unknown, profile: true, pilot: true), AppRoutes.splash);
      expect(step(_out, profile: true, pilot: true), AppRoutes.welcome);
      expect(step(_in), AppRoutes.onboarding);
      expect(step(_in, pilot: true), AppRoutes.onboarding);
      expect(step(_in, profile: true), AppRoutes.departmentMap);
      expect(step(_in, profile: true, pilot: true), AppRoutes.home);
    });
  });

  group('regla 1: sesión unknown', () {
    test('se queda en /splash', () {
      expect(_redirect(AppRoutes.splash, status: _unknown), isNull);
      expect(
        _redirect(AppRoutes.splash, status: _unknown, profile: true, pilot: true),
        isNull,
      );
    });

    test('cualquier otra ruta vuelve a /splash', () {
      for (final route in [
        ..._publicRoutes,
        AppRoutes.onboarding,
        ..._municipalityRoutes,
        ..._mainRoutes,
      ]) {
        expect(
          _redirect(route, status: _unknown, profile: true, pilot: true),
          AppRoutes.splash,
          reason: route,
        );
      }
    });
  });

  group('regla 2: /splash con sesión resuelta', () {
    test('sin sesión va a /welcome', () {
      expect(_redirect(AppRoutes.splash, status: _out), AppRoutes.welcome);
    });

    test('con sesión va al primer paso incompleto', () {
      expect(_redirect(AppRoutes.splash, status: _in), AppRoutes.onboarding);
      expect(
        _redirect(AppRoutes.splash, status: _in, profile: true),
        AppRoutes.departmentMap,
      );
      expect(
        _redirect(AppRoutes.splash, status: _in, profile: true, pilot: true),
        AppRoutes.home,
      );
    });
  });

  group('regla 3: sin sesión', () {
    test('las rutas de entrada públicas se permiten', () {
      for (final route in _publicRoutes) {
        expect(_redirect(route, status: _out), isNull, reason: route);
      }
    });

    test('onboarding, municipios y rutas principales van a /welcome', () {
      for (final route in [
        AppRoutes.onboarding,
        ..._municipalityRoutes,
        ..._mainRoutes,
      ]) {
        expect(_redirect(route, status: _out), AppRoutes.welcome, reason: route);
      }
    });

    test('perfil o municipio en memoria no sustituyen a la sesión', () {
      expect(
        _redirect(AppRoutes.home, status: _out, profile: true, pilot: true),
        AppRoutes.welcome,
      );
    });
  });

  group('regla 4: con sesión en una ruta de entrada pública', () {
    test('va al primer paso incompleto, no siempre a /home', () {
      for (final route in _publicRoutes) {
        expect(_redirect(route, status: _in), AppRoutes.onboarding, reason: route);
        expect(
          _redirect(route, status: _in, profile: true),
          AppRoutes.departmentMap,
          reason: route,
        );
        expect(
          _redirect(route, status: _in, profile: true, pilot: true),
          AppRoutes.home,
          reason: route,
        );
      }
    });
  });

  group('regla 5: con sesión', () {
    test('/onboarding se permite siempre (también para cambiar de perfil)', () {
      expect(_redirect(AppRoutes.onboarding, status: _in), isNull);
      expect(_redirect(AppRoutes.onboarding, status: _in, profile: true), isNull);
      expect(
        _redirect(AppRoutes.onboarding, status: _in, profile: true, pilot: true),
        isNull,
      );
    });

    test('las rutas de municipio exigen perfil', () {
      for (final route in _municipalityRoutes) {
        expect(_redirect(route, status: _in), AppRoutes.onboarding, reason: route);
        expect(_redirect(route, status: _in, profile: true), isNull, reason: route);
      }
    });

    test('las rutas de municipio no se bloquean si ya hay municipio', () {
      for (final route in _municipalityRoutes) {
        expect(
          _redirect(route, status: _in, profile: true, pilot: true),
          isNull,
          reason: route,
        );
      }
    });

    test('las rutas principales exigen perfil y municipio piloto', () {
      for (final route in _mainRoutes) {
        expect(_redirect(route, status: _in), AppRoutes.onboarding, reason: route);
        expect(
          _redirect(route, status: _in, pilot: true),
          AppRoutes.onboarding,
          reason: route,
        );
        expect(
          _redirect(route, status: _in, profile: true),
          AppRoutes.departmentMap,
          reason: route,
        );
        expect(
          _redirect(route, status: _in, profile: true, pilot: true),
          isNull,
          reason: route,
        );
      }
    });
  });

  group('sin bucles de redirección', () {
    test('nunca devuelve la misma ubicación recibida', () {
      final locations = [
        AppRoutes.splash,
        ..._publicRoutes,
        AppRoutes.onboarding,
        ..._municipalityRoutes,
        ..._mainRoutes,
      ];
      for (final status in SessionNavigationStatus.values) {
        for (final profile in [false, true]) {
          for (final pilot in [false, true]) {
            for (final location in locations) {
              final target = _redirect(
                location,
                status: status,
                profile: profile,
                pilot: pilot,
              );
              expect(
                target,
                isNot(location),
                reason: '$location / $status / perfil=$profile / piloto=$pilot',
              );
              // El destino debe ser estable: redirigir de nuevo desde él no
              // produce otro salto.
              if (target != null) {
                expect(
                  _redirect(target, status: status, profile: profile, pilot: pilot),
                  isNull,
                  reason: 'destino inestable $target desde $location / $status',
                );
              }
            }
          }
        }
      }
    });
  });

  group('resolveSessionRedirect (transitorio hasta el Paso B)', () {
    test('conserva el comportamiento anterior: solo redirige desde /splash', () {
      expect(
        resolveSessionRedirect(
          matchedLocation: AppRoutes.splash,
          isAuthenticated: false,
          hasSelectedProfile: false,
          hasSelectedPilotMunicipality: false,
        ),
        AppRoutes.welcome,
      );
      expect(
        resolveSessionRedirect(
          matchedLocation: AppRoutes.splash,
          isAuthenticated: true,
          hasSelectedProfile: true,
          hasSelectedPilotMunicipality: true,
        ),
        AppRoutes.home,
      );
      expect(
        resolveSessionRedirect(
          matchedLocation: '/department/20',
          isAuthenticated: false,
          hasSelectedProfile: false,
          hasSelectedPilotMunicipality: false,
        ),
        isNull,
      );
    });
  });
}
