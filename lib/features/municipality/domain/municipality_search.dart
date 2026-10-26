import 'package:via_justa/core/utils/text_normalizer.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';

/// Filtra la lista de municipios por la consulta normalizada.
List<Municipality> searchMunicipalities(List<Municipality> all, String query) {
  if (query.trim().isEmpty) {
    return all;
  }
  final normalizedQuery = normalizeForSearch(query);
  return all
      .where((m) => normalizeForSearch(m.name).contains(normalizedQuery))
      .toList();
}