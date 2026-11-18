import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';

/// Clave inmutable de caché para reutilizar íconos vectoriales de marcadores según tipo y estado.
class MapPinStyleKey {
  const MapPinStyleKey({
    required this.pinKind,
    required this.status,
    required this.category,
    this.selected = false,
  });

  factory MapPinStyleKey.fromItem(
    PriceMapItem item, {
    bool selected = false,
  }) {
    return MapPinStyleKey(
      pinKind: item.pinKind,
      status: item.status,
      category: item.category,
      selected: selected,
    );
  }

  final PriceMapPinKind pinKind;
  final PricePinStatus status;
  final PriceMapCategory category;
  final bool selected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPinStyleKey &&
          other.pinKind == pinKind &&
          other.status == status &&
          other.category == category &&
          other.selected == selected;

  @override
  int get hashCode => Object.hash(pinKind, status, category, selected);
}

/// Especificación visual compartida para pines del mapa real, tarjetas y lienzo de respaldo.
class MapPinStyleSpec {
  const MapPinStyleSpec({
    required this.icon,
    required this.fillColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.selected,
  });

  final IconData icon;
  final Color fillColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool selected;
}

/// Devuelve el ícono semántico de Material asociado a cada tipo de lugar o precio.
IconData mapPinIconForKind(PriceMapPinKind kind) {
  switch (kind) {
    case PriceMapPinKind.food:
      return Icons.restaurant;
    case PriceMapPinKind.transport:
      return Icons.local_taxi;
    case PriceMapPinKind.lodging:
      return Icons.hotel;
    case PriceMapPinKind.hospital:
      return Icons.local_hospital;
    case PriceMapPinKind.assistance:
      return Icons.volunteer_activism;
    case PriceMapPinKind.consulate:
      return Icons.account_balance;
  }
}

/// Resuelve colores e ícono de un marcador combinando semáforo de precios y categoría institucional.
MapPinStyleSpec resolveMapPinStyle(MapPinStyleKey key) {
  final Color fillColor;
  switch (key.status) {
    case PricePinStatus.fair:
      fillColor = AppColors.semaphoreGreen;
      break;
    case PricePinStatus.moderate:
      fillColor = AppColors.semaphoreAmber;
      break;
    case PricePinStatus.alert:
      fillColor = AppColors.semaphoreRed;
      break;
    case PricePinStatus.info:
      final isInstitutional =
          key.category == PriceMapCategory.consulates ||
          key.pinKind == PriceMapPinKind.consulate;
      fillColor = isInstitutional ? AppColors.textPrimary : AppColors.primary;
      break;
  }

  return MapPinStyleSpec(
    icon: mapPinIconForKind(key.pinKind),
    fillColor: fillColor,
    foregroundColor: AppColors.surface,
    borderColor: AppColors.surface,
    selected: key.selected,
  );
}

/// Especificación visual del pin temporal de destino seleccionado en el mapa.
const MapPinStyleSpec kDestinationMapPinSpec = MapPinStyleSpec(
  icon: Icons.flag,
  fillColor: AppColors.textPrimary,
  foregroundColor: AppColors.surface,
  borderColor: AppColors.surface,
  selected: true,
);

/// Dibuja el pin temporal de destino en alta resolución para [BitmapDescriptor.bytes].
Future<Uint8List> renderDestinationMarkerPngBytes({
  double pixelRatio = 3.0,
}) =>
    renderMapMarkerPngBytes(kDestinationMapPinSpec, pixelRatio: pixelRatio);

/// Dibuja un pin tipo gota en alta resolución y devuelve los bytes PNG para [BitmapDescriptor.bytes].
Future<Uint8List> renderMapMarkerPngBytes(
  MapPinStyleSpec spec, {
  double pixelRatio = 3.0,
}) async {
  final logicalWidth = spec.selected ? 50.0 : 42.0;
  final logicalHeight = spec.selected ? 60.0 : 50.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio, pixelRatio);

  final centerX = logicalWidth / 2;
  final headRadius = spec.selected ? 18.0 : 15.0;
  final headCenterY = spec.selected ? 22.0 : 18.0;
  final tipY = logicalHeight - 4.0;

  // Sombra suave bajo la punta del marcador
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.22)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(centerX, tipY + 0.5),
      width: spec.selected ? 16.0 : 13.0,
      height: 5.0,
    ),
    shadowPaint,
  );

  // Halo exterior cuando el pin está seleccionado
  if (spec.selected) {
    final haloPaint = Paint()
      ..color = spec.fillColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius + 5.0, haloPaint);
  }

  // Contorno único continuo tipo gota sin líneas internas en el cuello
  const startAngle = 0.78 * math.pi;
  const sweepAngle = 1.44 * math.pi;
  final leftNeckX = centerX + headRadius * math.cos(startAngle);
  final leftNeckY = headCenterY + headRadius * math.sin(startAngle);
  final controlY = tipY - ((tipY - headCenterY) * 0.34);
  final headCenter = Offset(centerX, headCenterY);

  final path = Path()
    ..moveTo(leftNeckX, leftNeckY)
    ..arcTo(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      startAngle,
      sweepAngle,
      false,
    )
    ..quadraticBezierTo(centerX + (headRadius * 0.62), controlY, centerX, tipY)
    ..quadraticBezierTo(
      centerX - (headRadius * 0.62),
      controlY,
      leftNeckX,
      leftNeckY,
    )
    ..close();

  final fillPaint = Paint()
    ..color = spec.fillColor
    ..style = PaintingStyle.fill;
  canvas.drawPath(path, fillPaint);

  final borderPaint = Paint()
    ..color = spec.borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = spec.selected ? 3.0 : 2.5
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(path, borderPaint);

  // Círculo interno sutil que enmarca el glifo del tipo de lugar
  final innerCirclePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.14)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(headCenter, headRadius * 0.72, innerCirclePaint);

  // Ícono vectorial centrado (tenedor, taxi, cama, cruz, etc.)
  final iconPainter = TextPainter(textDirection: TextDirection.ltr);
  iconPainter.text = TextSpan(
    text: String.fromCharCode(spec.icon.codePoint),
    style: TextStyle(
      fontSize: spec.selected ? 21.0 : 17.5,
      fontFamily: spec.icon.fontFamily,
      package: spec.icon.fontPackage,
      color: spec.foregroundColor,
    ),
  );
  iconPainter.layout();
  iconPainter.paint(
    canvas,
    Offset(
      centerX - (iconPainter.width / 2),
      headCenterY - (iconPainter.height / 2),
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (logicalWidth * pixelRatio).round(),
    (logicalHeight * pixelRatio).round(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    return Uint8List(0);
  }
  return byteData.buffer.asUint8List();
}

/// Función generadora de descriptores para poder sustituirse en pruebas sin motor Skia nativo.
typedef MapMarkerDescriptorBuilder = Future<BitmapDescriptor> Function(
  MapPinStyleKey key,
);

/// Caché en memoria de descriptores [BitmapDescriptor] para evitar regenerar PNGs repetidos.
class MapMarkerIconCache {
  MapMarkerIconCache({
    this.descriptorBuilder,
    this.pixelRatio = 3.0,
  });

  final MapMarkerDescriptorBuilder? descriptorBuilder;
  final double pixelRatio;
  final Map<MapPinStyleKey, BitmapDescriptor> _cache = {};

  Future<BitmapDescriptor> _buildDescriptor(MapPinStyleKey key) async {
    final customBuilder = descriptorBuilder;
    if (customBuilder != null) {
      return customBuilder(key);
    }
    final spec = resolveMapPinStyle(key);
    final bytes = await renderMapMarkerPngBytes(spec, pixelRatio: pixelRatio);
    if (bytes.isEmpty) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(bytes, imagePixelRatio: pixelRatio);
  }

  /// Devuelve el mapa completo de descriptores listos para los marcadores visibles actuales.
  Future<Map<MapPinStyleKey, BitmapDescriptor>> resolveForItems(
    List<PriceMapItem> items, {
    String? selectedItemId,
  }) async {
    final keysToLoad = <MapPinStyleKey>{};
    for (final item in items) {
      keysToLoad.add(
        MapPinStyleKey.fromItem(item, selected: item.id == selectedItemId),
      );
    }

    final missing = <MapPinStyleKey>[];
    for (final key in keysToLoad) {
      if (!_cache.containsKey(key)) {
        missing.add(key);
      }
    }
    if (missing.isNotEmpty) {
      final rendered = await Future.wait(missing.map(_buildDescriptor));
      for (var i = 0; i < missing.length; i++) {
        _cache[missing[i]] = rendered[i];
      }
    }

    return {
      for (final key in keysToLoad) key: _cache[key]!,
    };
  }
}
