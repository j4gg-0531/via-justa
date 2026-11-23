import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';
import 'package:via_justa/features/municipality/domain/city_landmark.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_grouping.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

const _sampleMunicipalities = <Municipality>[
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
  Municipality(
    code: '20570',
    name: 'Pueblo Bello',
    departmentCode: '20',
    isPilot: false,
  ),
];

class _FakeMunicipalityRepository implements MunicipalityRepository {
  const _FakeMunicipalityRepository();

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async {
    if (departmentCode == '20') return _sampleMunicipalities;
    return const <Municipality>[];
  }

  @override
  Future<Municipality?> getByCode(String code) async {
    for (final item in _sampleMunicipalities) {
      if (item.code == code) return item;
    }
    return null;
  }
}

void main() {
  group('CityLandmarkCatalog (domain)', () {
    test('Valledupar (20001) exposes 4 verified CC landmarks with distinct hero and cover', () {
      final landmarks = CityLandmarkCatalog.forMunicipality('20001');
      expect(landmarks.length, 4);

      for (final landmark in landmarks) {
        expect(
          landmark.assetPath,
          startsWith('assets/images/cities/valledupar/'),
        );
        expect(landmark.author, isNotEmpty);
        expect(landmark.license, contains('CC'));
        expect(landmark.sourceUrl, startsWith('https://commons.wikimedia.org/'));
        expect(landmark.attributionLabel, contains(landmark.author));
        expect(landmark.attributionLabel, contains(landmark.license));
      }

      final cover = CityLandmarkCatalog.coverForMunicipality('20001');
      final hero = CityLandmarkCatalog.editorialHeroForMunicipality('20001');
      expect(cover, isNotNull);
      expect(hero, isNotNull);
      expect(cover!.id, isNot(hero!.id));
    });

    test('non-pilot municipalities return empty landmarks so they fall back to regional art', () {
      expect(CityLandmarkCatalog.forMunicipality('20011'), isEmpty);
      expect(CityLandmarkCatalog.coverForMunicipality('20011'), isNull);
      expect(CityLandmarkCatalog.editorialHeroForMunicipality('20011'), isNull);
    });
  });

  group('partitionMunicipalities & clampGalleryIndex (domain)', () {
    test('separates pilot and upcoming municipalities preserving order', () {
      final partition = partitionMunicipalities(_sampleMunicipalities);

      expect(partition.pilot.map((m) => m.code).toList(), <String>['20001']);
      expect(
        partition.upcoming.map((m) => m.code).toList(),
        <String>['20011', '20570'],
      );
      expect(partition.totalCount, 3);
      expect(partition.isEmpty, isFalse);
    });

    test('handles empty input cleanly', () {
      final partition = partitionMunicipalities(const <Municipality>[]);
      expect(partition.pilot, isEmpty);
      expect(partition.upcoming, isEmpty);
      expect(partition.isEmpty, isTrue);
    });

    test('clampGalleryIndex clamps within valid slide bounds', () {
      expect(clampGalleryIndex(-2, 4), 0);
      expect(clampGalleryIndex(2, 4), 2);
      expect(clampGalleryIndex(10, 4), 3);
      expect(clampGalleryIndex(3, 0), 0);
    });
  });

  group('CityContentItem.safeLicensedAssetPath (domain)', () {
    CityContentItem buildItem({String? imagePath, String? imageLicense}) {
      return CityContentItem(
        id: 'id',
        municipalityCode: '20001',
        slug: 'slug',
        section: CityContentSection.places,
        requestedLocale: 'es',
        resolvedLocale: 'es',
        isLocaleFallback: false,
        title: 'Title',
        body: 'Body',
        imagePath: imagePath,
        imageLicense: imageLicense,
        sourceCitation: 'Source',
      );
    }

    test('allows local assets/images/ path only when explicit license is present', () {
      final valid = buildItem(
        imagePath: 'assets/images/cities/valledupar/rio_guatapuri.jpg',
        imageLicense: 'CC BY-SA 3.0 — Idaligomezmartinez (Wikimedia Commons)',
      );
      expect(
        valid.safeLicensedAssetPath,
        'assets/images/cities/valledupar/rio_guatapuri.jpg',
      );
      expect(valid.safeLicensedImageUri, isNull);
    });

    test('rejects missing license, traversal, and remote URLs', () {
      final missingLicense = buildItem(
        imagePath: 'assets/images/cities/valledupar/rio_guatapuri.jpg',
        imageLicense: null,
      );
      final traversal = buildItem(
        imagePath: 'assets/images/../secrets.jpg',
        imageLicense: 'CC0',
      );
      final remote = buildItem(
        imagePath: 'https://commons.wikimedia.org/photo.jpg',
        imageLicense: 'CC BY-SA 3.0',
      );

      expect(missingLicense.safeLicensedAssetPath, isNull);
      expect(traversal.safeLicensedAssetPath, isNull);
      expect(remote.safeLicensedAssetPath, isNull);
      expect(remote.safeLicensedImageUri, isNotNull);
    });
  });

  group('ProviderContainer tests for redesign state providers', () {
    test('partitionedMunicipalitiesProvider and departmentMunicipalityCountProvider combine repo + domain', () async {
      final container = ProviderContainer(
        overrides: [
          municipalityRepositoryProvider.overrideWithValue(
            const _FakeMunicipalityRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(partitionedMunicipalitiesProvider('20'), (_, _) {});
      container.listen(departmentMunicipalityCountProvider('20'), (_, _) {});
      await container.read(municipalitiesByDepartmentProvider('20').future);
      await container.pump();

      final partition =
          container.read(partitionedMunicipalitiesProvider('20')).value!;
      expect(partition.pilot.single.code, '20001');
      expect(partition.upcoming.length, 2);
      expect(container.read(departmentMunicipalityCountProvider('20')), 3);

      // Search filters both partitions reactively
      container.read(municipalityQueryProvider.notifier).setQuery('pueblo');
      final filtered =
          container.read(partitionedMunicipalitiesProvider('20')).value!;
      expect(filtered.pilot, isEmpty);
      expect(filtered.upcoming.single.name, 'Pueblo Bello');
    });

    test('municipalityGalleryIndexProvider clamps slide changes without view setState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(municipalityGalleryIndexProvider, (_, _) {});

      expect(container.read(municipalityGalleryIndexProvider), 0);
      container
          .read(municipalityGalleryIndexProvider.notifier)
          .selectIndex(3, total: 4);
      expect(container.read(municipalityGalleryIndexProvider), 3);

      container
          .read(municipalityGalleryIndexProvider.notifier)
          .selectIndex(99, total: 4);
      expect(container.read(municipalityGalleryIndexProvider), 3);
    });

    test('selectedDepartmentProvider starts null (white map), selects, and clears', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(selectedDepartmentProvider, (_, _) {});

      expect(container.read(selectedDepartmentProvider), isNull);
      container
          .read(selectedDepartmentProvider.notifier)
          .selectDepartment(Departments.cesar);
      expect(container.read(selectedDepartmentProvider), Departments.cesar);

      container.read(selectedDepartmentProvider.notifier).clear();
      expect(container.read(selectedDepartmentProvider), isNull);
    });
  });
}
