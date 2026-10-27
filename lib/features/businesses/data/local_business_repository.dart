import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Implementación local de demostración del repositorio de negocios para Valledupar.
/// NOTA: Datos de muestra provisionales para el piloto; no representan comercios verificados reales aún.
class LocalBusinessRepository implements BusinessRepository {
  const LocalBusinessRepository();

  static const _sampleBusinesses = <Business>[
    Business(
      id: 'biz_01',
      name: 'Restaurante El Pilón Vallenato',
      category: BusinessCategory.food,
      address: 'Cra 7 # 14-20, Centro Histórico',
      phone: '+57 300 123 4567',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Comida típica cesarense, chivo asado y sancocho de gallina criolla.',
    ),
    Business(
      id: 'biz_02',
      name: 'Cooperativa Taxis Cacique Upar',
      category: BusinessCategory.transport,
      address: 'Av. Salguero # 21-40',
      phone: '+57 315 987 6543',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Servicio de taxi urbano con tarifas estandarizadas según decreto municipal.',
    ),
    Business(
      id: 'biz_03',
      name: 'Hotel Boutique Los Ángeles',
      category: BusinessCategory.lodging,
      address: 'Calle 15 # 8-32, Alfonso López',
      phone: '+57 310 555 7890',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Hospedaje seguro cerca de la Plaza Alfonso López con tarifa fija en temporada.',
    ),
    Business(
      id: 'biz_04',
      name: 'Asesorías Jurídicas & Trámites del Cesar',
      category: BusinessCategory.services,
      address: 'Cra 9 # 12-45, Of. 204',
      phone: '+57 320 444 1122',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Revisión preventiva de contratos de arrendamiento y trámites notariales.',
    ),
    Business(
      id: 'biz_05',
      name: 'Café & Panadería La Guatapurí',
      category: BusinessCategory.food,
      address: 'Av. Hurtado, frente al Balneario',
      phone: '+57 301 777 8899',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Café de la Sierra Nevada y desayunos con precios a la vista.',
    ),
    Business(
      id: 'biz_06',
      name: 'Transportes Fluvial y Terrestre del Cesar',
      category: BusinessCategory.transport,
      address: 'Terminal de Transportes, Taquilla 12',
      phone: '+57 318 666 3322',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Rutas intermunicipales hacia La Paz, Manaure, San Diego y Aguachica.',
    ),
  ];

  @override
  Future<List<Business>> getBusinesses() async {
    return _sampleBusinesses;
  }
}
