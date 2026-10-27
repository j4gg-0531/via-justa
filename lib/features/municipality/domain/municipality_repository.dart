import 'package:via_justa/features/municipality/domain/municipality.dart';

/// Contrato del repositorio de municipios.
abstract interface class MunicipalityRepository {
  Future<List<Municipality>> getByDepartment(String departmentCode);

  /// Devuelve el municipio con ese código DIVIPOLA, o null si no existe.
  Future<Municipality?> getByCode(String code);
}
