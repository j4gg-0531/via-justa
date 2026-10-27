import 'package:via_justa/core/utils/text_normalizer.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';

/// Filtra departamentos por nombre, sin distinguir mayúsculas ni tildes.
List<Department> searchDepartments(List<Department> all, String query) {
  if (query.trim().isEmpty) {
    return all;
  }
  final normalizedQuery = normalizeForSearch(query);
  return all
      .where((d) => normalizeForSearch(d.name).contains(normalizedQuery))
      .toList();
}
