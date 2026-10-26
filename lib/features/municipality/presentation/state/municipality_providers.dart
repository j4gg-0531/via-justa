import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/municipality/data/local_municipality_repository.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';

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