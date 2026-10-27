import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Implementación local de demostración del repositorio de negocios para Valledupar.
/// NOTA: Datos de muestra provisionales para el piloto; no representan comercios verificados reales aún.
class LocalBusinessRepository implements BusinessRepository {
  const LocalBusinessRepository();

  static const _sampleBusinesses = <Business>[
    Business(
      id: 'biz_01',
      name: '[DEMO] Restaurante El Pilón Vallenato',
      category: BusinessCategory.food,
      address: 'Muestra DEMO — Sector Centro, Valledupar',
      phone: '000-000-0000 (DEMO)',
      municipalityCode: '20001',
      isVerified: false,
      description:
          'Dato de muestra: comida típica cesarense, chivo asado y sancocho de gallina criolla.',
    ),
    Business(
      id: 'biz_02',
      name: '[DEMO] Cooperativa Taxis Cacique Upar',
      category: BusinessCategory.transport,
      address: 'Muestra DEMO — Sector Terminal, Valledupar',
      phone: '000-000-0000 (DEMO)',
      municipalityCode: '20001',
      isVerified: false,
      description:
          'Dato de muestra: servicio de taxi urbano con tarifas estandarizadas según decreto municipal.',
    ),
    Business(
      id: 'biz_03',
      name: '[DEMO] Hotel Boutique Los Ángeles',
      category: BusinessCategory.lodging,
      address: 'Muestra DEMO — Sector Plaza Alfonso López, Valledupar',
      phone: '000-000-0000 (DEMO)',
      municipalityCode: '20001',
      isVerified: false,
      description:
          'Dato de muestra: hospedaje de referencia cerca de la Plaza Alfonso López.',
    ),
    Business(
      id: 'biz_04',
      name: '[DEMO] Asesorías Jurídicas & Trámites del Cesar',
      category: BusinessCategory.services,
      address: 'Muestra DEMO — Sector Notarías, Valledupar',
      phone: '000-000-0000 (DEMO)',
      municipalityCode: '20001',
      isVerified: false,
      description:
          'Dato de muestra: orientación preventiva sobre contratos de arrendamiento y trámites.',
    ),
    Business(
      id: 'biz_05',
      name: '[DEMO] Café & Panadería La Guatapurí',
      category: BusinessCategory.food,
      address: 'Muestra DEMO — Sector Balneario Hurtado, Valledupar',
      phone: '000-000-0000 (DEMO)',
      municipalityCode: '20001',
      isVerified: false,
      description:
          'Dato de muestra: café regional y desayunos con precios de referencia.',
    ),
    Business(
      id: 'biz_06',
      name: '[DEMO] Transportes Fluvial y Terrestre del Cesar',
      category: BusinessCategory.transport,
      address: 'Muestra DEMO — Sector Salguero, Valledupar',
      phone: '000-000-0000 (DEMO)',
      municipalityCode: '20001',
      isVerified: false,
      description:
          'Dato de muestra: rutas intermunicipales hacia La Paz, Manaure, San Diego y Aguachica.',
    ),
  ];

  @override
  Future<List<Business>> getBusinesses() async {
    return _sampleBusinesses;
  }
}
