import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

const _municipalities = <Municipality>[
  Municipality(
    code: '20001',
    name: 'Valledupar',
    departmentCode: '20',
    isPilot: true,
  ),
  Municipality(
    code: '20013',
    name: 'Agustín Codazzi',
    departmentCode: '20',
    isPilot: false,
  ),
  Municipality(
    code: '20011',
    name: 'Aguachica',
    departmentCode: '20',
    isPilot: false,
  ),
];

class _FakeMunicipalityRepository implements MunicipalityRepository {
  _FakeMunicipalityRepository({this.pending = false});

  final bool pending;
  final Completer<List<Municipality>> _completer =
      Completer<List<Municipality>>();

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) {
    if (pending) {
      return _completer.future;
    }
    return Future.value(_municipalities);
  }

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

void main() {
  group('municipality search providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          municipalityRepositoryProvider.overrideWithValue(
            _FakeMunicipalityRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(municipalityQueryProvider, (_, _) {});
      container.listen(filteredMunicipalitiesProvider('20'), (_, _) {});
    });

    Future<void> loadMunicipalities() async {
      await container.read(municipalitiesByDepartmentProvider('20').future);
      await container.pump();
    }

    test('empty query returns all municipalities', () async {
      await loadMunicipalities();

      final result = container.read(filteredMunicipalitiesProvider('20'));

      expect(result.value, _municipalities);
    });

    test('filters by query without accents', () async {
      await loadMunicipalities();
      container.read(municipalityQueryProvider.notifier).setQuery('agustin');

      final result = container.read(filteredMunicipalitiesProvider('20'));

      expect(result.value, [_municipalities[1]]);
    });

    test('returns an empty list when there are no matches', () async {
      await loadMunicipalities();
      container.read(municipalityQueryProvider.notifier).setQuery('xyz');

      final result = container.read(filteredMunicipalitiesProvider('20'));

      expect(result.value, isEmpty);
    });

    test('is loading while the repository is pending', () {
      final pendingContainer = ProviderContainer(
        overrides: [
          municipalityRepositoryProvider.overrideWithValue(
            _FakeMunicipalityRepository(pending: true),
          ),
        ],
      );
      addTearDown(pendingContainer.dispose);
      pendingContainer.listen(municipalityQueryProvider, (_, _) {});
      pendingContainer.listen(filteredMunicipalitiesProvider('20'), (_, _) {});

      final result = pendingContainer.read(
        filteredMunicipalitiesProvider('20'),
      );

      expect(result.isLoading, isTrue);
      expect(result, isA<AsyncLoading<List<Municipality>>>());
    });

    test('resolves a municipality by code and returns null when unknown',
        () async {
      container.listen(municipalityByCodeProvider('20001'), (_, _) {});
      container.listen(municipalityByCodeProvider('99999'), (_, _) {});

      final existing = await container.read(
        municipalityByCodeProvider('20001').future,
      );
      final missing = await container.read(
        municipalityByCodeProvider('99999').future,
      );

      expect(existing, _municipalities[0]);
      expect(missing, isNull);
    });
  });
}
