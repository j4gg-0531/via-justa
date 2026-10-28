import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';

/// Repositorio local de demostración para el mapa de precios y servicios del municipio piloto (M08).
/// NOTA: Datos de ejemplo rotulados; no representan reportes ni servicios verificados en tiempo real.
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
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_03',
      name: '[DEMO] Almuerzo corriente · Centro',
      description:
          'Muestra DEMO — Precio dentro de la mediana de referencia (\$12.000 COP)',
      category: PriceMapCategory.prices,
      pinKind: PriceMapPinKind.food,
      status: PricePinStatus.fair,
      pinLabel: r'$12k',
      badgeText: r'$12.000',
      normalizedX: 0.24,
      normalizedY: 0.34,
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_04',
      name: '[DEMO] Taxi Terminal – Centro',
      description:
          'Muestra DEMO — Reporte por encima de la mediana de referencia (\$12.000 COP)',
      category: PriceMapCategory.prices,
      pinKind: PriceMapPinKind.transport,
      status: PricePinStatus.alert,
      pinLabel: r'$45k',
      badgeText: r'$45.000',
      normalizedX: 0.72,
      normalizedY: 0.55,
      municipalityCode: '20001',
      isDemo: true,
    ),
    PriceMapItem(
      id: 'map_item_05',
      name: '[DEMO] Taxi urbano · Carrera diurna',
      description:
          'Muestra DEMO — Variación moderada (+25%) frente a referencia de \$12.000 COP',
      category: PriceMapCategory.prices,
      pinKind: PriceMapPinKind.transport,
      status: PricePinStatus.moderate,
      pinLabel: r'$15k',
      badgeText: r'$15.000',
      normalizedX: 0.64,
      normalizedY: 0.28,
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
      municipalityCode: '20001',
      isDemo: true,
    ),
  ];

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    return _sampleItems;
  }
}
