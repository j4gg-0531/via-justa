import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/data/local_price_map_repository.dart';
import 'package:via_justa/features/prices/data/supabase_price_map_repository.dart';
import 'package:via_justa/features/prices/domain/price_map_filter.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';

/// Indica si se debe renderizar el widget nativo `GoogleMap` (activo en dispositivos
/// Android/iOS reales; desactivado automáticamente en `flutter test` headless).
final useNativeGoogleMapProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  final isMobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!isMobile) return false;
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  if (bindingName.contains('TestWidgetsFlutterBinding') ||
      bindingName.contains('AutomatedTestWidgetsFlutterBinding')) {
    return false;
  }
  return true;
});

/// Provider del repositorio del mapa de precios, servicios y negocios (M08 / VJ-12).
final priceMapRepositoryProvider = Provider<PriceMapRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final bounds = ref.watch(priceMapViewportBoundsProvider);
  if (client != null) {
    return SupabasePriceMapRepository(
      client: client,
      bounds: bounds,
    );
  }
  return const LocalPriceMapRepository();
});

/// Notifier para el bounding box visible del mapa (con actualización bajo demanda).
class PriceMapViewportBoundsNotifier extends Notifier<MapViewportBounds?> {
  @override
  MapViewportBounds? build() => null;

  void updateBounds(MapViewportBounds? bounds) {
    state = bounds;
  }

  void clear() {
    state = null;
  }
}

/// Provider del área geográfica visible del mapa (o `null` para ver todo el municipio).
final priceMapViewportBoundsProvider =
    NotifierProvider<PriceMapViewportBoundsNotifier, MapViewportBounds?>(
  PriceMapViewportBoundsNotifier.new,
);

/// Estado de la ubicación GPS en vivo del usuario en el mapa del municipio.
class UserMapLocationState {
  const UserMapLocationState({
    this.latitude,
    this.longitude,
    this.permissionGranted = false,
    this.isRequesting = false,
  });

  final double? latitude;
  final double? longitude;
  final bool permissionGranted;
  final bool isRequesting;

  bool get hasLocation => latitude != null && longitude != null;

  UserMapLocationState copyWith({
    double? latitude,
    double? longitude,
    bool? permissionGranted,
    bool? isRequesting,
  }) {
    return UserMapLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      isRequesting: isRequesting ?? this.isRequesting,
    );
  }
}

/// Controlador de permisos y lectura GPS para el mapa de Google Maps (VJ-12).
class UserMapLocationNotifier extends Notifier<UserMapLocationState> {
  @override
  UserMapLocationState build() => const UserMapLocationState();

  /// Solicita permiso de ubicación al sistema Android y obtiene las coordenadas GPS actuales.
  Future<(double, double)?> requestAndFetchLocation() async {
    if (state.isRequesting) return null;
    state = state.copyWith(isRequesting: true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(isRequesting: false, permissionGranted: false);
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(isRequesting: false, permissionGranted: false);
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        permissionGranted: true,
        isRequesting: false,
      );
      return (position.latitude, position.longitude);
    } catch (_) {
      state = state.copyWith(isRequesting: false);
      return null;
    }
  }
}

/// Provider del estado de ubicación GPS del usuario en el mapa.
final userMapLocationProvider =
    NotifierProvider<UserMapLocationNotifier, UserMapLocationState>(
  UserMapLocationNotifier.new,
);

/// Notifier para la categoría activa en el filtro del mapa local.
class PriceMapCategoryNotifier extends Notifier<PriceMapCategory?> {
  @override
  PriceMapCategory? build() => null;

  void selectCategory(PriceMapCategory? category) {
    state = category;
  }

  /// Alterna una categoría: si ya estaba seleccionada, vuelve a mostrar todas (`null`).
  void toggleCategory(PriceMapCategory category) {
    state = state == category ? null : category;
  }

  void clear() {
    state = null;
  }
}

/// Provider de la categoría activa en el mapa local (`Precios`, `Servicios`, `Consulados` o `null`).
final priceMapCategoryProvider =
    NotifierProvider<PriceMapCategoryNotifier, PriceMapCategory?>(
  PriceMapCategoryNotifier.new,
);

/// Notifier para el texto de búsqueda en el mapa local.
class PriceMapSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider de la consulta de búsqueda en el mapa local.
final priceMapSearchQueryProvider =
    NotifierProvider<PriceMapSearchQueryNotifier, String>(
  PriceMapSearchQueryNotifier.new,
);

/// Provider que carga los puntos del mapa local (precios + negocios + servicios) para el municipio seleccionado.
/// También se actualiza automáticamente cuando el usuario confirma un nuevo aporte de precio.
final allPriceMapItemsProvider = FutureProvider<List<PriceMapItem>>((ref) async {
  // Escucha nuevos aportes confirmados para refrescar el mapa de inmediato.
  ref.watch(priceContributionProvider.select((s) => s.submittedRecord));
  final repository = ref.watch(priceMapRepositoryProvider);
  final municipality = ref.watch(selectedMunicipalityProvider);
  final code = municipality?.code ?? '20001';
  return repository.getMapItems(municipalityCode: code);
});

/// Provider que devuelve los puntos filtrados por categoría y texto mediante la función pura de dominio.
final filteredPriceMapItemsProvider =
    Provider<AsyncValue<List<PriceMapItem>>>((ref) {
  final itemsAsync = ref.watch(allPriceMapItemsProvider);
  final category = ref.watch(priceMapCategoryProvider);
  final query = ref.watch(priceMapSearchQueryProvider);

  return itemsAsync.whenData((items) {
    return filterPriceMapItems(
      items,
      category: category,
      query: query,
    );
  });
});

/// Provider de la clave de traducción para el título de la hoja inferior del mapa.
final priceMapSectionTitleKeyProvider = Provider<String>((ref) {
  final category = ref.watch(priceMapCategoryProvider);
  return sectionTitleKeyForMapCategory(category);
});
