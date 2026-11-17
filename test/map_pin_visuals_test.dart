import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_pin_visuals.dart';

void main() {
  test('mapPinIconForKind asigna un ícono semántico distinto a cada tipo', () {
    expect(mapPinIconForKind(PriceMapPinKind.food), Icons.restaurant);
    expect(mapPinIconForKind(PriceMapPinKind.transport), Icons.local_taxi);
    expect(mapPinIconForKind(PriceMapPinKind.lodging), Icons.hotel);
    expect(mapPinIconForKind(PriceMapPinKind.hospital), Icons.local_hospital);
    expect(
      mapPinIconForKind(PriceMapPinKind.assistance),
      Icons.volunteer_activism,
    );
    expect(
      mapPinIconForKind(PriceMapPinKind.consulate),
      Icons.account_balance,
    );
  });

  test('resolveMapPinStyle asigna colores de AppColors según semáforo y categoría', () {
    final fairFood = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.fair,
        category: PriceMapCategory.prices,
      ),
    );
    expect(fairFood.fillColor, AppColors.semaphoreGreen);
    expect(fairFood.icon, Icons.restaurant);

    final moderateTaxi = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.transport,
        status: PricePinStatus.moderate,
        category: PriceMapCategory.prices,
      ),
    );
    expect(moderateTaxi.fillColor, AppColors.semaphoreAmber);
    expect(moderateTaxi.icon, Icons.local_taxi);

    final alertPrice = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.alert,
        category: PriceMapCategory.prices,
      ),
    );
    expect(alertPrice.fillColor, AppColors.semaphoreRed);

    final restaurantPlace = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.info,
        category: PriceMapCategory.services,
      ),
    );
    expect(restaurantPlace.fillColor, AppColors.primary);
    expect(restaurantPlace.icon, Icons.restaurant);

    final consulatePlace = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.consulate,
        status: PricePinStatus.info,
        category: PriceMapCategory.consulates,
        selected: true,
      ),
    );
    expect(consulatePlace.fillColor, AppColors.textPrimary);
    expect(consulatePlace.selected, isTrue);
  });

  test('renderMapMarkerPngBytes genera PNG válido para pines normales y seleccionados', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final normalSpec = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.info,
        category: PriceMapCategory.services,
      ),
    );
    final selectedSpec = resolveMapPinStyle(
      const MapPinStyleKey(
        pinKind: PriceMapPinKind.hospital,
        status: PricePinStatus.info,
        category: PriceMapCategory.services,
        selected: true,
      ),
    );

    final normalBytes = await renderMapMarkerPngBytes(normalSpec, pixelRatio: 2.0);
    final selectedBytes = await renderMapMarkerPngBytes(
      selectedSpec,
      pixelRatio: 2.0,
    );

    expect(normalBytes.length, greaterThan(100));
    expect(normalBytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(selectedBytes.length, greaterThan(100));
    expect(selectedBytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('MapMarkerIconCache reutiliza descriptores cacheados y distingue pines seleccionados', () async {
    var buildCalls = 0;
    final cache = MapMarkerIconCache(
      descriptorBuilder: (key) async {
        buildCalls++;
        return BitmapDescriptor.defaultMarkerWithHue(
          key.selected ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure,
        );
      },
    );

    const items = [
      PriceMapItem(
        id: 'biz-1',
        name: 'Buen Restaurante',
        description: 'Comida casera',
        category: PriceMapCategory.services,
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.info,
        pinLabel: '',
        badgeText: 'Calle 50',
        normalizedX: 0.5,
        normalizedY: 0.5,
        municipalityCode: '20001',
        sourceType: 'business',
        isDemo: false,
      ),
      PriceMapItem(
        id: 'biz-2',
        name: 'Otro Restaurante',
        description: 'Desayunos',
        category: PriceMapCategory.services,
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.info,
        pinLabel: '',
        badgeText: 'Calle 12',
        normalizedX: 0.3,
        normalizedY: 0.3,
        municipalityCode: '20001',
        sourceType: 'business',
        isDemo: false,
      ),
    ];

    final first = await cache.resolveForItems(items);
    expect(first.length, 1);
    expect(buildCalls, 1);

    // Misma lista sin selección reutiliza caché (0 construcciones nuevas)
    await cache.resolveForItems(items);
    expect(buildCalls, 1);

    // Al seleccionar biz-1 solo se genera 1 descriptor nuevo (selected: true)
    final withSelection = await cache.resolveForItems(
      items,
      selectedItemId: 'biz-1',
    );
    expect(withSelection.length, 2);
    expect(buildCalls, 2);
  });
}
