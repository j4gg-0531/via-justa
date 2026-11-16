import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_price_notice.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

const _categories = <PriceCategory>[
  PriceCategory(
    id: 'food_corrientazo',
    groupKey: 'food',
    nameEs: 'Almuerzo ejecutivo / corriente',
    nameEn: 'Standard daily lunch',
    unitDescriptionEs: 'Plato del día con sopa, seco y bebida en la zona',
    unitDescriptionEn: 'Daily lunch menu with soup, main dish, and drink in the zone',
  ),
  PriceCategory(
    id: 'lodging_standard_night',
    groupKey: 'lodging',
    nameEs: 'Habitación estándar (1 noche)',
    nameEn: 'Standard room (1 night)',
    unitDescriptionEs: 'Habitación sencilla o doble con ventilador/A.C.',
    unitDescriptionEn: 'Single or double room with fan/A.C.',
  ),
  PriceCategory(
    id: 'transport_taxi_minimal',
    groupKey: 'transport',
    nameEs: 'Taxi — Carrera mínima urbana',
    nameEn: 'Taxi — Minimum urban ride',
    unitDescriptionEs: 'Trayecto diurno dentro de la zona seleccionada',
    unitDescriptionEn: 'Daytime trip within the selected zone',
  ),
  PriceCategory(
    id: 'services_laundry_load',
    groupKey: 'services',
    nameEs: 'Lavandería por tanda',
    nameEn: 'Laundry per load',
    unitDescriptionEs: 'Lavado y secado básico hasta 5 kg',
    unitDescriptionEn: 'Basic wash and dry up to 5 kg',
  ),
];

void main() {
  group('comparableCategoriesForBusinessType', () {
    test('filtra categorías equivalentes según el tipo de negocio', () {
      expect(
        comparableCategoriesForBusinessType(
          BusinessType.restaurant,
          _categories,
        ).map((c) => c.id),
        ['food_corrientazo'],
      );
      expect(
        comparableCategoriesForBusinessType(
          BusinessType.hotel,
          _categories,
        ).map((c) => c.id),
        ['lodging_standard_night'],
      );
      expect(
        comparableCategoriesForBusinessType(
          BusinessType.transport,
          _categories,
        ).map((c) => c.id),
        ['transport_taxi_minimal'],
      );
      expect(
        comparableCategoriesForBusinessType(
          BusinessType.service,
          _categories,
        ).map((c) => c.id),
        ['services_laundry_load'],
      );
    });
  });

  group('buildBusinessPriceNotice', () {
    test(
      'calcula mediana de la zona, diferencia respecto al precio ingresado y cantidad de reportes',
      () {
        const verdict = PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'vup_centro',
          level: PriceVerdictLevel.yellow,
          submittedCop: 15000,
          referenceCop: 12000,
          deviationPct: 25.0,
          n: 8,
          isDemo: false,
        );

        final notice = buildBusinessPriceNotice(
          category: _categories.first,
          verdict: verdict,
        );

        expect(notice.isInsufficient, isFalse);
        expect(notice.enteredCop, 15000);
        expect(notice.medianCop, 12000);
        expect(notice.differenceCop, 3000);
        expect(notice.sampleCount, 8);
        expect(notice.formattedMedianCop, r'$12.000 COP');
        expect(notice.formattedDifferenceCop, r'+$3.000 COP');
        expect(notice.formattedDeviationPct, '+25,0 %');
      },
    );

    test('indica muestra insuficiente cuando faltan reportes en la zona', () {
      const verdict = PriceVerdict(
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        level: PriceVerdictLevel.insufficient,
        submittedCop: 15000,
        n: 1,
        isDemo: false,
      );

      final notice = buildBusinessPriceNotice(
        category: _categories.first,
        verdict: verdict,
      );

      expect(notice.isInsufficient, isTrue);
      expect(notice.medianCop, isNull);
      expect(notice.differenceCop, isNull);
      expect(notice.sampleCount, 1);
    });
  });
}
