/// Departamento o distrito capital inmutable con código DANE DIVIPOLA de 2 dígitos,
/// nombre oficial y disponibilidad en el piloto.
///
/// La geometría cartográfica vive de forma separada en `DepartmentShape` para mantener
/// el catálogo ligero y alineado con la futura tabla `public.departments`.
class Department {
  const Department({
    required this.code,
    required this.name,
    required this.isAvailable,
  });

  /// Código DANE DIVIPOLA de 2 dígitos (ej. `'20'` para Cesar, `'11'` para Bogotá, D.C.).
  final String code;

  /// Nombre oficial del departamento o distrito.
  final String name;

  /// Indica si cuenta con municipios activos en el piloto (actualmente `true` solo para Cesar).
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
  int get hashCode => code.hashCode ^ name.hashCode ^ isAvailable.hashCode;

  @override
  String toString() =>
      'Department(code: $code, name: $name, isAvailable: $isAvailable)';
}

/// Catálogo nacional de los 33 territorios de Colombia (32 departamentos, incluido San Andrés, + Bogotá, D.C.).
/// Solo Cesar (`20`) tiene `isAvailable: true` en el piloto actual.
class Departments {
  Departments._();

  // --- Región Insular ---
  static const sanAndres = Department(
    code: '88',
    name: 'San Andrés y Providencia',
    isAvailable: false,
  );

  // --- Región Caribe ---
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

  static const atlantico = Department(
    code: '08',
    name: 'Atlántico',
    isAvailable: false,
  );

  static const cesar = Department(
    code: '20',
    name: 'Cesar',
    isAvailable: true,
  );

  static const bolivar = Department(
    code: '13',
    name: 'Bolívar',
    isAvailable: false,
  );

  static const sucre = Department(
    code: '70',
    name: 'Sucre',
    isAvailable: false,
  );

  static const cordoba = Department(
    code: '23',
    name: 'Córdoba',
    isAvailable: false,
  );

  // --- Región Andina y Nororiental ---
  static const norteDeSantander = Department(
    code: '54',
    name: 'Norte de Santander',
    isAvailable: false,
  );

  static const santander = Department(
    code: '68',
    name: 'Santander',
    isAvailable: false,
  );

  static const antioquia = Department(
    code: '05',
    name: 'Antioquia',
    isAvailable: false,
  );

  static const boyaca = Department(
    code: '15',
    name: 'Boyacá',
    isAvailable: false,
  );

  static const caldas = Department(
    code: '17',
    name: 'Caldas',
    isAvailable: false,
  );

  static const risaralda = Department(
    code: '66',
    name: 'Risaralda',
    isAvailable: false,
  );

  static const quindio = Department(
    code: '63',
    name: 'Quindío',
    isAvailable: false,
  );

  static const cundinamarca = Department(
    code: '25',
    name: 'Cundinamarca',
    isAvailable: false,
  );

  static const bogotaDc = Department(
    code: '11',
    name: 'Bogotá, D.C.',
    isAvailable: false,
  );

  static const tolima = Department(
    code: '73',
    name: 'Tolima',
    isAvailable: false,
  );

  static const huila = Department(
    code: '41',
    name: 'Huila',
    isAvailable: false,
  );

  // --- Región Pacífica ---
  static const choco = Department(
    code: '27',
    name: 'Chocó',
    isAvailable: false,
  );

  static const valleDelCauca = Department(
    code: '76',
    name: 'Valle del Cauca',
    isAvailable: false,
  );

  static const cauca = Department(
    code: '19',
    name: 'Cauca',
    isAvailable: false,
  );

  static const narino = Department(
    code: '52',
    name: 'Nariño',
    isAvailable: false,
  );

  // --- Región Orinoquía ---
  static const arauca = Department(
    code: '81',
    name: 'Arauca',
    isAvailable: false,
  );

  static const casanare = Department(
    code: '85',
    name: 'Casanare',
    isAvailable: false,
  );

  static const vichada = Department(
    code: '99',
    name: 'Vichada',
    isAvailable: false,
  );

  static const meta = Department(
    code: '50',
    name: 'Meta',
    isAvailable: false,
  );

  // --- Región Amazonía ---
  static const guainia = Department(
    code: '94',
    name: 'Guainía',
    isAvailable: false,
  );

  static const guaviare = Department(
    code: '95',
    name: 'Guaviare',
    isAvailable: false,
  );

  static const caqueta = Department(
    code: '18',
    name: 'Caquetá',
    isAvailable: false,
  );

  static const putumayo = Department(
    code: '86',
    name: 'Putumayo',
    isAvailable: false,
  );

  static const vaupes = Department(
    code: '97',
    name: 'Vaupés',
    isAvailable: false,
  );

  static const amazonas = Department(
    code: '91',
    name: 'Amazonas',
    isAvailable: false,
  );

  /// Lista completa de los 33 territorios (32 departamentos + Bogotá, D.C.).
  static const all = <Department>[
    sanAndres,
    laGuajira,
    magdalena,
    atlantico,
    cesar,
    bolivar,
    sucre,
    cordoba,
    norteDeSantander,
    santander,
    antioquia,
    boyaca,
    caldas,
    risaralda,
    quindio,
    cundinamarca,
    bogotaDc,
    tolima,
    huila,
    choco,
    valleDelCauca,
    cauca,
    narino,
    arauca,
    casanare,
    vichada,
    meta,
    guainia,
    guaviare,
    caqueta,
    putumayo,
    vaupes,
    amazonas,
  ];

  /// Resuelve un departamento por su código DANE de 2 dígitos.
  static Department? byCode(String code) {
    final normalized = code.trim();
    for (final department in all) {
      if (department.code == normalized) {
        return department;
      }
    }
    return null;
  }
}
