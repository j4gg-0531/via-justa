import 'package:via_justa/features/map_colombia/domain/department.dart';

/// Contrato abstracto para consultar el catálogo de departamentos (preparado para Supabase `public.departments`).
abstract class DepartmentRepository {
  /// Retorna la lista de departamentos del catálogo.
  List<Department> getAll();

  /// Resuelve un departamento por su código DANE de 2 dígitos (ej. `'20'`).
  Department? getByCode(String code);
}
