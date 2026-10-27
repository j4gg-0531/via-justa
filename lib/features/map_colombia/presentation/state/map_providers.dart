import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_search.dart';

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

/// Departamentos que coinciden con la búsqueda actual.
final filteredDepartmentsProvider = Provider.autoDispose<List<Department>>((
  ref,
) {
  final query = ref.watch(departmentQueryProvider);
  return searchDepartments(Departments.all, query);
});
