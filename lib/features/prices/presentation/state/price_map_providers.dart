import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/data/local_price_map_repository.dart';
import 'package:via_justa/features/prices/data/supabase_price_map_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_map_filter.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_pin_visuals.dart';

export 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart'
    show deviceLocationGatewayProvider;

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

/// Indica si el mapa está operando con datos de demostración o conectado a Supabase real.
final isDemoMapModeProvider = Provider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final usesDemo = ref.watch(
    authControllerProvider.select((state) => state.usesDemoData),
  );
  return client == null || usesDemo;
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
    this.errorKey,
  });

  final double? latitude;
  final double? longitude;
  final bool permissionGranted;
  final bool isRequesting;
  final String? errorKey;

  bool get hasLocation => latitude != null && longitude != null;

  UserMapLocationState copyWith({
    double? latitude,
    double? longitude,
    bool? permissionGranted,
    bool? isRequesting,
    String? errorKey,
    bool clearError = false,
  }) {
    return UserMapLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      isRequesting: isRequesting ?? this.isRequesting,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
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
    state = state.copyWith(isRequesting: true, clearError: true);
    try {
      final result = await ref
          .read(deviceLocationGatewayProvider)
          .fetchCurrentPosition();
      if (!ref.mounted) return null;

      if (!result.isGranted) {
        state = state.copyWith(
          isRequesting: false,
          permissionGranted: false,
          errorKey: result.errorKey ?? 'gps_unavailable',
        );
        return null;
      }

      state = state.copyWith(
        latitude: result.latitude,
        longitude: result.longitude,
        permissionGranted: true,
        isRequesting: false,
        clearError: true,
      );
      return (result.latitude!, result.longitude!);
    } catch (_) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        isRequesting: false,
        errorKey: 'gps_unavailable',
      );
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

/// Identificador del pin actualmente seleccionado en el mapa para destacarlo en la hoja inferior.
class SelectedMapItemIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}

final selectedMapItemIdProvider =
    NotifierProvider<SelectedMapItemIdNotifier, String?>(
  SelectedMapItemIdNotifier.new,
);

/// Controla si el listado inferior de lugares está expandido (Opción A).
class PriceMapListOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void open() {
    if (!state) state = true;
  }

  void close() {
    if (state) state = false;
  }
}

final priceMapListOpenProvider =
    NotifierProvider.autoDispose<PriceMapListOpenNotifier, bool>(
  PriceMapListOpenNotifier.new,
);

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

/// Provider que filtra únicamente lugares reales (negocios, servicios y consulados) para la hoja inferior.
final sheetPlaceItemsProvider =
    Provider<AsyncValue<List<PriceMapItem>>>((ref) {
  final itemsAsync = ref.watch(allPriceMapItemsProvider);
  final category = ref.watch(priceMapCategoryProvider);
  final query = ref.watch(priceMapSearchQueryProvider);
  final prioritizedId = ref.watch(selectedMapItemIdProvider);

  return itemsAsync.whenData((items) {
    return filterSheetPlaceItems(
      items,
      category: category,
      query: query,
      prioritizedId: prioritizedId,
    );
  });
});

/// Devuelve el elemento actualmente seleccionado mediante el identificador del pin tocado.
final selectedMapPlaceItemProvider = Provider<PriceMapItem?>((ref) {
  final items = ref.watch(filteredPriceMapItemsProvider).asData?.value;
  final selectedId = ref.watch(selectedMapItemIdProvider);
  if (items == null || selectedId == null) return null;
  return findMapItemById(items, selectedId);
});

/// Provider de la clave de traducción para el título de la hoja inferior del mapa.
final priceMapSectionTitleKeyProvider = Provider<String>((ref) {
  final category = ref.watch(priceMapCategoryProvider);
  return sectionTitleKeyForMapCategory(category);
});

/// Caché compartida en memoria para descriptores de marcadores personalizados de Google Maps.
final mapMarkerIconCacheProvider = Provider<MapMarkerIconCache>((ref) {
  return MapMarkerIconCache();
});

/// Descriptores PNG renderizados por ícono y semáforo para los marcadores visibles del mapa.
final mapMarkerDescriptorsProvider =
    FutureProvider<Map<MapPinStyleKey, BitmapDescriptor>>((ref) async {
  final useNative = ref.watch(useNativeGoogleMapProvider);
  if (!useNative) {
    return const <MapPinStyleKey, BitmapDescriptor>{};
  }
  final items = ref.watch(filteredPriceMapItemsProvider).asData?.value;
  if (items == null || items.isEmpty) {
    return const <MapPinStyleKey, BitmapDescriptor>{};
  }
  final selectedId = ref.watch(selectedMapItemIdProvider);
  final cache = ref.watch(mapMarkerIconCacheProvider);
  return cache.resolveForItems(items, selectedItemId: selectedId);
});


/// Resultado y estado activo de selección de un punto preciso en el mapa municipal.
class PickedMapPoint {
  const PickedMapPoint({
    required this.zoneId,
    required this.latitude,
    required this.longitude,
    required this.normalizedX,
    required this.normalizedY,
  });

  final String zoneId;
  final double latitude;
  final double longitude;
  final double normalizedX;
  final double normalizedY;
}

/// Notifier para el selector modal de punto en el mapa (`showMapPointPickerSheet`).
class MapPointPickerNotifier extends Notifier<PickedMapPoint> {
  @override
  PickedMapPoint build() {
    return const PickedMapPoint(
      zoneId: 'vup_centro',
      latitude: 10.4742,
      longitude: -73.2436,
      normalizedX: 0.50,
      normalizedY: 0.50,
    );
  }

  void initialize({
    required List<MunicipalityZone> zones,
    required String initialZoneId,
    double? initialLatitude,
    double? initialLongitude,
  }) {
    MunicipalityZone? initialZone;
    for (final z in zones) {
      if (z.id == initialZoneId) {
        initialZone = z;
        break;
      }
    }
    initialZone ??= zones.isNotEmpty ? zones.first : null;
    state = PickedMapPoint(
      zoneId: initialZone?.id ?? initialZoneId,
      latitude: initialLatitude ?? initialZone?.centerLat ?? 10.4742,
      longitude: initialLongitude ?? initialZone?.centerLng ?? -73.2436,
      normalizedX: initialZone?.normalizedX ?? 0.50,
      normalizedY: initialZone?.normalizedY ?? 0.50,
    );
  }

  void selectCoordinates({
    required List<MunicipalityZone> zones,
    required double latitude,
    required double longitude,
  }) {
    final nearest = resolveNearestZoneByCoordinates(
      zones: zones,
      latitude: latitude,
      longitude: longitude,
    );
    state = PickedMapPoint(
      zoneId: nearest?.id ?? state.zoneId,
      latitude: latitude,
      longitude: longitude,
      normalizedX: nearest?.normalizedX ?? state.normalizedX,
      normalizedY: nearest?.normalizedY ?? state.normalizedY,
    );
  }

  void selectNormalizedPoint({
    required List<MunicipalityZone> zones,
    required double normalizedX,
    required double normalizedY,
  }) {
    final nearest = resolveNearestZoneByNormalizedPoint(
      zones: zones,
      normalizedX: normalizedX,
      normalizedY: normalizedY,
    );
    if (nearest == null) return;
    state = PickedMapPoint(
      zoneId: nearest.id,
      latitude: nearest.centerLat,
      longitude: nearest.centerLng,
      normalizedX: normalizedX.clamp(0.08, 0.92),
      normalizedY: normalizedY.clamp(0.10, 0.90),
    );
  }

  void selectZone(MunicipalityZone zone) {
    state = PickedMapPoint(
      zoneId: zone.id,
      latitude: zone.centerLat,
      longitude: zone.centerLng,
      normalizedX: zone.normalizedX,
      normalizedY: zone.normalizedY,
    );
  }
}

/// Provider del punto activo en la hoja inferior de selección de mapa.
final mapPointPickerProvider =
    NotifierProvider<MapPointPickerNotifier, PickedMapPoint>(
  MapPointPickerNotifier.new,
);
