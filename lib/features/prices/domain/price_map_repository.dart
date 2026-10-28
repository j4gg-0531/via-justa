import 'package:via_justa/features/prices/domain/price_map_item.dart';

/// Interfaz abstracta para consultar los marcadores de precios y servicios del municipio.
abstract class PriceMapRepository {
  /// Obtiene los marcadores locales registrados para un código DIVIPOLA de municipio.
  Future<List<PriceMapItem>> getMapItems({String municipalityCode = '20001'});
}
