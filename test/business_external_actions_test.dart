import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_external_actions.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

class FakeBusinessExternalLauncher implements BusinessExternalLauncher {
  final launchedUris = <Uri>[];
  bool shouldSucceed = true;

  @override
  Future<bool> launchExternalUri(Uri uri) async {
    launchedUris.add(uri);
    return shouldSucceed;
  }
}

BusinessDetail _detail({
  bool canOrder = true,
  String? orderUrl = 'https://vinapp.co/cocina-del-patio',
  bool canWhatsapp = true,
  String? whatsapp = '573001234567',
  String? whatsappUrl,
  bool canDirections = true,
  double? latitude = 10.4742,
  double? longitude = -73.2436,
  String? mapsUrl,
}) {
  return BusinessDetail(
    id: 'biz-1',
    name: 'Cocina del Patio',
    type: 'restaurant',
    category: BusinessCategory.food,
    municipalityCode: '20001',
    description: 'Almuerzos y comida casera.',
    address: 'Sector Centro, Valledupar',
    latitude: latitude,
    longitude: longitude,
    whatsapp: whatsapp,
    orderUrl: orderUrl,
    whatsappUrl: whatsappUrl,
    mapsUrl: mapsUrl,
    canOrderExternal: canOrder,
    canWhatsapp: canWhatsapp,
    canDirections: canDirections,
  );
}

void main() {
  group('resolveBusinessOrderUri', () {
    test('accepts valid HTTPS merchant order URL and rejects insecure or disabled links', () {
      final valid = resolveBusinessOrderUri(_detail());
      expect(valid?.toString(), 'https://vinapp.co/cocina-del-patio');

      expect(resolveBusinessOrderUri(_detail(canOrder: false)), isNull);
      expect(
        resolveBusinessOrderUri(_detail(orderUrl: 'http://insecure.co/menu')),
        isNull,
      );
      expect(resolveBusinessOrderUri(_detail(orderUrl: '')), isNull);
    });
  });

  group('resolveBusinessWhatsappUri & suggestedBusinessWhatsappMessage', () {
    test('builds wa.me link with localized suggested message in es and en', () {
      final esUri = resolveBusinessWhatsappUri(
        _detail(whatsappUrl: 'https://wa.me/573001234567'),
        localeCode: 'es',
      );
      expect(esUri, isNotNull);
      expect(esUri!.host, 'wa.me');
      expect(esUri.path, '/573001234567');
      expect(
        esUri.queryParameters['text'],
        'Hola Cocina del Patio, vi tu ficha en Vía Justa y quisiera más información.',
      );

      final enUri = resolveBusinessWhatsappUri(
        _detail(whatsappUrl: null, whatsapp: '+57 300 123 4567'),
        localeCode: 'en',
      );
      expect(enUri, isNotNull);
      expect(enUri!.path, '/573001234567');
      expect(
        enUri.queryParameters['text'],
        'Hello Cocina del Patio, I saw your listing on Vía Justa and would like more information.',
      );

      expect(resolveBusinessWhatsappUri(_detail(canWhatsapp: false)), isNull);
      expect(
        resolveBusinessWhatsappUri(_detail(whatsappUrl: null, whatsapp: '123')),
        isNull,
      );
    });
  });

  group('resolveBusinessDirectionsUri', () {
    test('builds Google Maps directions URL from prebuilt URL or coordinates', () {
      final fromCoords = resolveBusinessDirectionsUri(_detail());
      expect(
        fromCoords?.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=10.474200,-73.243600',
      );

      final fromPrebuilt = resolveBusinessDirectionsUri(
        _detail(
          mapsUrl:
              'https://www.google.com/maps/dir/?api=1&destination=10.474200,-73.243600&destination_place_id=ChIJ_Valledupar001',
        ),
      );
      expect(
        fromPrebuilt?.queryParameters['destination_place_id'],
        'ChIJ_Valledupar001',
      );

      expect(
        resolveBusinessDirectionsUri(_detail(canDirections: false)),
        isNull,
      );
      expect(
        resolveBusinessDirectionsUri(_detail(latitude: null, longitude: null)),
        isNull,
      );
    });
  });

  group('resolveBusinessCardContactUri & BusinessExternalActionNotifier', () {
    test('launches order, WhatsApp, directions and directory card contact via provider', () async {
      final launcher = FakeBusinessExternalLauncher();
      final container = ProviderContainer(
        overrides: [
          businessExternalLauncherProvider.overrideWithValue(launcher),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(businessExternalActionProvider.notifier);
      final detail = _detail();

      expect(await notifier.openOrder(detail), isTrue);
      expect(await notifier.openWhatsapp(detail, localeCode: 'es'), isTrue);
      expect(await notifier.openDirections(detail), isTrue);

      const cardBusiness = Business(
        id: 'biz-card',
        name: 'Taxis del Valle',
        category: BusinessCategory.transport,
        address: 'Sector Terminal',
        phone: '6055710000',
        municipalityCode: '20001',
      );
      expect(await notifier.openCardContact(cardBusiness), isTrue);

      expect(launcher.launchedUris.length, 4);
      expect(
        launcher.launchedUris[0].toString(),
        'https://vinapp.co/cocina-del-patio',
      );
      expect(launcher.launchedUris[1].host, 'wa.me');
      expect(launcher.launchedUris[2].host, 'www.google.com');
      expect(launcher.launchedUris[3].toString(), 'tel:6055710000');
    });
  });
}
