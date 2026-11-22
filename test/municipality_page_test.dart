import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_page.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_selector_page.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_cultural_illustration.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_landmark_carousel.dart';

const _municipalities = <Municipality>[
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

class _FakeMunicipalityRepository implements MunicipalityRepository {
  const _FakeMunicipalityRepository();

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async =>
      _municipalities;

  @override
  Future<Municipality?> getByCode(String code) async {
    for (final municipality in _municipalities) {
      if (municipality.code == code) {
        return municipality;
      }
    }
    return null;
  }
}

Widget _buildPage(String code, {double textScale = 1.0}) {
  return ProviderScope(
    overrides: [
      municipalityRepositoryProvider.overrideWithValue(
        const _FakeMunicipalityRepository(),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 780),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MunicipalityPage(code: code),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'pilot municipality renders landmark carousel, intro, and enter button without overflow at 2.0x',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildPage('20001', textScale: 2.0));
      await tester.pumpAndSettle();

      expect(find.byType(CityLandmarkCarousel), findsOneWidget);
      expect(find.text('municipality.pilot_available'), findsOneWidget);
      expect(find.text('municipality.valledupar_intro'), findsOneWidget);
      expect(find.text('municipality.enter'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);

      // Cambiar al tercer hito (Plaza Alfonso López) tocando su chip interactivo
      final plazaChip = find.widgetWithText(
        ChoiceChip,
        'municipality.landmarks.plaza_chip',
      );
      await tester.ensureVisible(plazaChip);
      await tester.tap(plazaChip);
      await tester.pumpAndSettle();

      expect(find.text('3 / 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'not pilot municipality preserves regional illustration and registers interest',
    (tester) async {
      await tester.pumpWidget(_buildPage('20011'));
      await tester.pumpAndSettle();

      expect(find.byType(CityCulturalIllustrationBanner), findsOneWidget);
      expect(find.byType(CityLandmarkCarousel), findsNothing);
      expect(find.text('municipality.notify_me'), findsOneWidget);
      expect(find.text('municipality.notified'), findsNothing);

      await tester.tap(find.text('municipality.notify_me'));
      await tester.pump();

      expect(find.text('municipality.notified'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'selector renders pilot card and other municipalities immediately without overflow at 2.0x',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            municipalityRepositoryProvider.overrideWithValue(
              const _FakeMunicipalityRepository(),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MunicipalitySelectorPage(departmentCode: '20'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cesar'), findsOneWidget);
      expect(find.text('Valledupar'), findsOneWidget);
      expect(find.text('Aguachica'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown code shows a controlled message', (tester) async {
    await tester.pumpWidget(_buildPage('99999'));
    await tester.pumpAndSettle();

    expect(find.text('municipality.not_found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
