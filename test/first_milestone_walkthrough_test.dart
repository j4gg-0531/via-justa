import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/auth/presentation/pages/welcome_page.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/presentation/pages/businesses_page.dart';
import 'package:via_justa/features/home/presentation/pages/home_page.dart';
import 'package:via_justa/features/map_colombia/presentation/pages/map_page.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_page.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_selector_page.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/pages/profile_selection_page.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';
import 'package:via_justa/features/prices/presentation/pages/contribute_price_page.dart';
import 'package:via_justa/features/prices/presentation/pages/price_map_page.dart';
import 'package:via_justa/features/prices/presentation/pages/price_result_page.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/profile/presentation/pages/profile_page.dart';
import 'package:via_justa/features/scan/presentation/pages/scan_page.dart';

const _walkthroughMunicipalities = <Municipality>[
  Municipality(
    code: '20001',
    name: 'Valledupar',
    departmentCode: '20',
    isPilot: true,
  ),
  Municipality(
    code: '20011',
    name: 'Aguachica',
    departmentCode: '20',
    isPilot: false,
  ),
];

class _WalkthroughMunicipalityRepository implements MunicipalityRepository {
  const _WalkthroughMunicipalityRepository();

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async {
    if (departmentCode == '20') return _walkthroughMunicipalities;
    return const [];
  }

  @override
  Future<Municipality?> getByCode(String code) async {
    for (final item in _walkthroughMunicipalities) {
      if (item.code == code) return item;
    }
    return null;
  }
}

void main() {
  testWidgets(
    'VJ-06 First Milestone E2E Walkthrough: Welcome -> Onboarding -> Map -> Municipality (Pilot & Non-Pilot) -> 5-Tab Shell -> Semaphore Result (M07/M20) -> 4-Step Contribute (M10) -> SignOut',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          municipalityRepositoryProvider.overrideWithValue(
            const _WalkthroughMunicipalityRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
              );
            },
          ),
        ),
      );

      final router = container.read(routerProvider);

      // 1. Entrada (M01) -> Onboarding (M02)
      router.go(AppRoutes.welcome);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);

      // Inicia sesión para avanzar a Onboarding (requisito de VJ-09a)
      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'carlos@viajusta.co', password: 'password123');
      await tester.pumpAndSettle();

      router.go(AppRoutes.onboarding);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSelectionPage), findsOneWidget);

      // Select Visitor profile
      container.read(profileTypeProvider.notifier).select(ProfileType.visitor);
      await tester.pumpAndSettle();
      expect(container.read(profileTypeProvider), ProfileType.visitor);

      // 2. Mapa de departamentos (M03) -> Selector de municipios Cesar (M13)
      router.go(AppRoutes.departmentMap);
      await tester.pumpAndSettle();
      expect(find.byType(MapPage), findsOneWidget);

      router.push(AppRoutes.departmentPath('20'));
      await tester.pumpAndSettle();
      expect(find.byType(MunicipalitySelectorPage), findsOneWidget);
      expect(find.text('municipality.search_prompt'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();
      expect(find.text('Valledupar'), findsOneWidget);
      expect(find.text('Aguachica'), findsOneWidget);

      // 3. Municipio fuera del piloto (M15 - Aguachica): registrar interés en memoria
      router.push(AppRoutes.municipalityPath('20011'));
      await tester.pumpAndSettle();
      expect(find.byType(MunicipalityPage), findsOneWidget);
      expect(find.text('municipality.notify_me'), findsOneWidget);

      await tester.tap(find.text('municipality.notify_me'));
      await tester.pumpAndSettle();
      expect(find.text('municipality.notified'), findsOneWidget);
      expect(container.read(municipalityInterestProvider), contains('20011'));

      // 4. Municipio piloto (M14 - Valledupar): entrar al shell principal
      router.go(AppRoutes.municipalityPath('20001'));
      await tester.pumpAndSettle();
      expect(find.text('municipality.pilot_available'), findsOneWidget);

      await tester.tap(find.text('municipality.enter'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(container.read(selectedMunicipalityProvider)?.code, '20001');

      // 5. Pestaña Mapa local de precios y servicios (M08)
      await tester.tap(find.text('nav.map'));
      await tester.pumpAndSettle();
      expect(find.byType(PriceMapPage), findsOneWidget);

      // 6. Pestaña Escanear (M06) -> evaluar en semáforo (M07 / M20)
      await tester.tap(find.text('nav.scan'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanPage), findsOneWidget);

      final evaluateBtn = find.text('price_verdict.evaluate_cta');
      await tester.ensureVisible(evaluateBtn);
      await tester.tap(evaluateBtn);
      await tester.pumpAndSettle();
      expect(find.byType(PriceResultPage), findsOneWidget);
      expect(find.text('price_verdict.orientative_disclaimer'), findsOneWidget);

      // Alternar variante M20 (muestra insuficiente N < 3) en la pantalla de resultado
      final insufficientChip = find.text('price_verdict.scenario_insufficient');
      await tester.ensureVisible(insufficientChip);
      await tester.tap(insufficientChip);
      await tester.pumpAndSettle();
      expect(
        find.text('price_verdict.insufficient_no_threshold'),
        findsOneWidget,
      );

      // 7. Desde el resultado, abrir el flujo de 4 pasos de aporte de precio (M10)
      final contributeCta = find.text(
        'price_verdict.contribute_from_result_cta',
      );
      await tester.ensureVisible(contributeCta);
      await tester.tap(contributeCta);
      await tester.pumpAndSettle();
      expect(find.byType(ContributePricePage), findsOneWidget);

      // Completar los 4 pasos del aporte DEMO
      final nextStepBtn = find.text('price_contribute.next_step_cta');
      await tester.ensureVisible(nextStepBtn);
      await tester.tap(nextStepBtn); // Paso 1 -> Paso 2
      await tester.pumpAndSettle();

      final presetAmount = find.text(r'$12.000 COP');
      await tester.ensureVisible(presetAmount);
      await tester.tap(presetAmount);
      await tester.pumpAndSettle();

      await tester.ensureVisible(nextStepBtn);
      await tester.tap(nextStepBtn); // Paso 2 -> Paso 3
      await tester.pumpAndSettle();

      await tester.ensureVisible(nextStepBtn);
      await tester.tap(nextStepBtn); // Paso 3 -> Paso 4
      await tester.pumpAndSettle();

      final confirmSubmitBtn = find.text('price_contribute.confirm_submit_cta');
      await tester.ensureVisible(confirmSubmitBtn);
      await tester.tap(confirmSubmitBtn);
      await tester.pumpAndSettle();

      expect(find.text('price_contribute.success_title'), findsOneWidget);
      expect(container.read(priceContributionProvider).isCompleted, isTrue);

      // 8. Pestaña Negocios (M21) y Pestaña Perfil (M17) -> Cerrar sesión
      router.go(AppRoutes.businesses);
      await tester.pumpAndSettle();
      expect(find.byType(BusinessesPage), findsOneWidget);

      router.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);

      final signOutBtn = find.text('profile.sign_out');
      await tester.ensureVisible(signOutBtn);
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      // Verifica regreso limpio a WelcomePage y reinicio completo del estado DEMO
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(container.read(profileTypeProvider), isNull);
      expect(container.read(selectedMunicipalityProvider), isNull);
      expect(container.read(municipalityInterestProvider), isEmpty);
      expect(container.read(priceContributionProvider).isCompleted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}