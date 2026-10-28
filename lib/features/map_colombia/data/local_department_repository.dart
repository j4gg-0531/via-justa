import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_repository.dart';

/// Implementación local (DEMO) del catálogo de departamentos.
class LocalDepartmentRepository implements DepartmentRepository {
  const LocalDepartmentRepository();

  @override
  List<Department> getAll() => Departments.all;

  @override
  Department? getByCode(String code) => Departments.byCode(code);
}
