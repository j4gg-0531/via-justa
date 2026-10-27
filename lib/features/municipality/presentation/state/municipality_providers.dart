import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/municipality/data/local_municipality_repository.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/domain/municipality_search.dart';

/// Proveedor del repositorio de municipios (único lugar que conoce la implementación concreta).
final municipalityRepositoryProvider = Provider<MunicipalityRepository>((ref) {
  return LocalMunicipalityRepository();
});

/// Proveedor de la lista de municipios por código de departamento.
final municipalitiesByDepartmentProvider =
    FutureProvider.family<List<Municipality>, String>((ref, departmentCode) {
  final repository = ref.watch(municipalityRepositoryProvider);
  return repository.getByDepartment(departmentCode);
});

/// Notificador del municipio seleccionado (para "ubicación actual").
class _SelectedMunicipalityNotifier extends Notifier<Municipality?> {
  @override
  Municipality? build() => null;

  void select(Municipality municipality) {
    state = municipality;
  }
}

/// Proveedor del municipio seleccionado.
final selectedMunicipalityProvider =
    NotifierProvider<_SelectedMunicipalityNotifier, Municipality?>(
  _SelectedMunicipalityNotifier.new,
);

/// Texto de búsqueda del selector de municipios.
class _MunicipalityQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }
}

/// Se descarta al salir de la pantalla para no recordar una búsqueda vieja.
final municipalityQueryProvider =
    NotifierProvider.autoDispose<_MunicipalityQueryNotifier, String>(
  _MunicipalityQueryNotifier.new,
);

/// Municipios de un departamento ya filtrados por la búsqueda actual.
final filteredMunicipalitiesProvider = Provider.autoDispose
    .family<AsyncValue<List<Municipality>>, String>((ref, departmentCode) {
  final query = ref.watch(municipalityQueryProvider);
  final municipalities = ref.watch(
    municipalitiesByDepartmentProvider(departmentCode),
  );
  return municipalities.whenData((all) => searchMunicipalities(all, query));
});
