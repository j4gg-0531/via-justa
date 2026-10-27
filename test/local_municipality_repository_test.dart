import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/municipality/data/local_municipality_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalMunicipalityRepository.getByCode', () {
    late LocalMunicipalityRepository repository;

    setUp(() {
      repository = LocalMunicipalityRepository();
    });

    test('returns Valledupar as pilot', () async {
      final municipality = await repository.getByCode('20001');

      expect(municipality?.name, 'Valledupar');
      expect(municipality?.isPilot, isTrue);
    });

    test('returns Aguachica as not pilot', () async {
      final municipality = await repository.getByCode('20011');

      expect(municipality?.name, 'Aguachica');
      expect(municipality?.isPilot, isFalse);
    });

    test('returns null for an unknown code', () async {
      expect(await repository.getByCode('99999'), isNull);
    });

    test('returns null for codes that are too short', () async {
      expect(await repository.getByCode(''), isNull);
      expect(await repository.getByCode('2'), isNull);
    });
  });
}
