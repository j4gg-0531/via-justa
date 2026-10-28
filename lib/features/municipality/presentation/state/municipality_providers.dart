import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';
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

/// Municipio resuelto por código (funciona aunque la ruta se abra directo).
final municipalityByCodeProvider =
    FutureProvider.autoDispose.family<Municipality?, String>((ref, code) {
  final repository = ref.watch(municipalityRepositoryProvider);
  return repository.getByCode(code);
});

/// Notificador del municipio seleccionado (para "ubicación actual").
class _SelectedMunicipalityNotifier extends Notifier<Municipality?> {
  @override
  Municipality? build() => null;

  void select(Municipality municipality) {
    state = municipality;
  }

  void clear() {
    state = null;
  }
}

/// Proveedor del municipio seleccionado.
final selectedMunicipalityProvider =
    NotifierProvider<_SelectedMunicipalityNotifier, Municipality?>(
  _SelectedMunicipalityNotifier.new,
);

/// Etiqueta formateada de ubicación activa ("Municipio, Departamento") o null si aún no se ha elegido.
final selectedLocationLabelProvider = Provider<String?>((ref) {
  final municipality = ref.watch(selectedMunicipalityProvider);
  if (municipality == null) return null;
  final department = ref.watch(
    departmentByCodeProvider(municipality.departmentCode),
  );
  if (department != null) {
    return '${municipality.name}, ${department.name}';
  }
  return municipality.name;
});

/// Nombre corto del municipio activo (por defecto "Valledupar" como ciudad piloto).
final activeCityNameProvider = Provider<String>((ref) {
  final municipality = ref.watch(selectedMunicipalityProvider);
  return municipality?.name ?? 'Valledupar';
});

/// Texto de búsqueda del selector de municipios.
class _MunicipalityQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }

  void clear() {
    state = '';
  }
}

/// Se descarta al salir de la pantalla para no recordar una búsqueda vieja.
final municipalityQueryProvider =
    NotifierProvider.autoDispose<_MunicipalityQueryNotifier, String>(
  _MunicipalityQueryNotifier.new,
);

/// Indica si el usuario escribió texto válido en el buscador de municipios.
final hasMunicipalityQueryProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(municipalityQueryProvider).trim().isNotEmpty;
});

/// Municipios de un departamento ya filtrados por la búsqueda actual.
final filteredMunicipalitiesProvider = Provider.autoDispose
    .family<AsyncValue<List<Municipality>>, String>((ref, departmentCode) {
  final query = ref.watch(municipalityQueryProvider);
  final municipalities = ref.watch(
    municipalitiesByDepartmentProvider(departmentCode),
  );
  return municipalities.whenData((all) => searchMunicipalities(all, query));
});

/// Códigos de municipios en los que el usuario pidió ser notificado.
/// Solo en memoria: preparado para conectar con `public.interest_registrations` en Supabase.
class _MunicipalityInterestNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void register(String municipalityCode) {
    state = {...state, municipalityCode};
  }

  void clear() {
    state = const <String>{};
  }
}

final municipalityInterestProvider =
    NotifierProvider<_MunicipalityInterestNotifier, Set<String>>(
  _MunicipalityInterestNotifier.new,
);

/// Indica si el usuario ya registró interés de apertura para un municipio específico.
final isMunicipalityInterestedProvider = Provider.family<bool, String>((
  ref,
  municipalityCode,
) {
  return ref.watch(municipalityInterestProvider).contains(municipalityCode);
});
