import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/map_colombia/data/local_department_repository.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_repository.dart';
import 'package:via_justa/features/map_colombia/domain/department_search.dart';

/// Proveedor del repositorio de departamentos (único punto que conoce la implementación concreta).
final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return const LocalDepartmentRepository();
});

/// Catálogo completo de departamentos obtenido desde el repositorio.
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
