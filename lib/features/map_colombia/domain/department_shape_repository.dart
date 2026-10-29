import 'package:via_justa/features/map_colombia/domain/department_shape.dart';

/// Contrato asíncrono para consultar las formas poligonales del mapa de departamentos de Colombia.
///
/// Se mantiene separado de `DepartmentRepository` (que sigue siendo síncrono para el catálogo)
/// porque la geometría vectorial se carga desde el asset local generado a partir del SVG real.
abstract class DepartmentShapeRepository {
  /// Carga la geometría vectorial de los 33 territorios de Colombia y sus límites (`bounds`).
  Future<ColombiaMapGeometry> getGeometry();
}
