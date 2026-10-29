import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/map_colombia/data/local_department_shape_repository.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_hit_test.dart';
import 'package:via_justa/features/map_colombia/domain/department_search.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape_repository.dart';
import 'package:via_justa/features/map_colombia/presentation/pages/map_page.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';

class _PreloadedShapeRepository implements DepartmentShapeRepository {
  const _PreloadedShapeRepository(this.geometry);

  final ColombiaMapGeometry geometry;

  @override
  Future<ColombiaMapGeometry> getGeometry() async => geometry;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ColombiaMapGeometry realGeometry;

  setUpAll(() async {
    realGeometry = await LocalDepartmentShapeRepository().getGeometry();
  });

  group('searchDepartments and DANE catalog (32 departments + Bogotá D.C. = 33)', () {
    test('empty query returns all 33 territorial entities', () {
      expect(Departments.all.length, 33);
      expect(searchDepartments(Departments.all, ''), Departments.all);
      expect(searchDepartments(Departments.all, '   '), Departments.all);
    });

    test('finds Cesar ignoring case and verifies only Cesar is pilot', () {
      expect(searchDepartments(Departments.all, 'CESAR'), [Departments.cesar]);
      expect(Departments.cesar.isAvailable, isTrue);
      expect(Departments.byCode('20'), Departments.cesar);
      expect(
        Departments.all.where((d) => d.isAvailable).toList(),
        [Departments.cesar],
      );
    });

    test('finds La Guajira by partial name', () {
      expect(searchDepartments(Departments.all, 'guaj'), [
        Departments.laGuajira,
      ]);
    });

    test('finds departments ignoring accents (Bogotá, Nariño, Atlántico, Córdoba)', () {
      expect(searchDepartments(Departments.all, 'bogota'), [
        Departments.bogotaDc,
      ]);
      expect(searchDepartments(Departments.all, 'narino'), [
        Departments.narino,
      ]);
      expect(searchDepartments(Departments.all, 'atlantico'), [
        Departments.atlantico,
      ]);
      expect(searchDepartments(Departments.all, 'cordoba'), [
        Departments.cordoba,
      ]);
    });

    test('returns an empty list when there are no matches', () {
      expect(searchDepartments(Departments.all, 'xyz'), isEmpty);
    });
  });

  group('LocalDepartmentShapeRepository and catalog/geometry parity (33 == 33)', () {
    test('loads real colombia_departments_geo.json with 33 territories and valid bounds', () {
      expect(realGeometry.shapes.length, 33);
      expect(realGeometry.bounds.width, greaterThan(700));
      expect(realGeometry.bounds.height, greaterThan(800));
    });

    test('every DANE code in Departments.all has geometry and vice versa (33 and 33)', () {
      final catalogCodes = Departments.all.map((d) => d.code).toSet();
      final shapeCodes = realGeometry.shapes.map((s) => s.code).toSet();

      expect(catalogCodes.length, 33);
      expect(shapeCodes.length, 33);
      expect(shapeCodes, equals(catalogCodes));

      final joined = joinDepartmentsWithShapes(
        departments: Departments.all,
        shapes: realGeometry.shapes,
      );
      expect(joined.length, 33);
    });
  });

  group('findDepartmentAtPoint on real SVG rings (Cesar, Sea, Providencia, Bogotá)', () {
    test('point inside Cesar ring returns code 20', () {
      final cesarShape = realGeometry.shapeByCode('20')!;
      final cesarInteriorPoint = cesarShape.primaryCenter;

      expect(
        findDepartmentAtPoint(realGeometry.shapes, cesarInteriorPoint),
        '20',
      );
    });

    test('point in the Caribbean/Pacific sea returns null', () {
      const seaPoint = MapPoint(150.0, 200.0);
      expect(findDepartmentAtPoint(realGeometry.shapes, seaPoint), isNull);
    });

    test('real averaged interior point in Providencia island ring returns code 88', () {
      final sanAndresShape = realGeometry.shapeByCode('88')!;
      expect(sanAndresShape.rings.length, greaterThanOrEqualTo(2));

      // Ring 0 is San Andrés island; Ring 1 is Providencia island in colombia_departments_geo.json
      final sanAndresIslandCenter = calculateRingCenter(sanAndresShape.rings[0]);
      final providenciaIslandCenter = calculateRingCenter(sanAndresShape.rings[1]);

      expect(
        findDepartmentAtPoint(realGeometry.shapes, sanAndresIslandCenter),
        '88',
      );
      expect(
        findDepartmentAtPoint(realGeometry.shapes, providenciaIslandCenter),
        '88',
      );
    });

    test('prioritizes Bogotá D.C. (11) enclave over surrounding Cundinamarca (25)', () {
      final bogotaShape = realGeometry.shapeByCode('11')!;
      final bogotaCenter = bogotaShape.primaryCenter;

      expect(
        findDepartmentAtPoint(realGeometry.shapes, bogotaCenter),
        '11',
      );
    });
  });

  group('MapPage widget test (360x780 @ 1.5x text scale)', () {
    testWidgets('MapPage renders real Colombia map and selects department without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          departmentShapeRepositoryProvider.overrideWithValue(
            _PreloadedShapeRepository(realGeometry),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default selected department is Cesar ('20')
      expect(container.read(selectedDepartmentProvider), Departments.cesar);
      expect(find.text('Cesar'), findsWidgets);

      // Select Antioquia ('05') via real SVG interior point
      final antioquiaCenter = realGeometry.shapeByCode('05')!.primaryCenter;
      final hit = container
          .read(selectedDepartmentProvider.notifier)
          .selectAtMapPoint(antioquiaCenter);
      await tester.pumpAndSettle();

      expect(hit, Departments.antioquia);
      expect(find.text('Antioquia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
