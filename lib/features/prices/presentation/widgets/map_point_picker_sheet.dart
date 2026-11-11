import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

export 'package:via_justa/features/prices/presentation/state/price_map_providers.dart'
    show PickedMapPoint;

/// Abre una hoja inferior (modal bottom sheet) con el mapa interactivo de Google Maps
/// de la ciudad para elegir un punto preciso (Origen, Destino o Ubicación del establecimiento).
Future<PickedMapPoint?> showMapPointPickerSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<MunicipalityZone> zones,
  required String initialZoneId,
  double? initialLatitude,
  double? initialLongitude,
  required String languageCode,
  bool allowGpsButton = true,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(mapPointPickerProvider.notifier).initialize(
        zones: zones,
        initialZoneId: initialZoneId,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
      );
  return showModalBottomSheet<PickedMapPoint>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) => _MapPointPickerSheetContent(
      title: title,
      subtitle: subtitle,
      zones: zones,
      languageCode: languageCode,
      allowGpsButton: allowGpsButton,
    ),
  );
}

class _MapPointPickerSheetContent extends ConsumerStatefulWidget {
  const _MapPointPickerSheetContent({
    required this.title,
    required this.subtitle,
    required this.zones,
    required this.languageCode,
    required this.allowGpsButton,
  });

  final String title;
  final String subtitle;
  final List<MunicipalityZone> zones;
  final String languageCode;
  final bool allowGpsButton;

  @override
  ConsumerState<_MapPointPickerSheetContent> createState() =>
      _MapPointPickerSheetContentState();
}

class _MapPointPickerSheetContentState
    extends ConsumerState<_MapPointPickerSheetContent> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  MunicipalityZone? _findZoneById(String id) {
    for (final z in widget.zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  Future<void> _handleUseMyGps() async {
    final coords = await ref
        .read(userMapLocationProvider.notifier)
        .requestAndFetchLocation();
    if (!mounted) return;
    if (coords != null) {
      final (lat, lng) = coords;
      ref.read(mapPointPickerProvider.notifier).selectCoordinates(
            zones: widget.zones,
            latitude: lat,
            longitude: lng,
          );
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.8),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final useNativeMap = ref.watch(useNativeGoogleMapProvider);
    final gpsState = ref.watch(userMapLocationProvider);
    final picked = ref.watch(mapPointPickerProvider);
    final activeZone = _findZoneById(picked.zoneId);
    final zoneName =
        activeZone?.localizedName(widget.languageCode) ?? picked.zoneId;
    final zoneSectors =
        activeZone?.localizedSectorHint(widget.languageCode) ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'common.close'.tr(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: useNativeMap
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(picked.latitude, picked.longitude),
                          zoom: 14.2,
                        ),
                        myLocationEnabled: gpsState.permissionGranted,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: (latLng) {
                          ref
                              .read(mapPointPickerProvider.notifier)
                              .selectCoordinates(
                                zones: widget.zones,
                                latitude: latLng.latitude,
                                longitude: latLng.longitude,
                              );
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('picked_point'),
                            position: LatLng(picked.latitude, picked.longitude),
                            infoWindow: InfoWindow(
                              title: zoneName,
                              snippet: zoneSectors,
                            ),
                          ),
                        },
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            EagerGestureRecognizer.new,
                          ),
                        },
                      )
                    : _FallbackMapCanvas(
                        zones: widget.zones,
                        selectedZoneId: picked.zoneId,
                        pinAlignmentX: (picked.normalizedX * 2) - 1,
                        pinAlignmentY: (picked.normalizedY * 2) - 1,
                        languageCode: widget.languageCode,
                        onZoneTapped: (zone) {
                          ref
                              .read(mapPointPickerProvider.notifier)
                              .selectZone(zone);
                        },
                        onPointTapped: (normX, normY) {
                          ref
                              .read(mapPointPickerProvider.notifier)
                              .selectNormalizedPoint(
                                zones: widget.zones,
                                normalizedX: normX,
                                normalizedY: normY,
                              );
                        },
                      ),
              ),
            ),
            if (widget.allowGpsButton) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: gpsState.isRequesting ? null : _handleUseMyGps,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text('price_verdict.use_gps_cta'.tr()),
                ),
              ),
            ] else
              const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zoneName,
                          style: textTheme.titleMedium?.copyWith(fontSize: 14),
                        ),
                        if (zoneSectors.isNotEmpty)
                          Text(
                            zoneSectors,
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VjButton(
              label: 'price_verdict.confirm_map_point_cta'.tr(),
              leadingIcon: Icons.check,
              onPressed: () {
                Navigator.of(context).pop(picked);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackMapCanvas extends StatelessWidget {
  const _FallbackMapCanvas({
    required this.zones,
    required this.selectedZoneId,
    required this.pinAlignmentX,
    required this.pinAlignmentY,
    required this.languageCode,
    required this.onZoneTapped,
    required this.onPointTapped,
  });

  final List<MunicipalityZone> zones;
  final String selectedZoneId;
  final double pinAlignmentX;
  final double pinAlignmentY;
  final String languageCode;
  final ValueChanged<MunicipalityZone> onZoneTapped;
  final void Function(double normX, double normY) onPointTapped;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            if (width <= 0 || height <= 0) return;
            onPointTapped(
              details.localPosition.dx / width,
              details.localPosition.dy / height,
            );
          },
          child: Container(
            color: const Color(0xFFE5E9F0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final zone in zones)
                  Align(
                    alignment: Alignment(zone.alignmentX, zone.alignmentY),
                    child: GestureDetector(
                      onTap: () => onZoneTapped(zone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: zone.id == selectedZoneId
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          zone.localizedName(languageCode),
                          style: TextStyle(
                            color: zone.id == selectedZoneId
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment(pinAlignmentX, pinAlignmentY),
                  child: IgnorePointer(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
