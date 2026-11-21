import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/municipality/domain/city_visual_identity.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_cultural_illustration.dart';

void main() {
  group('CityVisualIdentityCatalog (3-Level Cultural Identity)', () {
    test('Level 1: Valledupar (20001) and Cesar (20) resolve to Canaguate + Accordion + Guatapuri', () {
      final valledupar = CityVisualIdentityCatalog.forMunicipality(
        municipalityCode: '20001',
        departmentCode: '20',
        isPilot: true,
      );
      final cesar = CityVisualIdentityCatalog.forDepartment('20');

      expect(valledupar.motif, CulturalMotifKind.valleduparCanaguateAccordion);
      expect(cesar.motif, CulturalMotifKind.valleduparCanaguateAccordion);
      expect(
        valledupar.featureChipKeys,
        containsAll(<String>[
          'municipality.cultural.chip_canaguate',
          'municipality.cultural.chip_accordion',
          'municipality.cultural.chip_guatapuri',
        ]),
      );
    });

    test('Level 2: all 33 Colombian departments resolve to a valid cultural motif and chips', () {
      for (final dept in Departments.all) {
        final identity = CityVisualIdentityCatalog.forDepartment(dept.code);
        expect(identity.subtitleKey, isNotEmpty);
        expect(identity.tagKey, isNotEmpty);
        expect(identity.featureChipKeys.length, greaterThanOrEqualTo(3));
      }

      expect(
        CityVisualIdentityCatalog.forDepartment('47').motif,
        CulturalMotifKind.sierraSnowyCoast,
      );
      expect(
        CityVisualIdentityCatalog.forDepartment('13').motif,
        CulturalMotifKind.caribbeanWalledSea,
      );
      expect(
        CityVisualIdentityCatalog.forDepartment('05').motif,
        CulturalMotifKind.coffeeFlowersValley,
      );
      expect(
        CityVisualIdentityCatalog.forDepartment('88').motif,
        CulturalMotifKind.sevenColorsArchipelago,
      );
    });

    test('Level 3: Cesar subregional municipalities resolve to Serrania, Zapatosa, or Savanna', () {
      final puebloBello = CityVisualIdentityCatalog.forMunicipality(
        municipalityCode: '20570',
        departmentCode: '20',
      );
      final chimichagua = CityVisualIdentityCatalog.forMunicipality(
        municipalityCode: '20175',
        departmentCode: '20',
      );
      final aguachica = CityVisualIdentityCatalog.forMunicipality(
        municipalityCode: '20011',
        departmentCode: '20',
      );

      expect(puebloBello.motif, CulturalMotifKind.cesarSerraniaCoffee);
      expect(chimichagua.motif, CulturalMotifKind.cesarZapatosaLagoon);
      expect(aguachica.motif, CulturalMotifKind.cesarSavannaCotton);
    });
  });

  group('CityCulturalIllustrationBanner & Medallion widgets', () {
    testWidgets('renders Valledupar banner, chips, and medallion without overflow at 360dp and 1.5x text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CulturalHeaderMedallion(
                      identity: CityVisualIdentityCatalog.valleduparIdentity,
                    ),
                    const SizedBox(height: 12),
                    CityCulturalIllustrationBanner(
                      identity: CityVisualIdentityCatalog.valleduparIdentity,
                      cityName: 'Valledupar',
                      departmentName: 'Cesar',
                      isPilot: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CityCulturalIllustrationBanner), findsOneWidget);
      expect(find.byType(CulturalHeaderMedallion), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
