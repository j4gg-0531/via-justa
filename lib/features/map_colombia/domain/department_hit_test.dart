import 'package:via_justa/features/map_colombia/domain/department_shape.dart';

/// Algoritmo puro de ray-casting para determinar si un [point] `(x, y)`
/// se encuentra dentro de un anillo cerrado [ring].
bool isPointInRing(MapPoint point, List<MapPoint> ring) {
  if (ring.length < 3) return false;

  final x = point.x;
  final y = point.y;
  var inside = false;

  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].x;
    final yi = ring[i].y;
    final xj = ring[j].x;
    final yj = ring[j].y;

    final intersect = ((yi > y) != (yj > y)) &&
        (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
    if (intersect) {
      inside = !inside;
    }
  }
  return inside;
}

/// Evalúa si [point] cae dentro de cualquiera de los anillos (continental o islas)
/// de un [DepartmentShape].
bool isPointInDepartmentShape(MapPoint point, DepartmentShape shape) {
  for (final ring in shape.rings) {
    if (isPointInRing(point, ring)) {
      return true;
    }
  }
  return false;
}

/// Resuelve el código DANE de 2 dígitos del departamento que contiene a [point]
/// evaluando **todos** los anillos de cada forma en [shapes].
///
/// Prioriza enclaves (como Bogotá, D.C. `'11'` frente a Cundinamarca `'25'`)
/// y recorre las formas en orden inverso al de pintado. Devuelve `null` si el
/// punto cae en el mar o fuera de todos los anillos.
String? findDepartmentAtPoint(
  List<DepartmentShape> shapes,
  MapPoint point,
) {
  // 1. Evaluar primero enclaves conocidos (Bogotá D.C. '11' dentro de Cundinamarca '25').
  for (final shape in shapes) {
    if (shape.code == '11' && isPointInDepartmentShape(point, shape)) {
      return shape.code;
    }
  }

  // 2. Evaluar el resto de territorios en orden inverso al de pintado.
  for (var i = shapes.length - 1; i >= 0; i--) {
    final shape = shapes[i];
    if (shape.code == '11') continue;
    if (isPointInDepartmentShape(point, shape)) {
      return shape.code;
    }
  }
  return null;
}
