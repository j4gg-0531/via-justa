import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/taxi_route_estimate.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_pin_visuals.dart';

void main() {
  test('calculateAirDistanceKm devuelve distancia geodésica coherente entre puntos de Valledupar', () {
    expect(
      calculateAirDistanceKm(
        originLatitude: 10.4742,
        originLongitude: -73.2436,
        destinationLatitude: 10.4742,
        destinationLongitude: -73.2436,
      ),
      closeTo(0.0, 0.001),
    );

    final plazaToGuatapuri = calculateAirDistanceKm(
      originLatitude: 10.4742,
      originLongitude: -73.2436,
      destinationLatitude: 10.4885,
      destinationLongitude: -73.2535,
    );
    expect(plazaToGuatapuri, greaterThan(1.5));
    expect(plazaToGuatapuri, lessThan(2.5));
  });

  test('classifyTaxiDistanceRange y taxiDistanceRangeTranslationKey cubren los 3 rangos SQL', () {
    expect(classifyTaxiDistanceRange(0.4), '0_2_km');
    expect(classifyTaxiDistanceRange(2.0), '0_2_km');
    expect(classifyTaxiDistanceRange(2.01), '2_5_km');
    expect(classifyTaxiDistanceRange(5.0), '2_5_km');
    expect(classifyTaxiDistanceRange(5.01), 'gt_5_km');

    expect(
      taxiDistanceRangeTranslationKey('0_2_km'),
      'price_map.distance_range_short',
    );
    expect(
      taxiDistanceRangeTranslationKey('2_5_km'),
      'price_map.distance_range_medium',
    );
    expect(
      taxiDistanceRangeTranslationKey('gt_5_km'),
      'price_map.distance_range_long',
    );
    expect(taxiDistanceRangeTranslationKey('unknown'), isNull);
  });

  test('DemoPriceVerdictRepository.evaluatePrice resuelve zonas y distancia cuando recibe coordenadas libres', () async {
    const repo = DemoPriceVerdictRepository();
    final verdict = await repo.evaluatePrice(
      categoryId: kTaxiCategoryId,
      municipalityCode: '20001',
      zoneId: '',
      originLatitude: 10.4885,
      originLongitude: -73.2535,
      destinationLatitude: 10.4742,
      destinationLongitude: -73.2436,
      submittedCop: kTaxiReferenceProbeCop,
    );

    expect(verdict.zoneId, 'vup_norte');
    expect(verdict.destinationZoneId, 'vup_centro');
    expect(verdict.distanceKm, isNotNull);
    expect(verdict.distanceRange, '0_2_km');
    expect(verdict.referenceCop, 11000);
    expect(verdict.recommendedCapCop, 12650);
  });

  test('renderDestinationMarkerPngBytes genera bytes PNG válidos para el marcador temporal', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await renderDestinationMarkerPngBytes(pixelRatio: 2.0);
    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
