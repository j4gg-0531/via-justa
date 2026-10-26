/// Municipio inmutable con código DIVIPOLA, nombre, código de departamento y si es piloto.
class Municipality {
  const Municipality({
    required this.code,
    required this.name,
    required this.departmentCode,
    required this.isPilot,
  });

  final String code;
  final String name;
  final String departmentCode;
  final bool isPilot;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Municipality &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name &&
          departmentCode == other.departmentCode &&
          isPilot == other.isPilot;

  @override
  int get hashCode =>
      code.hashCode ^ name.hashCode ^ departmentCode.hashCode ^ isPilot.hashCode;

  @override
  String toString() =>
      'Municipality(code: $code, name: $name, departmentCode: $departmentCode, isPilot: $isPilot)';
}