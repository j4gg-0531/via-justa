import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/security/external_uri_guard.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_pin_visuals.dart';

/// Pantalla 13 (M08 / VJ-12) · Mapa interactivo de Google Maps con precios, comercios y servicios del municipio seleccionado.
class PriceMapPage extends ConsumerStatefulWidget {
  const PriceMapPage({super.key});

  @override
  ConsumerState<PriceMapPage> createState() => _PriceMapPageState();
}

class _PriceMapPageState extends ConsumerState<PriceMapPage> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _openList() => ref.read(priceMapListOpenProvider.notifier).open();

  void _closeList() => ref.read(priceMapListOpenProvider.notifier).close();

  void _openBusinessDetail(BuildContext context, String businessId) {
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.businessDetailPath(businessId));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BusinessDetailPage(businessId: businessId),
        ),
      );
    }
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  double _markerHueForItem(PriceMapItem item) {
    switch (item.status) {
      case PricePinStatus.fair:
        return BitmapDescriptor.hueGreen;
      case PricePinStatus.moderate:
        return BitmapDescriptor.hueOrange;
      case PricePinStatus.alert:
        return BitmapDescriptor.hueRed;
      case PricePinStatus.info:
        if (item.category == PriceMapCategory.consulates) {
          return BitmapDescriptor.hueViolet;
        }
        return BitmapDescriptor.hueAzure;
    }
  }

  Set<Marker> _buildGoogleMarkers(
    BuildContext context,
    List<PriceMapItem> items, {
    required Map<MapPinStyleKey, BitmapDescriptor> customIcons,
    required String? selectedItemId,
  }) {
    final markers = <Marker>{};
    for (final item in items) {
      final title = item.pinLabel.isNotEmpty
          ? '${item.pinLabel} · ${item.name}'
          : item.name;
      final styleKey = MapPinStyleKey.fromItem(
        item,
        selected: item.id == selectedItemId,
      );
      final customIcon = customIcons[styleKey];
      markers.add(
        Marker(
          markerId: MarkerId(item.id),
          position: LatLng(item.latitude, item.longitude),
          icon:
              customIcon ??
              BitmapDescriptor.defaultMarkerWithHue(_markerHueForItem(item)),
          anchor: customIcon != null
              ? const Offset(0.5, 0.92)
              : const Offset(0.5, 1.0),
          zIndexInt: item.id == selectedItemId ? 2 : 1,
          onTap: () {
            ref.read(selectedMapItemIdProvider.notifier).select(item.id);
            _closeList();
            _focusItemOnMap(item);
          },
          infoWindow: InfoWindow(
            title: title,
            snippet: item.description,
            onTap: () => item.sourceType == 'business'
                ? _openBusinessDetail(context, item.id)
                : _openDirectionsToItem(context, item),
          ),
        ),
      );
    }
    return markers;
  }

  Future<void> _focusItemOnMap(PriceMapItem item) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(item.latitude, item.longitude),
        16.2,
      ),
    );
    await controller.showMarkerInfoWindow(MarkerId(item.id));
  }

  Future<void> _handleCenterOnMyLocation(
    BuildContext context,
    String cityName,
  ) async {
    final useNativeMap = ref.read(useNativeGoogleMapProvider);
    if (!useNativeMap) {
      _showInfoDialog(
        context,
        title: cityName,
        body: 'price_map.demo_location_body'.tr(namedArgs: {'city': cityName}),
      );
      return;
    }

    final coords = await ref
        .read(userMapLocationProvider.notifier)
        .requestAndFetchLocation();

    if (!context.mounted) return;

    if (coords != null) {
      final (lat, lng) = coords;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.8),
      );
    } else {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          const LatLng(kValleduparCenterLat, kValleduparCenterLng),
          14.2,
        ),
      );
      if (!context.mounted) return;
      final errorKey = ref.read(userMapLocationProvider).errorKey;
      _showInfoDialog(
        context,
        title: cityName,
        body: errorKey != null
            ? 'price_map.gps_errors.$errorKey'.tr()
            : 'price_map.demo_location_body'.tr(namedArgs: {'city': cityName}),
      );
    }
  }

  Future<void> _openDirectionsToItem(
    BuildContext context,
    PriceMapItem item,
  ) async {
    final useNativeMap = ref.read(useNativeGoogleMapProvider);
    if (!useNativeMap) {
      _showInfoDialog(
        context,
        title: 'price_map.action_route'.tr(),
        body: 'price_map.demo_route_body'.tr(namedArgs: {'name': item.name}),
      );
      return;
    }

    await _focusItemOnMap(item);
    final uri = ExternalUriGuard.buildSafeGoogleMapsDirectionsUri(
      latitude: item.latitude,
      longitude: item.longitude,
    );
    if (uri == null || !ExternalUriGuard.isAllowedExternalUri(uri)) {
      if (context.mounted) {
        _showInfoDialog(
          context,
          title: 'price_map.action_route'.tr(),
          body: 'price_map.demo_route_body'.tr(namedArgs: {'name': item.name}),
        );
      }
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showInfoDialog(
          context,
          title: 'price_map.action_route'.tr(),
          body: 'price_map.demo_route_body'.tr(namedArgs: {'name': item.name}),
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showInfoDialog(
          context,
          title: 'price_map.action_route'.tr(),
          body: 'price_map.demo_route_body'.tr(namedArgs: {'name': item.name}),
        );
      }
    }
  }

  void _resetMapFilters() {
    ref.read(priceMapCategoryProvider.notifier).selectCategory(null);
    ref.read(priceMapSearchQueryProvider.notifier).clear();
    ref.read(selectedMapItemIdProvider.notifier).clear();
    ref.read(priceMapViewportBoundsProvider.notifier).clear();
    ref.invalidate(allPriceMapItemsProvider);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        const LatLng(kValleduparCenterLat, kValleduparCenterLng),
        14.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredPriceMapItemsProvider);
    final sheetItemsAsync = ref.watch(sheetPlaceItemsProvider);
    final selectedCategory = ref.watch(priceMapCategoryProvider);
    final selectedItemId = ref.watch(selectedMapItemIdProvider);
    final isListOpen = ref.watch(priceMapListOpenProvider);
    final selectedPlace = ref.watch(selectedMapPlaceItemProvider);
    final sectionTitleKey = ref.watch(priceMapSectionTitleKeyProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final useNativeGoogleMap = ref.watch(useNativeGoogleMapProvider);
    final customIcons =
        ref.watch(mapMarkerDescriptorsProvider).asData?.value ??
        const <MapPinStyleKey, BitmapDescriptor>{};
    final isDemoMode = ref.watch(isDemoMapModeProvider);
    final userLocation = ref.watch(userMapLocationProvider);

    ref.listen<String>(priceMapSearchQueryProvider, (prev, next) {
      if (next.trim().isNotEmpty) {
        _openList();
      }
    });
    ref.listen<PriceMapCategory?>(priceMapCategoryProvider, (prev, next) {
      if (next != null) {
        _openList();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Mapa completo (Google Maps en dispositivo / Canvas en entorno de test)
            Positioned.fill(
              child: Semantics(
                label: 'price_map.semantics'.tr(namedArgs: {'city': cityName}),
                child: useNativeGoogleMap
                    ? GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(
                            kValleduparCenterLat,
                            kValleduparCenterLng,
                          ),
                          zoom: 14.2,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: (_) {
                          ref.read(selectedMapItemIdProvider.notifier).clear();
                          _closeList();
                        },
                        myLocationEnabled: userLocation.permissionGranted,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        mapToolbarEnabled: true,
                        buildingsEnabled: true,
                        indoorViewEnabled: true,
                        markers: itemsAsync.hasValue
                            ? _buildGoogleMarkers(
                                context,
                                itemsAsync.value!,
                                customIcons: customIcons,
                                selectedItemId: selectedItemId,
                              )
                            : const <Marker>{},
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            EagerGestureRecognizer.new,
                          ),
                        },
                      )
                    : ClipRect(
                        child: CustomPaint(
                          painter: _UrbanMapCanvasPainter(),
                          child: const SizedBox.expand(),
                        ),
                      ),
              ),
            ),

            // 2. Marcadores interactivos sobre el lienzo de respaldo (en entorno de test)
            if (!useNativeGoogleMap && itemsAsync.hasValue)
              for (final item in itemsAsync.value!)
                Align(
                  alignment: Alignment(item.alignmentX, item.alignmentY),
                  child: _MapPinWidget(
                    item: item,
                    onTap: () {
                      ref
                          .read(selectedMapItemIdProvider.notifier)
                          .select(item.id);
                      _closeList();
                    },
                  ),
                ),

            // 3. Controles y tarjetas flotantes inferiores sobre el mapa (Opción A)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.md,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isListOpen) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isDemoMode) ...[
                          Flexible(child: _DemoMapBadge(cityName: cityName)),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        const Spacer(),
                        _MapFloatingActionsColumn(
                          isRequestingLocation: userLocation.isRequesting,
                          onResetTap: () {
                            _resetMapFilters();
                            _closeList();
                          },
                          onCenterLocationTap: () =>
                              _handleCenterOnMyLocation(context, cityName),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (sheetItemsAsync.hasError)
                    _MapErrorBannerCard(
                      onRetry: () => ref.invalidate(allPriceMapItemsProvider),
                    )
                  else if (isListOpen)
                    _MapPlacesSheet(
                      maxHeight: (MediaQuery.sizeOf(context).height * 0.46)
                          .clamp(220.0, 420.0),
                      itemsAsync: sheetItemsAsync,
                      selectedCategory: selectedCategory,
                      selectedItemId: selectedItemId,
                      sectionTitleKey: sectionTitleKey,
                      onCloseSheet: _closeList,
                      onResetFilters: () {
                        ref
                            .read(priceMapCategoryProvider.notifier)
                            .selectCategory(null);
                        ref.read(priceMapSearchQueryProvider.notifier).clear();
                        ref.read(selectedMapItemIdProvider.notifier).clear();
                        ref.invalidate(allPriceMapItemsProvider);
                      },
                      onRetry: () => ref.invalidate(allPriceMapItemsProvider),
                      onItemTap: (item) {
                        ref
                            .read(selectedMapItemIdProvider.notifier)
                            .select(item.id);
                        if (item.sourceType == 'business') {
                          _openBusinessDetail(context, item.id);
                        } else {
                          _closeList();
                          _focusItemOnMap(item);
                        }
                      },
                      onRouteTap: (item) => _openDirectionsToItem(context, item),
                    )
                  else if (selectedPlace != null)
                    _FloatingSelectedPlaceCard(
                      item: selectedPlace,
                      onClose: () =>
                          ref.read(selectedMapItemIdProvider.notifier).clear(),
                      onCardTap: () {
                        if (selectedPlace.sourceType == 'business') {
                          _openBusinessDetail(context, selectedPlace.id);
                        } else {
                          _focusItemOnMap(selectedPlace);
                        }
                      },
                      onRouteTap: () =>
                          _openDirectionsToItem(context, selectedPlace),
                    )
                  else
                    _MapExplorePill(
                      itemsAsync: sheetItemsAsync,
                      sectionTitleKey: sectionTitleKey,
                      selectedCategory: selectedCategory,
                      onTap: _openList,
                    ),
                ],
              ),
            ),

                // 6. Controles superiores flotantes: buscador, filtros y "+ Aportar un precio al mapa"
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'profile.change_city'.tr(),
                            icon: const Icon(Icons.public, size: 22),
                            onPressed: () =>
                                context.push(AppRoutes.departmentMap),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size(48, 48),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: VjSearchField(
                              hint: 'price_map.search_hint'.tr(),
                              onChanged: ref
                                  .read(priceMapSearchQueryProvider.notifier)
                                  .updateQuery,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _MapFilterChip(
                              label: 'price_map.filter_prices'.tr(),
                              selected:
                                  selectedCategory == PriceMapCategory.prices,
                              onTap: () => ref
                                  .read(priceMapCategoryProvider.notifier)
                                  .toggleCategory(PriceMapCategory.prices),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _MapFilterChip(
                              label: 'price_map.filter_services'.tr(),
                              selected:
                                  selectedCategory == PriceMapCategory.services,
                              onTap: () => ref
                                  .read(priceMapCategoryProvider.notifier)
                                  .toggleCategory(PriceMapCategory.services),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _MapFilterChip(
                              label: 'price_map.filter_consulates'.tr(),
                              selected:
                                  selectedCategory ==
                                  PriceMapCategory.consulates,
                              onTap: () => ref
                                  .read(priceMapCategoryProvider.notifier)
                                  .toggleCategory(PriceMapCategory.consulates),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: _ContributeMapButton(
                            label: 'price_map.contribute_cta'.tr(),
                            onTap: () {
                              if (GoRouter.maybeOf(context) != null) {
                                context.push(AppRoutes.priceContribute);
                              } else {
                                _showInfoDialog(
                                  context,
                                  title: 'home.contribute_dialog_title'.tr(),
                                  body: 'home.contribute_dialog_body'.tr(),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta flotante expandible con listado limpio de negocios, servicios y puntos institucionales.
class _MapPlacesSheet extends StatelessWidget {
  const _MapPlacesSheet({
    required this.maxHeight,
    required this.itemsAsync,
    required this.selectedCategory,
    required this.selectedItemId,
    required this.sectionTitleKey,
    required this.onCloseSheet,
    required this.onResetFilters,
    required this.onRetry,
    required this.onItemTap,
    required this.onRouteTap,
  });

  final double maxHeight;
  final AsyncValue<List<PriceMapItem>> itemsAsync;
  final PriceMapCategory? selectedCategory;
  final String? selectedItemId;
  final String sectionTitleKey;
  final VoidCallback onCloseSheet;
  final VoidCallback onResetFilters;
  final VoidCallback onRetry;
  final ValueChanged<PriceMapItem> onItemTap;
  final ValueChanged<PriceMapItem> onRouteTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = itemsAsync.asData?.value.length;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: CustomScrollView(
              shrinkWrap: true,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sectionTitleKey.tr(),
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            if (count != null)
                              Text(
                                'price_map.places_count'.tr(
                                  args: [count.toString()],
                                ),
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: TextButton(
                                onPressed: onResetFilters,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  minimumSize: const Size(48, 48),
                                ),
                                child: Text(
                                  'price_map.see_all'.tr(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'price_map.show_map'.tr(),
                              onPressed: onCloseSheet,
                              icon: const Icon(Icons.close, size: 20),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                itemsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'municipality.load_error'.tr(),
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          VjButton(
                            label: 'common.retry'.tr(),
                            onPressed: onRetry,
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: Text(
                              (selectedCategory == PriceMapCategory.prices
                                      ? 'price_map.no_results'
                                      : 'businesses.no_results')
                                  .tr(),
                              style: textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = items[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < items.length - 1
                                    ? AppSpacing.sm
                                    : 0,
                              ),
                              child: _PriceMapItemCard(
                                item: item,
                                isSelected: item.id == selectedItemId,
                                onCardTap: () => onItemTap(item),
                                onRouteTap: () => onRouteTap(item),
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro superior del mapa local (`Precios`, `Servicios`, `Consulados`).
class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón con borde punteado "+ Aportar un precio al mapa" (M08).
class _ContributeMapButton extends StatelessWidget {
  const _ContributeMapButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.textMuted,
            radius: AppRadius.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador interactivo sobre el mapa local (píldora de semáforo o pin de servicio).
class _MapPinWidget extends StatelessWidget {
  const _MapPinWidget({
    required this.item,
    required this.onTap,
  });

  final PriceMapItem item;
  final VoidCallback onTap;

  String _semanticStatusLabel(PricePinStatus status) {
    switch (status) {
      case PricePinStatus.fair:
        return 'price_map.status_fair'.tr();
      case PricePinStatus.moderate:
        return 'price_map.status_moderate'.tr();
      case PricePinStatus.alert:
        return 'price_map.status_alert'.tr();
      case PricePinStatus.info:
        return 'price_map.status_service'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = resolveMapPinStyle(MapPinStyleKey.fromItem(item));

    return Semantics(
      button: true,
      label: '${item.name}, ${_semanticStatusLabel(item.status)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: item.pinLabel.isEmpty
                      ? AppSpacing.sm
                      : AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: style.fillColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: style.borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      style.icon,
                      size: 16,
                      color: style.foregroundColor,
                    ),
                    if (item.pinLabel.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        item.pinLabel,
                        style: TextStyle(
                          color: style.foregroundColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta inferior de un lugar real (negocio, servicio o consulado).
class _PriceMapItemCard extends StatelessWidget {
  const _PriceMapItemCard({
    required this.item,
    required this.isSelected,
    required this.onCardTap,
    required this.onRouteTap,
    this.onClose,
  });

  final PriceMapItem item;
  final bool isSelected;
  final VoidCallback onCardTap;
  final VoidCallback onRouteTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  mapPinIconForKind(item.pinKind),
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            item.badgeText,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (onClose != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            tooltip: 'common.close'.tr(),
                            onPressed: onClose,
                            icon: const Icon(Icons.close, size: 18),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _SemaphoreStatusBadge(
                      status: item.status,
                      isDemo: item.isDemo,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (item.sourceType == 'business')
                          OutlinedButton.icon(
                            onPressed: onCardTap,
                            icon: const Icon(Icons.storefront_outlined, size: 16),
                            label: Text('price_map.action_details'.tr()),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.primarySoft,
                              foregroundColor: AppColors.primary,
                              side: BorderSide.none,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: onRouteTap,
                          icon: const Icon(Icons.route_outlined, size: 16),
                          label: Text('price_map.action_route'.tr()),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.primarySoft,
                            foregroundColor: AppColors.primary,
                            side: BorderSide.none,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insignia accesible que combina color + ícono + texto para el nivel del semáforo o estado verificado.
class _SemaphoreStatusBadge extends StatelessWidget {
  const _SemaphoreStatusBadge({
    required this.status,
    required this.isDemo,
  });

  final PricePinStatus status;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case PricePinStatus.fair:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.semaphoreGreenSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 14,
                color: AppColors.semaphoreGreen,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'price_map.status_fair'.tr(),
                  style: const TextStyle(
                    color: AppColors.semaphoreGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      case PricePinStatus.moderate:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.semaphoreAmberSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.semaphoreAmber,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'price_map.status_moderate'.tr(),
                  style: const TextStyle(
                    color: AppColors.semaphoreAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      case PricePinStatus.alert:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.semaphoreRedSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 14,
                color: AppColors.semaphoreRed,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'price_map.status_alert'.tr(),
                  style: const TextStyle(
                    color: AppColors.semaphoreRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      case PricePinStatus.info:
        return VjBadge(
          label: isDemo
              ? 'businesses.demo_badge'.tr()
              : 'businesses.published_badge'.tr(),
        );
    }
  }
}

/// Dibuja la cuadrícula de calles urbanas y el marcador central de posición en el lienzo de respaldo (M08).
class _UrbanMapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.border;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Calles secundarias y avenidas diagonales (estilo mockup M08)
    final streetPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Avenidas verticales ligeramente inclinadas
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.16, size.height),
      streetPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, 0),
      Offset(size.width * 0.72, size.height),
      streetPaint,
    );

    // Calles transversales
    canvas.drawLine(
      Offset(0, size.height * 0.28),
      Offset(size.width, size.height * 0.34),
      streetPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.60),
      Offset(size.width, size.height * 0.68),
      streetPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.85),
      Offset(size.width, size.height * 0.90),
      streetPaint,
    );

    // Punto central de ubicación del usuario con halo
    final center = Offset(size.width * 0.48, size.height * 0.50);
    final haloPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 24, haloPaint);

    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, whiteRingPaint);

    final blueDotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, blueDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dibuja un borde punteado redondeado alrededor del botón "+ Aportar un precio al mapa".
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Etiqueta compacta mostrada solo cuando el mapa opera en modo demostración local.
class _DemoMapBadge extends StatelessWidget {
  const _DemoMapBadge({required this.cityName});

  final String cityName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'price_map.demo_label'.tr(namedArgs: {'city': cityName}),
        style: textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Botones flotantes derechos del mapa (restablecer capas y centrar en GPS).
class _MapFloatingActionsColumn extends StatelessWidget {
  const _MapFloatingActionsColumn({
    required this.isRequestingLocation,
    required this.onResetTap,
    required this.onCenterLocationTap,
  });

  final bool isRequestingLocation;
  final VoidCallback onResetTap;
  final VoidCallback onCenterLocationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'price_map.layers_tooltip'.tr(),
          onPressed: onResetTap,
          icon: const Icon(Icons.layers_outlined),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(48, 48),
            elevation: 3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IconButton(
          tooltip: 'price_map.center_tooltip'.tr(),
          onPressed: onCenterLocationTap,
          icon: isRequestingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 48),
            elevation: 3,
          ),
        ),
      ],
    );
  }
}

/// Píldora flotante inferior (Opción A) que resume lugares disponibles y abre el listado completo.
class _MapExplorePill extends StatelessWidget {
  const _MapExplorePill({
    required this.itemsAsync,
    required this.sectionTitleKey,
    required this.selectedCategory,
    required this.onTap,
  });

  final AsyncValue<List<PriceMapItem>> itemsAsync;
  final String sectionTitleKey;
  final PriceMapCategory? selectedCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = itemsAsync.asData?.value;
    final count = items?.length;

    final String headline;
    if (itemsAsync.isLoading && items == null) {
      headline = sectionTitleKey.tr();
    } else if (count == null || count == 0) {
      headline = 'businesses.no_results'.tr();
    } else {
      headline = 'price_map.places_count'.tr(args: [count.toString()]);
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (selectedCategory != null)
                          Text(
                            sectionTitleKey.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (itemsAsync.isLoading && items == null)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'price_map.view_list'.tr(),
                              style: textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_up,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ficha flotante sobre el mapa cuando el usuario selecciona un pin específico.
class _FloatingSelectedPlaceCard extends StatelessWidget {
  const _FloatingSelectedPlaceCard({
    required this.item,
    required this.onClose,
    required this.onCardTap,
    required this.onRouteTap,
  });

  final PriceMapItem item;
  final VoidCallback onClose;
  final VoidCallback onCardTap;
  final VoidCallback onRouteTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 8,
      child: _PriceMapItemCard(
        item: item,
        isSelected: true,
        onCardTap: onCardTap,
        onRouteTap: onRouteTap,
        onClose: onClose,
      ),
    );
  }
}

/// Tarjeta flotante de error con reintento directo sobre el mapa.
class _MapErrorBannerCard extends StatelessWidget {
  const _MapErrorBannerCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'municipality.load_error'.tr(),
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            VjButton(
              label: 'common.retry'.tr(),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
