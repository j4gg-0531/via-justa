import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

/// Selector híbrido de zona del municipio:
/// 1) Solicita permiso de ubicación del teléfono para autodetectar la zona por GPS.
/// 2) Si el usuario no permite la ubicación (o desea consultar otro punto), despliega un mapa
///    interactivo estilo M08 donde puede tocar cualquier sector o marcador de zona.
class ZoneMapPickerCard extends StatelessWidget {
  const ZoneMapPickerCard({
    super.key,
    required this.scanState,
    required this.zones,
    required this.activeZone,
    required this.cityName,
    required this.languageCode,
    required this.onRequestGpsPermission,
    required this.onDenyGpsPermission,
    required this.onToggleManualMap,
    required this.onZoneTapped,
    required this.onMapPointTapped,
  });

  final PriceScanState scanState;
  final List<MunicipalityZone> zones;
  final MunicipalityZone? activeZone;
  final String cityName;
  final String languageCode;
  final VoidCallback onRequestGpsPermission;
  final VoidCallback onDenyGpsPermission;
  final ValueChanged<bool> onToggleManualMap;
  final ValueChanged<String> onZoneTapped;
  final void Function(double normalizedX, double normalizedY) onMapPointTapped;

  void _showPermissionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.my_location, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('price_verdict.gps_permission_dialog_title'.tr()),
            ),
          ],
        ),
        content: Text(
          'price_verdict.gps_permission_dialog_body'.tr(
            namedArgs: {'city': cityName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onDenyGpsPermission();
            },
            child: Text('price_verdict.gps_permission_deny_btn'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRequestGpsPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('price_verdict.gps_permission_allow_btn'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final zoneTitle =
        activeZone?.localizedName(languageCode) ?? scanState.selectedZoneId;
    final zoneSectors = activeZone?.localizedSectorHint(languageCode) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del campo de zona
        Row(
          children: [
            Expanded(
              child: Text(
                'price_verdict.zone_field_label'.tr(),
                style: textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
            ),
            VjBadge(
              label: scanState.locationPermission ==
                          LocationPermissionStatus.granted &&
                      !scanState.isManualMapOpen
                  ? 'price_verdict.zone_mode_gps_badge'.tr()
                  : 'price_verdict.zone_mode_map_badge'.tr(),
              icon: scanState.locationPermission ==
                          LocationPermissionStatus.granted &&
                      !scanState.isManualMapOpen
                  ? Icons.my_location
                  : Icons.map_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'price_verdict.zone_field_helper'.tr(namedArgs: {'city': cityName}),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Tarjeta de zona actualmente seleccionada
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  scanState.locationPermission ==
                              LocationPermissionStatus.granted &&
                          !scanState.isManualMapOpen
                      ? Icons.gps_fixed
                      : Icons.place,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zoneTitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (zoneSectors.isNotEmpty)
                      Text(
                        zoneSectors,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Estado 1: Aún no ha respondido el permiso de ubicación (prompt)
        if (scanState.locationPermission == LocationPermissionStatus.prompt &&
            !scanState.isManualMapOpen)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'price_verdict.gps_prompt_banner'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    VjButton(
                      label: 'price_verdict.use_gps_cta'.tr(),
                      leadingIcon: Icons.my_location,
                      onPressed: () => _showPermissionDialog(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    VjButton(
                      label: 'price_verdict.pick_on_map_cta'.tr(),
                      leadingIcon: Icons.map_outlined,
                      variant: VjButtonVariant.outlined,
                      onPressed: onDenyGpsPermission,
                    ),
                  ],
                ),
              ],
            ),
          )
        // Estado 2: Permiso GPS concedido y mapa cerrado -> botón para abrir mapa si desea consultar otro sector
        else if (!scanState.shouldShowMapPicker)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onToggleManualMap(true),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text('price_verdict.change_point_on_map_cta'.tr()),
            ),
          )
        // Estado 3: Permiso denegado o mapa manual abierto -> Mapa interactivo estilo M08
        else ...[
          _InteractiveZoneMapCanvas(
            zones: zones,
            selectedZoneId: scanState.selectedZoneId,
            pinAlignmentX: scanState.pinAlignmentX,
            pinAlignmentY: scanState.pinAlignmentY,
            languageCode: languageCode,
            onZoneTapped: onZoneTapped,
            onMapPointTapped: onMapPointTapped,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'price_verdict.map_tap_instruction'.tr(),
                style: textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: onRequestGpsPermission,
                icon: const Icon(Icons.my_location, size: 16),
                label: Text('price_verdict.use_gps_cta'.tr()),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lienzo interactivo del mapa de zonas del municipio (mismo estilo visual del mapa de precios M08).
/// Al tocar cualquier parte del lienzo o un pin de zona, ubica el marcador y selecciona la zona más cercana.
class _InteractiveZoneMapCanvas extends StatelessWidget {
  const _InteractiveZoneMapCanvas({
    required this.zones,
    required this.selectedZoneId,
    required this.pinAlignmentX,
    required this.pinAlignmentY,
    required this.languageCode,
    required this.onZoneTapped,
    required this.onMapPointTapped,
  });

  final List<MunicipalityZone> zones;
  final String selectedZoneId;
  final double pinAlignmentX;
  final double pinAlignmentY;
  final String languageCode;
  final ValueChanged<String> onZoneTapped;
  final void Function(double normalizedX, double normalizedY) onMapPointTapped;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                if (width <= 0 || height <= 0) return;
                final normX = details.localPosition.dx / width;
                final normY = details.localPosition.dy / height;
                onMapPointTapped(normX, normY);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo cartográfico urbano (idéntico al estilo M08)
                  CustomPaint(
                    painter: _UrbanZoneMapPainter(),
                  ),

                  // Marcadores interactivos de las zonas del municipio (Norte, Centro, Sur, Oriente, Occidente)
                  for (final zone in zones)
                    Align(
                      alignment: Alignment(zone.alignmentX, zone.alignmentY),
                      child: _ZoneMapMarker(
                        label: zone.localizedName(languageCode),
                        selected: zone.id == selectedZoneId,
                        onTap: () => onZoneTapped(zone.id),
                      ),
                    ),

                  // Pin azul móvil de la ubicación seleccionada por el usuario
                  Align(
                    alignment: Alignment(pinAlignmentX, pinAlignmentY),
                    child: IgnorePointer(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.20),
                        ),
                        alignment: Alignment.center,
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ZoneMapMarker extends StatelessWidget {
  const _ZoneMapMarker({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.primary : AppColors.surface;
    final fgColor = selected ? Colors.white : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? Colors.white : AppColors.primary,
                width: 1.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.place_outlined,
                  size: 14,
                  color: fgColor,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pintor del lienzo urbano de Valledupar (cuadrícula de vías, río Guatapurí y parque central).
class _UrbanZoneMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE5E9F0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Zona verde oriental (Río Guatapurí / Hurtado)
    final parkPaint = Paint()..color = const Color(0xFFD6EADF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.84, size.height * 0.34),
        width: size.width * 0.28,
        height: size.height * 0.44,
      ),
      parkPaint,
    );

    // Cuadrícula de avenidas principales
    final roadPaint = Paint()
      ..color = const Color(0xFFBCC5D3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.22, 0),
      Offset(size.width * 0.28, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, 0),
      Offset(size.width * 0.52, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, 0),
      Offset(size.width * 0.74, size.height),
      roadPaint,
    );

    canvas.drawLine(
      Offset(0, size.height * 0.26),
      Offset(size.width, size.height * 0.30),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.56),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.78),
      Offset(size.width, size.height * 0.82),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
