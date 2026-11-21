/// Identidad visual e ilustrada por municipio y departamento (M03, M13, M14, M15).
///
/// Cumple con la arquitectura en 3 niveles:
/// - **Nivel 1 (Protagonista):** Valledupar (`20001`) y Cesar (`20`) con composición
///   de árbol de Cañaguate florecido, Acordeón Vallenato, Río Guatapurí y Sierra Nevada.
/// - **Nivel 2 (Capitales y Regiones de Colombia):** Emblemas ilustrados por región
///   y departamento (Caribe, Sierra, Andina, Cafetera, Pacífico, Insular, Llanos, Amazonía).
/// - **Nivel 3 (Subregiones municipales del Cesar):** Serranía y Café, Ciénaga de Zapatosa
///   y Sabana Cálida del Valle del Cacique Upar.
enum CulturalMotifKind {
  /// Valledupar y Cesar: Árbol de Cañaguate amarillo, Acordeón y Río Guatapurí.
  valleduparCanaguateAccordion,

  /// Subregión Norte/Serranía del Cesar (Pueblo Bello, Manaure, La Paz, San Diego).
  cesarSerraniaCoffee,

  /// Subregión Ciénaga de Zapatosa y Río Magdalena (Chimichagua, Tamalameque, Gamarra).
  cesarZapatosaLagoon,

  /// Subregión Sabana y Sur del Cesar (Aguachica, Codazzi, Bosconia, Chiriguaná, etc.).
  cesarSavannaCotton,

  /// Caribe Amurallado y Sabanas (Bolívar / Cartagena, Sucre, Córdoba).
  caribbeanWalledSea,

  /// Sierra Nevada frente al Mar Caribe (Magdalena / Santa Marta).
  sierraSnowyCoast,

  /// Río Magdalena y Carnaval (Atlántico / Barranquilla).
  carnavalMagdalenaRiver,

  /// Dunas Guajiras y Tejido Wayúu (La Guajira / Riohacha).
  wayuuDesertDunes,

  /// Archipiélago de Siete Colores (San Andrés y Providencia).
  sevenColorsArchipelago,

  /// Cordillera Andina, Cerros y Cañones (Bogotá D.C., Cundinamarca, Santander, Boyacá, etc.).
  andeanCapitalPeaks,

  /// Montañas de Flores y Paisaje Cafetero (Antioquia / Medellín, Caldas, Risaralda, Quindío).
  coffeeFlowersValley,

  /// Brisa del Pacífico, Palmeras y Farallones (Valle / Cali, Cauca, Chocó).
  pacificPalmsBreeze,

  /// Amanecer Llanero y Morichales (Meta, Casanare, Arauca, Vichada).
  llanosOrinocoSunrise,

  /// Selva Amazónica y Ríos Caudalosos (Amazonas, Caquetá, Putumayo, Guaviare, Guainía, Vaupés).
  amazonSelvaRivers,
}

/// Modelo puro e inmutable de identidad visual cultural para un territorio.
class CityVisualIdentity {
  const CityVisualIdentity({
    required this.motif,
    required this.subtitleKey,
    required this.tagKey,
    required this.featureChipKeys,
    required this.skyStartHex,
    required this.skyEndHex,
    required this.accentHex,
    required this.secondaryHex,
  });

  final CulturalMotifKind motif;

  /// Clave de traducción del subtítulo descriptivo (ej. en tarjeta del mapa o detalle).
  final String subtitleKey;

  /// Clave de traducción corta para chips o subtítulos de lista.
  final String tagKey;

  /// Claves de traducción de los elementos característicos (ej. Cañaguate, Acordeón, Río Guatapurí).
  final List<String> featureChipKeys;

  /// Color superior del fondo ilustrado (ARGB 32-bit int).
  final int skyStartHex;

  /// Color inferior del fondo ilustrado (ARGB 32-bit int).
  final int skyEndHex;

  /// Color de acento principal del motivo cultural (ej. Amarillo Cañaguate `0xFFFFCA28`).
  final int accentHex;

  /// Color secundario complementario (ej. Azul Guatapurí o Verde Sierra).
  final int secondaryHex;
}

/// Catálogo determinista O(1) de identidades visuales culturales por código DANE.
class CityVisualIdentityCatalog {
  const CityVisualIdentityCatalog._();

  static const CityVisualIdentity valleduparIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.valleduparCanaguateAccordion,
    subtitleKey: 'municipality.cultural.valledupar_subtitle',
    tagKey: 'municipality.cultural.valledupar_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_canaguate',
      'municipality.cultural.chip_accordion',
      'municipality.cultural.chip_guatapuri',
    ],
    skyStartHex: 0xFF0F2942,
    skyEndHex: 0xFF1B4B6B,
    accentHex: 0xFFFFCA28,
    secondaryHex: 0xFF26A69A,
  );

  static const CityVisualIdentity _cesarSerraniaIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.cesarSerraniaCoffee,
    subtitleKey: 'municipality.cultural.serrania_subtitle',
    tagKey: 'municipality.cultural.serrania_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_serrania',
      'municipality.cultural.chip_coffee',
      'municipality.cultural.chip_canaguate',
    ],
    skyStartHex: 0xFF163A32,
    skyEndHex: 0xFF285E50,
    accentHex: 0xFFFFCA28,
    secondaryHex: 0xFF66BB6A,
  );

  static const CityVisualIdentity _cesarZapatosaIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.cesarZapatosaLagoon,
    subtitleKey: 'municipality.cultural.zapatosa_subtitle',
    tagKey: 'municipality.cultural.zapatosa_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_zapatosa',
      'municipality.cultural.chip_river',
      'municipality.cultural.chip_sunset',
    ],
    skyStartHex: 0xFF103152,
    skyEndHex: 0xFF1E5680,
    accentHex: 0xFFFFB300,
    secondaryHex: 0xFF29B6F6,
  );

  static const CityVisualIdentity _cesarSavannaIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.cesarSavannaCotton,
    subtitleKey: 'municipality.cultural.savanna_subtitle',
    tagKey: 'municipality.cultural.savanna_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_savanna',
      'municipality.cultural.chip_canaguate',
      'municipality.cultural.chip_valley',
    ],
    skyStartHex: 0xFF1F364D,
    skyEndHex: 0xFF335775,
    accentHex: 0xFFFFCA28,
    secondaryHex: 0xFFFFA726,
  );

  static const CityVisualIdentity _sierraCoastIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.sierraSnowyCoast,
    subtitleKey: 'municipality.cultural.sierra_coast_subtitle',
    tagKey: 'municipality.cultural.sierra_coast_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_sierra',
      'municipality.cultural.chip_caribbean',
      'municipality.cultural.chip_heritage',
    ],
    skyStartHex: 0xFF0D3B66,
    skyEndHex: 0xFF1D6A96,
    accentHex: 0xFFFFD166,
    secondaryHex: 0xFF4ECDC4,
  );

  static const CityVisualIdentity _walledCaribbeanIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.caribbeanWalledSea,
    subtitleKey: 'municipality.cultural.walled_sea_subtitle',
    tagKey: 'municipality.cultural.walled_sea_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_caribbean',
      'municipality.cultural.chip_heritage',
      'municipality.cultural.chip_sunset',
    ],
    skyStartHex: 0xFF1B365D,
    skyEndHex: 0xFF2B5876,
    accentHex: 0xFFFFB703,
    secondaryHex: 0xFFFB8500,
  );

  static const CityVisualIdentity _carnavalMagdalenaIdentity =
      CityVisualIdentity(
        motif: CulturalMotifKind.carnavalMagdalenaRiver,
        subtitleKey: 'municipality.cultural.magdalena_river_subtitle',
        tagKey: 'municipality.cultural.magdalena_river_tag',
        featureChipKeys: <String>[
          'municipality.cultural.chip_river',
          'municipality.cultural.chip_caribbean',
          'municipality.cultural.chip_heritage',
        ],
        skyStartHex: 0xFF14365D,
        skyEndHex: 0xFF1E5785,
        accentHex: 0xFFFFCA28,
        secondaryHex: 0xFF2EC4B6,
      );

  static const CityVisualIdentity _wayuuDesertIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.wayuuDesertDunes,
    subtitleKey: 'municipality.cultural.wayuu_subtitle',
    tagKey: 'municipality.cultural.wayuu_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_caribbean',
      'municipality.cultural.chip_sunset',
      'municipality.cultural.chip_heritage',
    ],
    skyStartHex: 0xFF3D2645,
    skyEndHex: 0xFF7A3E48,
    accentHex: 0xFFFFB703,
    secondaryHex: 0xFFE07A5F,
  );

  static const CityVisualIdentity _sevenColorsIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.sevenColorsArchipelago,
    subtitleKey: 'municipality.cultural.san_andres_subtitle',
    tagKey: 'municipality.cultural.san_andres_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_caribbean',
      'municipality.cultural.chip_sunset',
      'municipality.cultural.chip_heritage',
    ],
    skyStartHex: 0xFF004E64,
    skyEndHex: 0xFF00A5CF,
    accentHex: 0xFFFFD166,
    secondaryHex: 0xFF25A18E,
  );

  static const CityVisualIdentity _coffeeFlowersIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.coffeeFlowersValley,
    subtitleKey: 'municipality.cultural.coffee_flowers_subtitle',
    tagKey: 'municipality.cultural.coffee_flowers_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_coffee',
      'municipality.cultural.chip_serrania',
      'municipality.cultural.chip_heritage',
    ],
    skyStartHex: 0xFF183A37,
    skyEndHex: 0xFF2E6F40,
    accentHex: 0xFFFFCA28,
    secondaryHex: 0xFF52B788,
  );

  static const CityVisualIdentity _andeanPeaksIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.andeanCapitalPeaks,
    subtitleKey: 'municipality.cultural.andean_peaks_subtitle',
    tagKey: 'municipality.cultural.andean_peaks_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_serrania',
      'municipality.cultural.chip_heritage',
      'municipality.cultural.chip_valley',
    ],
    skyStartHex: 0xFF1A2A44,
    skyEndHex: 0xFF2D4A73,
    accentHex: 0xFFFFCA28,
    secondaryHex: 0xFF64B5F6,
  );

  static const CityVisualIdentity _pacificPalmsIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.pacificPalmsBreeze,
    subtitleKey: 'municipality.cultural.pacific_breeze_subtitle',
    tagKey: 'municipality.cultural.pacific_breeze_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_valley',
      'municipality.cultural.chip_sunset',
      'municipality.cultural.chip_heritage',
    ],
    skyStartHex: 0xFF1D3557,
    skyEndHex: 0xFF457B9D,
    accentHex: 0xFFFFB703,
    secondaryHex: 0xFF2A9D8F,
  );

  static const CityVisualIdentity _llanosSunriseIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.llanosOrinocoSunrise,
    subtitleKey: 'municipality.cultural.llanos_subtitle',
    tagKey: 'municipality.cultural.llanos_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_savanna',
      'municipality.cultural.chip_sunset',
      'municipality.cultural.chip_river',
    ],
    skyStartHex: 0xFF2D2A4A,
    skyEndHex: 0xFF6B3E52,
    accentHex: 0xFFFFB703,
    secondaryHex: 0xFFF4A261,
  );

  static const CityVisualIdentity _amazonSelvaIdentity = CityVisualIdentity(
    motif: CulturalMotifKind.amazonSelvaRivers,
    subtitleKey: 'municipality.cultural.amazon_subtitle',
    tagKey: 'municipality.cultural.amazon_tag',
    featureChipKeys: <String>[
      'municipality.cultural.chip_river',
      'municipality.cultural.chip_serrania',
      'municipality.cultural.chip_heritage',
    ],
    skyStartHex: 0xFF0F382A,
    skyEndHex: 0xFF1F634B,
    accentHex: 0xFFFFCA28,
    secondaryHex: 0xFF40916C,
  );

  static const Map<String, CityVisualIdentity> _byMunicipalityCode =
      <String, CityVisualIdentity>{
        '20001': valleduparIdentity, // Valledupar (Piloto)
        // Subregión Norte y Serranía del Cesar
        '20570': _cesarSerraniaIdentity, // Pueblo Bello
        '20443': _cesarSerraniaIdentity, // Manaure Balcón del Cesar
        '20621': _cesarSerraniaIdentity, // La Paz
        '20750': _cesarSerraniaIdentity, // San Diego
        // Subregión Ciénaga de Zapatosa y Ribera
        '20175': _cesarZapatosaIdentity, // Chimichagua
        '20787': _cesarZapatosaIdentity, // Tamalameque
        '20295': _cesarZapatosaIdentity, // Gamarra
        '20250': _cesarZapatosaIdentity, // El Paso
        '20032': _cesarZapatosaIdentity, // Astrea
        '20383': _cesarZapatosaIdentity, // La Gloria
      };

  static const Map<String, CityVisualIdentity> _byDepartmentCode =
      <String, CityVisualIdentity>{
        '20': valleduparIdentity, // Cesar
        '47': _sierraCoastIdentity, // Magdalena (Santa Marta)
        '13': _walledCaribbeanIdentity, // Bolívar (Cartagena)
        '70': _walledCaribbeanIdentity, // Sucre (Sincelejo)
        '23': _walledCaribbeanIdentity, // Córdoba (Montería)
        '08': _carnavalMagdalenaIdentity, // Atlántico (Barranquilla)
        '44': _wayuuDesertIdentity, // La Guajira (Riohacha)
        '88': _sevenColorsIdentity, // San Andrés y Providencia
        '05': _coffeeFlowersIdentity, // Antioquia (Medellín)
        '17': _coffeeFlowersIdentity, // Caldas (Manizales)
        '66': _coffeeFlowersIdentity, // Risaralda (Pereira)
        '63': _coffeeFlowersIdentity, // Quindío (Armenia)
        '11': _andeanPeaksIdentity, // Bogotá, D.C.
        '25': _andeanPeaksIdentity, // Cundinamarca
        '15': _andeanPeaksIdentity, // Boyacá
        '68': _andeanPeaksIdentity, // Santander (Bucaramanga)
        '54': _andeanPeaksIdentity, // Norte de Santander (Cúcuta)
        '73': _andeanPeaksIdentity, // Tolima (Ibagué)
        '41': _andeanPeaksIdentity, // Huila (Neiva)
        '52': _andeanPeaksIdentity, // Nariño (Pasto)
        '76': _pacificPalmsIdentity, // Valle del Cauca (Cali)
        '19': _pacificPalmsIdentity, // Cauca (Popayán)
        '27': _pacificPalmsIdentity, // Chocó (Quibdó)
        '50': _llanosSunriseIdentity, // Meta (Villavicencio)
        '85': _llanosSunriseIdentity, // Casanare (Yopal)
        '81': _llanosSunriseIdentity, // Arauca
        '99': _llanosSunriseIdentity, // Vichada
        '91': _amazonSelvaIdentity, // Amazonas (Leticia)
        '18': _amazonSelvaIdentity, // Caquetá (Florencia)
        '86': _amazonSelvaIdentity, // Putumayo (Mocoa)
        '95': _amazonSelvaIdentity, // Guaviare
        '94': _amazonSelvaIdentity, // Guainía
        '97': _amazonSelvaIdentity, // Vaupés
      };

  /// Resuelve la identidad visual para un departamento por su código DANE de 2 dígitos.
  static CityVisualIdentity forDepartment(String departmentCode) {
    return _byDepartmentCode[departmentCode] ?? _andeanPeaksIdentity;
  }

  /// Resuelve la identidad visual para un municipio por su código DIVIPOLA de 5 dígitos.
  static CityVisualIdentity forMunicipality({
    required String municipalityCode,
    required String departmentCode,
    bool isPilot = false,
  }) {
    if (isPilot || municipalityCode == '20001') {
      return valleduparIdentity;
    }
    final direct = _byMunicipalityCode[municipalityCode];
    if (direct != null) {
      return direct;
    }
    if (departmentCode == '20') {
      return _cesarSavannaIdentity;
    }
    return forDepartment(departmentCode);
  }
}
