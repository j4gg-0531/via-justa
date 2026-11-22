import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';

/// Repositorio de muestra sin red usado exclusivamente en modo DEMO
/// (`supabaseClientProvider == null`).
///
/// Todos los registros devueltos se rotulan con `isDemo = true` para impedir
/// que la interfaz presente contenido sin conexión como si fuera en vivo.
class DemoCityRepository implements CityRepository {
  DemoCityRepository({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() _nowProvider;

  static const String _pilotCode = '20001';

  @override
  Future<CityOverview> getCityOverview({
    required String municipalityCode,
    required String localeCode,
    bool includeDemo = false,
  }) async {
    final code = municipalityCode.trim();
    _assertPilotOrThrow(code);
    final normalizedLocale = normalizeCityLocale(localeCode);
    final isEn = normalizedLocale == 'en';

    return CityOverview(
      municipalityCode: _pilotCode,
      municipalityName: 'Valledupar',
      departmentCode: '20',
      isPilot: true,
      requestedLocale: normalizedLocale,
      hasLocaleFallback: false,
      content: _buildDemoContent(isEn: isEn, requestedLocale: normalizedLocale),
      events: _buildDemoEvents(),
    );
  }

  @override
  Future<List<CityEvent>> getCityEvents({
    required String municipalityCode,
    bool includeDemo = false,
  }) async {
    final code = municipalityCode.trim();
    _assertPilotOrThrow(code);
    return _buildDemoEvents();
  }

  void _assertPilotOrThrow(String code) {
    if (code == _pilotCode) return;
    if (RegExp(r'^[0-9]{5}$').hasMatch(code) && code != '99999') {
      throw CityLoadException(
        CityLoadErrorKind.notPilot,
        'Demo non-pilot municipality: $code',
      );
    }
    throw CityLoadException(
      CityLoadErrorKind.notFound,
      'Demo municipality not found: $code',
    );
  }

  List<CityEvent> _buildDemoEvents() {
    final now = _nowProvider().toUtc();
    final startsAt = DateTime.parse('2027-04-28T00:00:00-05:00');
    final endsAt = DateTime.parse('2027-05-02T23:59:59-05:00');
    final bool isActive =
        !now.isBefore(startsAt.toUtc()) && !now.isAfter(endsAt.toUtc());
    final CityEventTemporalStatus status;
    if (isActive) {
      status = CityEventTemporalStatus.active;
    } else if (startsAt.toUtc().isAfter(now)) {
      status = CityEventTemporalStatus.upcoming;
    } else {
      status = CityEventTemporalStatus.past;
    }

    return <CityEvent>[
      CityEvent(
        id: 'demo-festival-vallenato-2027',
        municipalityCode: _pilotCode,
        name: 'Festival de la Leyenda Vallenata (Edición Anual Oficial)',
        descriptionEs:
            'Certamen folclórico anual de acordeoneros, verseadores y canciones inéditas en Valledupar. Se celebra oficialmente a finales de abril.',
        descriptionEn:
            'Annual folkloric contest of accordionists, traditional improvisors, and unreleased songs in Valledupar. Officially held in late April.',
        venue:
            'Parque de la Leyenda Vallenata Consuelo Araujonoguera y Plaza Alfonso López',
        startsAt: startsAt,
        endsAt: endsAt,
        temporalStatus: status,
        isCurrentlyActive: isActive,
        isDemo: true,
        sourceCitation:
            'Fundación Festival de la Leyenda Vallenata — Programación anual oficial',
      ),
    ];
  }

  static List<CityContentItem> _buildDemoContent({
    required bool isEn,
    required String requestedLocale,
  }) {
    final resolved = isEn ? 'en' : 'es';
    return <CityContentItem>[
      CityContentItem(
        id: 'demo-valledupar-welcome-$resolved',
        municipalityCode: _pilotCode,
        slug: 'valledupar_welcome',
        section: CityContentSection.welcome,
        requestedLocale: requestedLocale,
        resolvedLocale: resolved,
        isLocaleFallback: false,
        title: isEn
            ? 'Valledupar, City of the Holy Kings of the Upar Valley'
            : 'Valledupar, Ciudad de los Santos Reyes del Valle de Upar',
        body: isEn
            ? 'Capital of the department of Cesar, founded on January 6, 1550 by Hernando de Santana. Recognized as the cradle of Vallenato folklore and an agro-industrial, commercial, and university hub in the northeastern Colombian Caribbean.'
            : 'Capital del departamento del Cesar, fundada el 6 de enero de 1550 por Hernando de Santana. Reconocida como cuna del folclor vallenato y centro agroindustrial, comercial y universitario del nororiente caribe colombiano.',
        imagePath: 'assets/images/cities/valledupar/catedral_ecce_homo.jpg',
        imageLicense: 'CC BY-SA 4.0 — XAVARDILA (Wikimedia Commons)',
        sourceCitation: isEn
            ? "Mayor's Office of Valledupar — Institutional and historical municipality profile (DIVIPOLA 20001)"
            : 'Alcaldía de Valledupar — Reseña histórica e institucional del municipio (DIVIPOLA 20001)',
        sourceUrl: 'https://www.valledupar-cesar.gov.co',
        sortOrder: 1,
        isDemo: true,
      ),
      CityContentItem(
        id: 'demo-valledupar-context-$resolved',
        municipalityCode: _pilotCode,
        slug: 'valledupar_context',
        section: CityContentSection.context,
        requestedLocale: requestedLocale,
        resolvedLocale: resolved,
        isLocaleFallback: false,
        title: isEn
            ? 'Valley Between Two Mountain Ranges and the Guatapurí River'
            : 'Valle entre dos sistemas montañosos y el río Guatapurí',
        body: isEn
            ? 'Located at 169 meters above sea level between the Sierra Nevada de Santa Marta to the west and the Serranía del Perijá to the east. Its urban layout spans five reference zones (North, Downtown, South, East, and West) bordered by the Guatapurí River.'
            : 'Ubicada a 169 metros sobre el nivel del mar entre la Sierra Nevada de Santa Marta al occidente y la Serranía del Perijá al oriente. Su trama urbana está articulada en cinco sectores de referencia (Norte, Centro, Sur, Oriente y Occidente) bordeados por el río Guatapurí.',
        imagePath: 'assets/images/cities/valledupar/rio_guatapuri.jpg',
        imageLicense: 'CC BY-SA 3.0 — Idaligomezmartinez (Wikimedia Commons)',
        sourceCitation: isEn
            ? 'Agustín Codazzi Geographic Institute (IGAC) and DANE — Geography of Cesar and Valledupar'
            : 'Instituto Geográfico Agustín Codazzi (IGAC) y DANE — Geografía del Cesar y Valledupar',
        sourceUrl: 'https://www.dane.gov.co',
        sortOrder: 2,
        isDemo: true,
      ),
      CityContentItem(
        id: 'demo-vallenato-unesco-$resolved',
        municipalityCode: _pilotCode,
        slug: 'vallenato_unesco',
        section: CityContentSection.culture,
        requestedLocale: requestedLocale,
        resolvedLocale: resolved,
        isLocaleFallback: false,
        title: isEn
            ? 'Traditional Vallenato Music and UNESCO Creative City'
            : 'Música Vallenata Tradicional y Ciudad Creativa UNESCO',
        body: isEn
            ? 'Traditional Vallenato music of the Greater Magdalena region—performed with caja, guacharaca, and diatonic accordion across four rhythms: paseo, merengue, son, and puya—was inscribed by UNESCO in 2015 on the Intangible Cultural Heritage List. In 2019, Valledupar was designated a UNESCO Creative City of Music.'
            : 'La música vallenata tradicional del Magdalena Grande —interpretada con caja, guacharaca y acordeón diatónico en los cuatro aires: paseo, merengue, son y puya— fue inscrita por la UNESCO en 2015 en la Lista de Patrimonio Cultural Inmaterial. En 2019, Valledupar fue designada Ciudad Creativa de la Música por la UNESCO.',
        imagePath: 'assets/images/cities/valledupar/rotonda_acordeon.jpg',
        imageLicense: 'CC BY-SA 3.0 — Jdvillalobos (Wikimedia Commons)',
        sourceCitation: isEn
            ? 'UNESCO — Decision 10.COM 10.a.3 (2015) and UNESCO Creative Cities Network (2019)'
            : 'UNESCO — Decisión 10.COM 10.a.3 (2015) y Red de Ciudades Creativas de la UNESCO (2019)',
        sourceUrl: isEn
            ? 'https://ich.unesco.org/en/USL/traditional-vallenato-music-of-the-greater-magdalena-region-01095'
            : 'https://ich.unesco.org/es/USL/la-musica-vallenata-tradicional-del-magdalena-grande-01095',
        sortOrder: 3,
        isDemo: true,
      ),
      CityContentItem(
        id: 'demo-plaza-hurtado-$resolved',
        municipalityCode: _pilotCode,
        slug: 'plaza_alfonso_lopez_y_hurtado',
        section: CityContentSection.places,
        requestedLocale: requestedLocale,
        resolvedLocale: resolved,
        isLocaleFallback: false,
        title: isEn
            ? 'Alfonso López Square, Historic Center, and Hurtado Riverfront'
            : 'Plaza Alfonso López, Centro Histórico y Balneario Hurtado',
        body: isEn
            ? 'Alfonso López Square in the Historic Center preserves the colonial and republican architecture where the Vallenato Legend Festival began in 1968. To the northeast, the Hurtado riverfront along the Guatapurí River and the "Consuelo Araujonoguera" Vallenato Legend Park form the city\'s main cultural and environmental corridor.'
            : 'La Plaza Alfonso López en el Centro Histórico conserva la arquitectura republicana y colonial donde nació el Festival de la Leyenda Vallenata en 1968. Al norte oriente, el Balneario Hurtado sobre el río Guatapurí y el Parque de la Leyenda Vallenata "Consuelo Araujonoguera" integran el corredor ambiental y cultural de la ciudad.',
        imagePath: 'assets/images/cities/valledupar/plaza_alfonso_lopez.jpg',
        imageLicense: 'CC BY-SA 3.0 — Idaligomezmartinez (Wikimedia Commons)',
        sourceCitation: isEn
            ? 'Ministry of Cultures, Arts, and Knowledge of Colombia — Urban Heritage of Valledupar'
            : 'Ministerio de las Culturas, las Artes y los Saberes de Colombia — Patrimonio Urbano de Valledupar',
        sourceUrl: 'https://www.mincultura.gov.co',
        sortOrder: 4,
        isDemo: true,
      ),
      CityContentItem(
        id: 'demo-gastronomia-$resolved',
        municipalityCode: _pilotCode,
        slug: 'gastronomia_tradicional_cesar',
        section: CityContentSection.gastronomy,
        requestedLocale: requestedLocale,
        resolvedLocale: resolved,
        isLocaleFallback: false,
        title: isEn
            ? 'Traditional Cuisine of the Cacique Upar Valley'
            : 'Gastronomía tradicional del valle del Cacique Upar',
        body: isEn
            ? 'Local gastronomy features wood-fired creole hen sancocho, stewed or roasted goat served with bollo limpio and cassava, vermicelli rice with ground beef, and traditional corn and coastal-cheese baked goods such as almojábanas and chiricanas.'
            : 'La cocina local destaca por el sancocho de gallina criolla en fogón de leña, el chivo guisado o asado acompañado de bollo limpio y yuca, el arroz de fideo con carne molida y los amasijos tradicionales como las almojábanas y chiricanas de maíz y queso costeño.',
        sourceCitation: isEn
            ? 'Ministry of Culture — Basic Library of Traditional Colombian Cuisines (Caribbean / Cesar Region)'
            : 'Ministerio de Cultura — Biblioteca Básica de Cocinas Tradicionales de Colombia (Región Caribe / Cesar)',
        sourceUrl: 'https://www.mincultura.gov.co',
        sortOrder: 5,
        isDemo: true,
      ),
      CityContentItem(
        id: 'demo-emergencia-$resolved',
        municipalityCode: _pilotCode,
        slug: 'lineas_atencion_y_emergencia_vup',
        section: CityContentSection.emergency,
        requestedLocale: requestedLocale,
        resolvedLocale: resolved,
        isLocaleFallback: false,
        title: isEn
            ? 'Emergency Hotlines and Institutional Guidance in Valledupar'
            : 'Líneas de emergencia y orientación institucional en Valledupar',
        body: isEn
            ? 'For medical, police, or traffic emergencies, dial the National Emergency Hotline 123 (24/7). For civic rights guidance, housing inquiries, or migrant support, contact the Municipal Ombudsman (Personería de Valledupar) or the Regional Ombudsman\'s Office (Defensoría del Pueblo Regional Cesar).'
            : 'Para emergencias médicas, policiales o de tránsito está habilitada la Línea Única Nacional 123 (24 horas). Para orientación en derechos ciudadanos, arrendamiento o atención a población migrante, acuda a la Personería Municipal de Valledupar o a la Defensoría del Pueblo Regional Cesar.',
        sourceCitation: isEn
            ? "Mayor's Office of Valledupar / Regional Ombudsman's Office of Cesar — Citizen Service Directory"
            : 'Alcaldía de Valledupar / Defensoría del Pueblo Regional Cesar — Directorio de Atención Ciudadana',
        sourceUrl: 'https://www.defensoria.gov.co',
        sortOrder: 6,
        isDemo: true,
      ),
    ];
  }
}
