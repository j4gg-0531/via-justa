import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';

/// Repositorio local del mapa de precios del municipio piloto (M08 / VJ-12).
/// Los comercios de demostración se retiraron de la experiencia.
class LocalPriceMapRepository implements PriceMapRepository {
  const LocalPriceMapRepository();

  static const _sampleItems = <PriceMapItem>[
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
