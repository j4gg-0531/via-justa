/// Modelo puro e inmutable de un sitio icónico verificado con fotografía bajo
/// licencia Creative Commons para la portada y la guía cultural de la ciudad.
class CityLandmark {
  const CityLandmark({
    required this.id,
    required this.assetPath,
    required this.titleKey,
    required this.subtitleKey,
    required this.chipKey,
    required this.author,
    required this.license,
    required this.sourceUrl,
  });

  final String id;

  /// Ruta del asset local empaquetado (`assets/images/cities/...`).
  final String assetPath;

  /// Clave de traducción del nombre del sitio icónico.
  final String titleKey;

  /// Clave de traducción de la descripción breve del sitio.
  final String subtitleKey;

  /// Clave de traducción corta para el chip interactivo del carrusel.
  final String chipKey;

  /// Autor original de la fotografía según Wikimedia Commons.
  final String author;

  /// Licencia Creative Commons explícita (ej. `CC BY-SA 3.0`).
  final String license;

  /// URL `https://` de la ficha verificable en Wikimedia Commons.
  final String sourceUrl;

  /// Etiqueta compacta de atribución visible en la interfaz.
  String get attributionLabel => '$author · $license (Wikimedia Commons)';
}

/// Catálogo determinístico de sitios icónicos con fotografía verificada (CC)
/// por código DIVIPOLA municipal.
class CityLandmarkCatalog {
  const CityLandmarkCatalog._();

  static const String valleduparCode = '20001';

  static const CityLandmark rioGuatapuri = CityLandmark(
    id: 'rio_guatapuri',
    assetPath: 'assets/images/cities/valledupar/rio_guatapuri.jpg',
    titleKey: 'municipality.landmarks.guatapuri_title',
    subtitleKey: 'municipality.landmarks.guatapuri_subtitle',
    chipKey: 'municipality.landmarks.guatapuri_chip',
    author: 'Idaligomezmartinez',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Rio_guatapuri.JPG',
  );

  static const CityLandmark piloneraMayor = CityLandmark(
    id: 'pilonera_mayor',
    assetPath: 'assets/images/cities/valledupar/pilonera_mayor.jpg',
    titleKey: 'municipality.landmarks.pilonera_title',
    subtitleKey: 'municipality.landmarks.pilonera_subtitle',
    chipKey: 'municipality.landmarks.pilonera_chip',
    author: 'Petruss',
    license: 'CC BY-SA 3.0',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Monumento_a_Consuelo_Araujo_Noguera.JPG',
  );

  static const CityLandmark plazaAlfonsoLopez = CityLandmark(
    id: 'plaza_alfonso_lopez',
    assetPath: 'assets/images/cities/valledupar/plaza_alfonso_lopez.jpg',
    titleKey: 'municipality.landmarks.plaza_title',
    subtitleKey: 'municipality.landmarks.plaza_subtitle',
    chipKey: 'municipality.landmarks.plaza_chip',
    author: 'Idaligomezmartinez',
    license: 'CC BY-SA 3.0',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Valledupar_La_revolucion_en_marcha.JPG',
  );

  static const CityLandmark rotondaAcordeon = CityLandmark(
    id: 'rotonda_acordeon',
    assetPath: 'assets/images/cities/valledupar/rotonda_acordeon.jpg',
    titleKey: 'municipality.landmarks.acordeon_title',
    subtitleKey: 'municipality.landmarks.acordeon_subtitle',
    chipKey: 'municipality.landmarks.acordeon_chip',
    author: 'Jdvillalobos',
    license: 'CC BY-SA 3.0',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Valledupar,_rotonda_Pedazo_de_Acorde%C3%B3n.JPG',
  );

  /// Galería principal de la portada de Valledupar (`20001`).
  static const List<CityLandmark> valleduparLandmarks = <CityLandmark>[
    rioGuatapuri,
    piloneraMayor,
    plazaAlfonsoLopez,
    rotondaAcordeon,
  ];

  /// Retorna la galería de sitios icónicos con fotografía CC para un municipio,
  /// o una lista vacía cuando el municipio aún usa ilustración regional.
  static List<CityLandmark> forMunicipality(String municipalityCode) {
    if (municipalityCode.trim() == valleduparCode) {
      return valleduparLandmarks;
    }
    return const <CityLandmark>[];
  }

  /// Portada compacta para destacar el municipio piloto en el selector de Cesar.
  static CityLandmark? coverForMunicipality(String municipalityCode) {
    final landmarks = forMunicipality(municipalityCode);
    return landmarks.isEmpty ? null : landmarks.first;
  }

  /// Fotografía editorial principal para la vista completa de Ciudad y Cultura (`VJ-15`),
  /// distinta de la primera foto de la portada para evitar repetición visual.
  static CityLandmark? editorialHeroForMunicipality(String municipalityCode) {
    if (municipalityCode.trim() == valleduparCode) {
      return plazaAlfonsoLopez;
    }
    return null;
  }
}
