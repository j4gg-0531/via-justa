import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

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
    List<PriceMapItem> items,
  ) {
    final markers = <Marker>{};
    for (final item in items) {
      final title = item.pinLabel.isNotEmpty
          ? '${item.pinLabel} · ${item.name}'
          : item.name;
      markers.add(
        Marker(
          markerId: MarkerId(item.id),
          position: LatLng(item.latitude, item.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHueForItem(item)),
          infoWindow: InfoWindow(
            title: title,
            snippet: item.description,
            onTap: () => _openDirectionsToItem(context, item),
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
      _showInfoDialog(
        context,
        title: cityName,
        body: 'price_map.demo_location_body'.tr(namedArgs: {'city': cityName}),
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
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${item.latitude},${item.longitude}',
    );
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

  Future<void> _callItem(BuildContext context, PriceMapItem item) async {
    final useNativeMap = ref.read(useNativeGoogleMapProvider);
    final rawPhone = (item.phone != null && item.phone!.trim().isNotEmpty)
        ? item.phone!.trim()
        : item.whatsapp?.trim();

    if (!useNativeMap || rawPhone == null || rawPhone.isEmpty) {
      _showInfoDialog(
        context,
        title: 'businesses.contact_dialog_title'.tr(),
        body: 'businesses.contact_dialog_body'.tr(),
      );
      return;
    }

    final sanitizedDigits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitizedDigits.isEmpty) {
      _showInfoDialog(
        context,
        title: 'businesses.contact_dialog_title'.tr(),
        body: 'businesses.contact_dialog_body'.tr(),
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: sanitizedDigits);
    try {
      final launched = await launchUrl(telUri);
      if (!launched && context.mounted) {
        _showInfoDialog(
          context,
          title: 'businesses.contact_dialog_title'.tr(),
          body: 'businesses.contact_dialog_body'.tr(),
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showInfoDialog(
          context,
          title: 'businesses.contact_dialog_title'.tr(),
          body: 'businesses.contact_dialog_body'.tr(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredPriceMapItemsProvider);
    final selectedCategory = ref.watch(priceMapCategoryProvider);
    final sectionTitleKey = ref.watch(priceMapSectionTitleKeyProvider);
    final cityName = ref.watch(activeCityNameProvider);
    final useNativeGoogleMap = ref.watch(useNativeGoogleMapProvider);
    final userLocation = ref.watch(userMapLocationProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // Lienzo de Google Maps (o respaldo en entorno de pruebas) con controles superpuestos (M08 / VJ-12)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 360,
                child: Stack(
                  children: [
                    // 1. Mapa interactivo (Google Maps en Android real / Canvas en test headless)
                    Positioned.fill(
                      child: Semantics(
                        label: 'price_map.semantics'.tr(
                          namedArgs: {'city': cityName},
                        ),
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
                                myLocationEnabled:
                                    userLocation.permissionGranted,
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
                                      )
                                    : const <Marker>{},
                                gestureRecognizers: <
                                  Factory<OneSequenceGestureRecognizer>
                                >{
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
                          alignment: Alignment(
                            item.alignmentX,
                            item.alignmentY,
                          ),
                          child: _MapPinWidget(
                            item: item,
                            onTap: () => _showInfoDialog(
                              context,
                              title: item.name,
                              body:
                                  '${item.description}\n\n${'price_map.demo_pin_dialog'.tr()}',
                            ),
                          ),
                        ),

                    // 3. Controles superiores: buscador, filtros y botón "+ Aportar un precio al mapa"
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
                                      .read(
                                        priceMapSearchQueryProvider.notifier,
                                      )
                                      .updateQuery,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Chips de filtro: Precios | Servicios | Consulados
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _MapFilterChip(
                                  label: 'price_map.filter_prices'.tr(),
                                  selected: selectedCategory ==
                                      PriceMapCategory.prices,
                                  onTap: () => ref
                                      .read(priceMapCategoryProvider.notifier)
                                      .toggleCategory(PriceMapCategory.prices),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _MapFilterChip(
                                  label: 'price_map.filter_services'.tr(),
                                  selected: selectedCategory ==
                                      PriceMapCategory.services,
                                  onTap: () => ref
                                      .read(priceMapCategoryProvider.notifier)
                                      .toggleCategory(
                                        PriceMapCategory.services,
                                      ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _MapFilterChip(
                                  label: 'price_map.filter_consulates'.tr(),
                                  selected: selectedCategory ==
                                      PriceMapCategory.consulates,
                                  onTap: () => ref
                                      .read(priceMapCategoryProvider.notifier)
                                      .toggleCategory(
                                        PriceMapCategory.consulates,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Botón punteado "+ Aportar un precio al mapa"
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
                                      title:
                                          'home.contribute_dialog_title'.tr(),
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

                    // 4. Botones flotantes derechos (Restablecer/Refrescar capas y Centrar en mi ubicación GPS)
                    Positioned(
                      right: AppSpacing.lg,
                      bottom: AppSpacing.xl,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'price_map.layers_tooltip'.tr(),
                            onPressed: () {
                              ref
                                  .read(priceMapCategoryProvider.notifier)
                                  .selectCategory(null);
                              ref
                                  .read(priceMapSearchQueryProvider.notifier)
                                  .clear();
                              ref
                                  .read(priceMapViewportBoundsProvider.notifier)
                                  .clear();
                              ref.invalidate(allPriceMapItemsProvider);
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  const LatLng(
                                    kValleduparCenterLat,
                                    kValleduparCenterLng,
                                  ),
                                  14.2,
                                ),
                              );
                            },
                            icon: const Icon(Icons.layers_outlined),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size(48, 48),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          IconButton(
                            tooltip: 'price_map.center_tooltip'.tr(),
                            onPressed: () =>
                                _handleCenterOnMyLocation(context, cityName),
                            icon: userLocation.isRequesting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(48, 48),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5. Etiqueta inferior izquierda del municipio activo
                    Positioned(
                      left: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'price_map.demo_label'.tr(
                            namedArgs: {'city': cityName},
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hoja inferior redondeada con listado de Servicios / Precios / Negocios
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    topRight: Radius.circular(AppRadius.lg),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Text(
                          sectionTitleKey.tr(),
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(priceMapCategoryProvider.notifier)
                                .selectCategory(null);
                            ref
                                .read(priceMapSearchQueryProvider.notifier)
                                .clear();
                            ref.invalidate(allPriceMapItemsProvider);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text('price_map.see_all'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tarjetas de lugares, negocios y reportes filtrados
            itemsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'municipality.load_error'.tr(),
                      style: textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'price_map.no_results'.tr(),
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _PriceMapItemCard(
                            item: item,
                            onCardTap: () => _focusItemOnMap(item),
                            onRouteTap: () =>
                                _openDirectionsToItem(context, item),
                            onCallTap: () => _callItem(context, item),
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

  IconData _iconForKind(PriceMapPinKind kind) {
    switch (kind) {
      case PriceMapPinKind.food:
        return Icons.restaurant;
      case PriceMapPinKind.transport:
        return Icons.directions_car;
      case PriceMapPinKind.lodging:
        return Icons.hotel;
      case PriceMapPinKind.hospital:
        return Icons.local_hospital;
      case PriceMapPinKind.assistance:
        return Icons.medical_services_outlined;
      case PriceMapPinKind.consulate:
        return Icons.account_balance;
    }
  }

  Color _backgroundColorForStatus(PricePinStatus status) {
    switch (status) {
      case PricePinStatus.fair:
        return AppColors.semaphoreGreen;
      case PricePinStatus.moderate:
        return AppColors.semaphoreAmber;
      case PricePinStatus.alert:
        return AppColors.semaphoreRed;
      case PricePinStatus.info:
        return AppColors.surface;
    }
  }

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
    final isServicePin = item.status == PricePinStatus.info;
    final bgColor = _backgroundColorForStatus(item.status);
    final fgColor = isServicePin ? AppColors.primary : Colors.white;

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
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isServicePin ? AppSpacing.sm : AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: Colors.white, width: 2),
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
                      _iconForKind(item.pinKind),
                      size: 16,
                      color: fgColor,
                    ),
                    if (item.pinLabel.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        item.pinLabel,
                        style: TextStyle(
                          color: fgColor,
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

/// Tarjeta inferior de un servicio, negocio o reporte de precio (M08 / VJ-12).
class _PriceMapItemCard extends StatelessWidget {
  const _PriceMapItemCard({
    required this.item,
    required this.onCardTap,
    required this.onRouteTap,
    required this.onCallTap,
  });

  final PriceMapItem item;
  final VoidCallback onCardTap;
  final VoidCallback onRouteTap;
  final VoidCallback onCallTap;

  IconData _iconForKind(PriceMapPinKind kind) {
    switch (kind) {
      case PriceMapPinKind.food:
        return Icons.restaurant;
      case PriceMapPinKind.transport:
        return Icons.local_taxi;
      case PriceMapPinKind.lodging:
        return Icons.hotel;
      case PriceMapPinKind.hospital:
        return Icons.local_hospital_outlined;
      case PriceMapPinKind.assistance:
        return Icons.volunteer_activism_outlined;
      case PriceMapPinKind.consulate:
        return Icons.account_balance_outlined;
    }
  }

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
            border: Border.all(color: AppColors.border),
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
                  _iconForKind(item.pinKind),
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
                        OutlinedButton.icon(
                          onPressed: onCallTap,
                          icon: const Icon(Icons.phone, size: 16),
                          label: Text('businesses.action_call'.tr()),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
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
              : 'businesses.verified_badge'.tr(),
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
