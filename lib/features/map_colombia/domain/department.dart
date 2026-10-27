/// Departamento inmutable con código, nombre y disponibilidad.
class Department {
  const Department({
    required this.code,
    required this.name,
    required this.isAvailable,
  });

  final String code;
  final String name;
  final bool isAvailable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Department &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name &&
          isAvailable == other.isAvailable;

  @override
  int get hashCode =>
      code.hashCode ^ name.hashCode ^ isAvailable.hashCode;

  @override
  String toString() =>
      'Department(code: $code, name: $name, isAvailable: $isAvailable)';
}

/// Catálogo de departamentos (por ahora solo Cesar).
class Departments {
  Departments._();

  static const cesar = Department(code: '20', name: 'Cesar', isAvailable: true);
  static const laGuajira = Department(
    code: '44',
    name: 'La Guajira',
    isAvailable: false,
  );
  static const magdalena = Department(
    code: '47',
    name: 'Magdalena',
    isAvailable: false,
  );
  static const norteDeSantander = Department(
    code: '54',
    name: 'Norte de Santander',
    isAvailable: false,
  );

  static const all = <Department>[
    cesar,
    laGuajira,
    magdalena,
    norteDeSantander,
  ];

  static Department? byCode(String code) {
    switch (code) {
      case '20':
        return cesar;
      case '44':
        return laGuajira;
      case '47':
        return magdalena;
      case '54':
        return norteDeSantander;
      default:
        return null;
    }
  }
}
