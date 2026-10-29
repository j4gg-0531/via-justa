import 'package:via_justa/features/map_colombia/domain/department.dart';

/// Punto bidimensional en el espacio vectorial del mapa de Colombia (0..1000 en el SVG fuente).
/// Definido en Dart puro (sin `dart:ui`) para mantener la capa de dominio libre de Flutter.
class MapPoint {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'MapPoint($x, $y)';
}

/// Caja delimitadora global (`bounds`) de las coordenadas vectoriales del mapa.
class MapBounds {
  const MapBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
}

/// Calcula el centroide promedio de los vértices de un anillo poligonal.
MapPoint calculateRingCenter(List<MapPoint> ring) {
  if (ring.isEmpty) return const MapPoint(0, 0);

  // Si el último vértice repite el primero para cerrar el anillo, no lo duplicamos en el promedio.
  final effectiveLength =
      (ring.length > 1 && ring.first == ring.last) ? ring.length - 1 : ring.length;

  var sumX = 0.0;
  var sumY = 0.0;
  for (var i = 0; i < effectiveLength; i++) {
    sumX += ring[i].x;
    sumY += ring[i].y;
  }
  return MapPoint(sumX / effectiveLength, sumY / effectiveLength);
}

/// Geometría vectorial de un territorio colombiano (departamento o Distrito Capital).
/// Se une con [Department] exclusivamente mediante el código DANE de 2 dígitos ([code]).
class DepartmentShape {
  const DepartmentShape({
    required this.code,
    required this.rings,
  });

  /// Código DANE DIVIPOLA de 2 dígitos (ej. `'20'` para Cesar, `'88'` para San Andrés).
  final String code;

  /// Lista de anillos cerrados (`[[MapPoint(x, y), ...], ...]`).
  /// Los anillos adicionales representan islas separadas, no huecos.
  final List<List<MapPoint>> rings;

  /// Anillo principal del territorio (el de mayor cantidad de vértices).
  List<MapPoint> get primaryRing {
    if (rings.isEmpty) return const <MapPoint>[];
    var largest = rings.first;
    for (var i = 1; i < rings.length; i++) {
      if (rings[i].length > largest.length) {
        largest = rings[i];
      }
    }
    return largest;
  }

  /// Punto promedio del anillo principal en coordenadas del SVG.
  MapPoint get primaryCenter => calculateRingCenter(primaryRing);
}

/// Geometría completa del mapa de departamentos de Colombia (`bounds` + 33 formas).
class ColombiaMapGeometry {
  const ColombiaMapGeometry({
    required this.bounds,
    required this.shapes,
  });

  final MapBounds bounds;
  final List<DepartmentShape> shapes;

  /// Busca la forma de un departamento por su código DANE de 2 dígitos.
  DepartmentShape? shapeByCode(String code) {
    final normalized = code.trim();
    for (final shape in shapes) {
      if (shape.code == normalized) {
        return shape;
      }
    }
    return null;
  }

  /// Convierte un punto de coordenadas locales del lienzo `(0..width, 0..height)`
  /// al sistema de coordenadas original del SVG.
  MapPoint canvasOffsetToSvgPoint(double dx, double dy) {
    return MapPoint(dx + bounds.minX, dy + bounds.minY);
  }

  /// Devuelve la posición en el lienzo `(0..width, 0..height)` del centroide principal
  /// de un territorio identificado por su código DANE.
  MapPoint? canvasAnchorForCode(String code) {
    final shape = shapeByCode(code);
    if (shape == null || shape.rings.isEmpty) return null;
    final center = shape.primaryCenter;
    return MapPoint(center.x - bounds.minX, center.y - bounds.minY);
  }
}

/// Unión por código DANE entre un territorio del catálogo ([Department]) y su forma ([DepartmentShape]).
class DepartmentMapFeature {
  const DepartmentMapFeature({
    required this.department,
    required this.shape,
  });

  final Department department;
  final DepartmentShape shape;
}

/// Une el catálogo de departamentos con la geometría vectorial exclusivamente por código DANE.
/// Respeta el orden de pintado de [shapes] (donde los enclaves como Bogotá, D.C. `'11'`
/// se ubican después del departamento envolvente Cundinamarca `'25'`).
List<DepartmentMapFeature> joinDepartmentsWithShapes({
  required List<Department> departments,
  required List<DepartmentShape> shapes,
}) {
  final byCode = <String, Department>{
    for (final dept in departments) dept.code: dept,
  };

  final result = <DepartmentMapFeature>[];
  for (final shape in shapes) {
    final dept = byCode[shape.code];
    if (dept != null) {
      result.add(DepartmentMapFeature(department: dept, shape: shape));
    }
  }
  return result;
}
