import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape_repository.dart';

/// Implementación local de [DepartmentShapeRepository] que lee la geometría
/// generada desde `tools/source/co.svg` en `assets/data/colombia_departments_geo.json`
/// y la mantiene en caché en memoria.
class LocalDepartmentShapeRepository implements DepartmentShapeRepository {
  LocalDepartmentShapeRepository({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  static const String assetPath = 'assets/data/colombia_departments_geo.json';

  /// Caché estática cuando se usa `rootBundle` para evitar re-parsear el JSON al reabrir la pantalla.
  static ColombiaMapGeometry? _sharedCache;

  final AssetBundle _assetBundle;
  ColombiaMapGeometry? _instanceCache;

  @override
  Future<ColombiaMapGeometry> getGeometry() async {
    if (_instanceCache != null) {
      return _instanceCache!;
    }
    if (identical(_assetBundle, rootBundle) && _sharedCache != null) {
      _instanceCache = _sharedCache;
      return _sharedCache!;
    }

    final jsonString = await _assetBundle.loadString(assetPath);
    final geometry = parseGeometryJson(jsonString);

    _instanceCache = geometry;
    if (identical(_assetBundle, rootBundle)) {
      _sharedCache = geometry;
    }
    return geometry;
  }

  /// Parsea el contenido JSON de `colombia_departments_geo.json` a entidades de dominio.
  static ColombiaMapGeometry parseGeometryJson(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final boundsJson = decoded['bounds'] as Map<String, dynamic>;
    final bounds = MapBounds(
      minX: (boundsJson['minX'] as num).toDouble(),
      minY: (boundsJson['minY'] as num).toDouble(),
      maxX: (boundsJson['maxX'] as num).toDouble(),
      maxY: (boundsJson['maxY'] as num).toDouble(),
    );

    final departmentsJson = decoded['departments'] as List<dynamic>;
    final parsedShapes = <DepartmentShape>[];
    DepartmentShape? bogotaShape;

    for (final rawDept in departmentsJson) {
      final deptMap = rawDept as Map<String, dynamic>;
      final code = deptMap['code'] as String;
      final ringsRaw = deptMap['rings'] as List<dynamic>;

      final rings = <List<MapPoint>>[];
      for (final rawRing in ringsRaw) {
        final ringPointsRaw = rawRing as List<dynamic>;
        final points = <MapPoint>[];
        for (final rawPoint in ringPointsRaw) {
          final pair = rawPoint as List<dynamic>;
          points.add(
            MapPoint(
              (pair[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            ),
          );
        }
        if (points.isNotEmpty) {
          rings.add(List<MapPoint>.unmodifiable(points));
        }
      }

      final shape = DepartmentShape(
        code: code,
        rings: List<List<MapPoint>>.unmodifiable(rings),
      );

      // Bogotá D.C. ('11') es un enclave dentro de Cundinamarca ('25');
      // se ubica al final para pintarse encima de Cundinamarca.
      if (code == '11') {
        bogotaShape = shape;
      } else {
        parsedShapes.add(shape);
      }
    }

    if (bogotaShape != null) {
      parsedShapes.add(bogotaShape);
    }

    return ColombiaMapGeometry(
      bounds: bounds,
      shapes: List<DepartmentShape>.unmodifiable(parsedShapes),
    );
  }
}
