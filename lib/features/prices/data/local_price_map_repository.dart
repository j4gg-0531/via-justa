import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';

/// Repositorio local de demostración para el mapa de precios y servicios del municipio piloto (M08 / VJ-12).
/// NOTA: Datos de ejemplo rotulados con coordenadas reales de referencia en Valledupar.
class LocalPriceMapRepository implements PriceMapRepository {
  const LocalPriceMapRepository();

  static const _sampleItems = <PriceMapItem>[
    PriceMapItem(
      id: 'map_item_01',
      name: '[DEMO] Hospital Rosario Pumarejo',
      description: 'Muestra DEMO — Atención urgencias 24h · Sector Centro',
      category: PriceMapCategory.services,
      pinKind: PriceMapPinKind.hospital,
      status: PricePinStatus.info,
      pinLabel: '',
      badgeText: '2.4 km',
      normalizedX: 0.34,
      normalizedY: 0.72,
      latitude: 10.4718,
      longitude: -73.2562,
      phone: '6055748400',
      address: 'Calle 16B #19-75, Valledupar',
      sourceType: 'business',
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_02',
      name: '[DEMO] Cruz Roja - Atención a Migrantes',
      description:
          'Muestra DEMO — Punto de orientación y primeros auxilios en Valledupar',
      category: PriceMapCategory.services,
      pinKind: PriceMapPinKind.assistance,
      status: PricePinStatus.info,
      pinLabel: '',
      badgeText: '3.1 km',
      normalizedX: 0.56,
      normalizedY: 0.80,
      latitude: 10.4758,
      longitude: -73.2545,
      phone: '6055712255',
      address: 'Carrera 19 #14-50, Valledupar',
      sourceType: 'business',
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_03',
      name: '[DEMO] Almuerzo corriente · Centro',
      description:
          r'Muestra DEMO — Precio dentro de la mediana de referencia ($12.000 COP)',
      category: PriceMapCategory.prices,
      pinKind: PriceMapPinKind.food,
      status: PricePinStatus.fair,
      pinLabel: r'$12k',
      badgeText: r'$12.000',
      normalizedX: 0.24,
      normalizedY: 0.34,
      latitude: 10.4760,
      longitude: -73.2430,
      address: 'Galería Popular · Centro',
      sourceType: 'price_report',
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_04',
      name: '[DEMO] Taxi Terminal – Centro',
      description:
          r'Muestra DEMO — Reporte por encima de la mediana de referencia ($12.000 COP)',
      category: PriceMapCategory.prices,
      pinKind: PriceMapPinKind.transport,
      status: PricePinStatus.alert,
      pinLabel: r'$45k',
      badgeText: r'$45.000',
      normalizedX: 0.72,
      normalizedY: 0.55,
      latitude: 10.4452,
      longitude: -73.2468,
      address: 'Terminal de Transportes de Valledupar',
      sourceType: 'price_report',
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_05',
      name: '[DEMO] Taxi urbano · Carrera diurna',
      description:
          r'Muestra DEMO — Variación moderada (+25%) frente a referencia de $12.000 COP',
      category: PriceMapCategory.prices,
      pinKind: PriceMapPinKind.transport,
      status: PricePinStatus.moderate,
      pinLabel: r'$15k',
      badgeText: r'$15.000',
      normalizedX: 0.64,
      normalizedY: 0.28,
      latitude: 10.4885,
      longitude: -73.2535,
      address: 'Sector Novalito · Zona Norte',
      sourceType: 'price_report',
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_06',
      name: '[DEMO] Enlace de Orientación Migratoria y Consular',
      description:
          'Muestra DEMO — Información de trámites, consulados y rutas de atención',
      category: PriceMapCategory.consulates,
      pinKind: PriceMapPinKind.consulate,
      status: PricePinStatus.info,
      pinLabel: '',
      badgeText: '1.9 km',
      normalizedX: 0.22,
      normalizedY: 0.56,
      latitude: 10.4752,
      longitude: -73.2452,
      phone: '6055801122',
      address: 'Calle 15 #11-45 · Sector Centro',
      sourceType: 'business',
      municipalityCode: '20001',
      isDemo: true,
    ),
  ];

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    return _sampleItems
        .where((item) => item.municipalityCode == municipalityCode)
        .toList();
  }
}
