import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/map_colombia/data/local_department_repository.dart';
import 'package:via_justa/features/map_colombia/data/local_department_shape_repository.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_hit_test.dart';
import 'package:via_justa/features/map_colombia/domain/department_repository.dart';
import 'package:via_justa/features/map_colombia/domain/department_search.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape_repository.dart';

/// Proveedor del repositorio de departamentos (único punto que conoce la implementación concreta).
final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return const LocalDepartmentRepository();
});

/// Catálogo completo de los 33 territorios (32 departamentos y Bogotá, D.C.) obtenido síncronamente.
final allDepartmentsProvider = Provider<List<Department>>((ref) {
  return ref.watch(departmentRepositoryProvider).getAll();
});

/// Resuelve un departamento por su código DANE de 2 dígitos.
final departmentByCodeProvider = Provider.family<Department?, String>((
  ref,
  code,
) {
  return ref.watch(departmentRepositoryProvider).getByCode(code);
});

/// Proveedor del repositorio asíncrono de formas vectoriales del mapa de Colombia.
/// Único punto de la app que conoce `LocalDepartmentShapeRepository`.
final departmentShapeRepositoryProvider = Provider<DepartmentShapeRepository>((
  ref,
) {
  return LocalDepartmentShapeRepository();
});

/// Geometría vectorial de los 33 territorios de Colombia cargada desde el asset JSON.
final colombiaMapGeometryProvider = FutureProvider<ColombiaMapGeometry>((ref) {
  return ref.watch(departmentShapeRepositoryProvider).getGeometry();
});

/// Une las formas vectoriales con el catálogo de departamentos por su código DANE de 2 dígitos.
final colombiaMapFeaturesProvider = Provider<List<DepartmentMapFeature>>((ref) {
  final departments = ref.watch(allDepartmentsProvider);
  final geometryAsync = ref.watch(colombiaMapGeometryProvider);
  final geometry = geometryAsync.value;
  if (geometry == null) {
    return const <DepartmentMapFeature>[];
  }
  return joinDepartmentsWithShapes(
    departments: departments,
    shapes: geometry.shapes,
  );
});

/// Departamento actualmente resaltado en el mapa de Colombia (por defecto Cesar).
class SelectedDepartmentNotifier extends Notifier<Department> {
  @override
  Department build() => Departments.cesar;

  void selectDepartment(Department department) {
    state = department;
  }

  /// Selecciona un departamento a partir de su código DANE de 2 dígitos.
  Department? selectByCode(String code) {
    final department = ref.read(departmentRepositoryProvider).getByCode(code);
    if (department != null) {
      state = department;
    }
    return department;
  }

  /// Resuelve qué territorio fue tocado en las coordenadas del SVG (`point`)
  /// y lo une con el catálogo por su código DANE.
  Department? selectAtMapPoint(MapPoint point) {
    final geometry = ref.read(colombiaMapGeometryProvider).value;
    if (geometry == null) return null;
    final code = findDepartmentAtPoint(geometry.shapes, point);
    if (code == null) return null;
    return selectByCode(code);
  }

  /// Resuelve qué territorio fue tocado en las coordenadas locales `(dx, dy)` del lienzo
  /// ajustado a `bounds` y actualiza el departamento seleccionado.
  Department? selectAtCanvasOffset(double dx, double dy) {
    final geometry = ref.read(colombiaMapGeometryProvider).value;
    if (geometry == null) return null;
    final svgPoint = geometry.canvasOffsetToSvgPoint(dx, dy);
    return selectAtMapPoint(svgPoint);
  }
}

final selectedDepartmentProvider =
    NotifierProvider.autoDispose<SelectedDepartmentNotifier, Department>(
      SelectedDepartmentNotifier.new,
    );

/// Texto de búsqueda del mapa de departamentos.
class _DepartmentQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }
}

final departmentQueryProvider =
    NotifierProvider.autoDispose<_DepartmentQueryNotifier, String>(
      _DepartmentQueryNotifier.new,
    );

/// Indica si hay una consulta activa en el buscador de departamentos.
final hasDepartmentQueryProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(departmentQueryProvider).trim().isNotEmpty;
});

/// Departamentos que coinciden con la búsqueda actual.
final filteredDepartmentsProvider = Provider.autoDispose<List<Department>>((
  ref,
) {
  final all = ref.watch(allDepartmentsProvider);
  final query = ref.watch(departmentQueryProvider);
  return searchDepartments(all, query);
});
