import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/city/data/demo_city_repository.dart';
import 'package:via_justa/features/city/data/device_city_external_launcher.dart';
import 'package:via_justa/features/city/data/supabase_city_repository.dart';
import 'package:via_justa/features/city/domain/city_external_launcher.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_overview_rules.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

/// Parámetro compuesto para consultar la vista cultural según municipio e idioma.
typedef CityOverviewRequest = ({String municipalityCode, String localeCode});

/// Proveedor del repositorio de ciudad (único lugar que conoce las implementaciones concretas).
final cityRepositoryProvider = Provider<CityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    return SupabaseCityRepository(client);
  }
  return DemoCityRepository();
});

/// Proveedor del adaptador de apertura segura de fuentes externas (`https://`).
final cityExternalLauncherProvider = Provider<CityExternalLauncher>((ref) {
  return const DeviceCityExternalLauncher();
});

/// Código DIVIPOLA del municipio activo (por defecto Valledupar `'20001'`).
final activeMunicipalityCodeProvider = Provider<String>((ref) {
  final municipality = ref.watch(selectedMunicipalityProvider);
  return municipality?.code ?? '20001';
});

/// Carga el panorama cultural bilingüe y los eventos oficiales de un municipio piloto.
final cityOverviewProvider =
    FutureProvider.autoDispose.family<CityOverview, CityOverviewRequest>(
  (ref, request) {
    final repository = ref.watch(cityRepositoryProvider);
    final isDemoMode = ref.watch(isDemoModeProvider);
    return repository.getCityOverview(
      municipalityCode: request.municipalityCode,
      localeCode: normalizeCityLocale(request.localeCode),
      includeDemo: isDemoMode,
    );
  },
  // El fallo se entrega de inmediato a la UI para mostrar mensaje honesto y
  // botón manual de reintento, sin reintentos silenciosos en segundo plano.
  retry: (retryCount, error) => null,
);

/// Sección seleccionada en la vista cultural (`null` muestra todas las secciones).
class SelectedCitySectionNotifier extends Notifier<CityContentSection?> {
  @override
  CityContentSection? build() => null;

  void select(CityContentSection? section) {
    state = section;
  }

  void clear() {
    state = null;
  }
}

/// Se descarta al salir de la vista cultural para iniciar siempre en "Todas".
final selectedCitySectionProvider =
    NotifierProvider.autoDispose<SelectedCitySectionNotifier, CityContentSection?>(
  SelectedCitySectionNotifier.new,
);

/// Secciones disponibles en la ficha cultural cargada, en orden canónico.
final cityAvailableSectionsProvider = Provider.autoDispose
    .family<List<CityContentSection>, CityOverviewRequest>((ref, request) {
  final overview = ref.watch(cityOverviewProvider(request)).asData?.value;
  if (overview == null) return const <CityContentSection>[];
  return availableCitySections(overview.content);
});

/// Fichas culturales filtradas y ordenadas según [selectedCitySectionProvider].
final filteredCityContentProvider = Provider.autoDispose
    .family<AsyncValue<List<CityContentItem>>, CityOverviewRequest>((
  ref,
  request,
) {
  final selectedSection = ref.watch(selectedCitySectionProvider);
  final overview = ref.watch(cityOverviewProvider(request));
  return overview.whenData(
    (data) => filterCityContentBySection(data.content, selectedSection),
  );
});

/// Eventos municipales evaluados con ventana temporal (`active`, `upcoming`, `past`).
final cityEventsProvider =
    FutureProvider.autoDispose.family<List<CityEvent>, String>(
  (ref, municipalityCode) {
    final repository = ref.watch(cityRepositoryProvider);
    final isDemoMode = ref.watch(isDemoModeProvider);
    return repository.getCityEvents(
      municipalityCode: municipalityCode,
      includeDemo: isDemoMode,
    );
  },
  retry: (retryCount, error) => null,
);

/// Decisión del banner de eventos reales para `HomePage`.
final homeCityEventBannerProvider =
    Provider.autoDispose<AsyncValue<CityEventBannerDecision>>((ref) {
  final code = ref.watch(activeMunicipalityCodeProvider);
  final isDemoMode = ref.watch(isDemoModeProvider);
  final events = ref.watch(cityEventsProvider(code));
  return events.whenData(
    (list) => selectCityEventBanner(list, isDemoMode: isDemoMode),
  );
});
