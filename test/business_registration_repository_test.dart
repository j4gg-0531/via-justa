import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/businesses/data/supabase_business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseBusinessRegistrationRepository repository;
  late List<({String method, String path, String body})> requests;
  var published = false;
  String? error;
  setUp(() async {
    requests = [];
    published = false;
    error = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add((
        method: request.method,
        path: request.uri.path,
        body: body,
      ));
      request.response.headers.contentType = ContentType.json;
      if (error != null) {
        request.response.statusCode = 400;
        request.response.write(
          jsonEncode({
            'message': '[$error]',
            'code': 'P0001',
            'details': null,
            'hint': null,
          }),
        );
      } else if (request.uri.path.endsWith('submit_business')) {
        request.response.write(
          jsonEncode({
            'id': 'business-id',
            'status': published ? 'approved' : 'pending',
          }),
        );
      } else if (request.uri.path.contains('/storage/')) {
        request.response.write(
          jsonEncode({'Key': 'business-media/owner/business-id/photo_0.png'}),
        );
      } else {
        request.response.write('{}');
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'local-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'local-test-token',
        'token_type': 'bearer',
        'user': {
          'id': 'owner',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    repository = SupabaseBusinessRegistrationRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  const draft = BusinessDraft(
    fields: {
      BusinessField.name: ' Cocina ',
      BusinessField.whatsapp: '+57 3001234567',
      BusinessField.orderUrl: 'https://vinapp.co/menu',
    },
    dishes: [BusinessDishDraft(name: 'Almuerzo', price: '15000')],
  );
  Future<String> publish(BusinessDraft value, {String owner = 'owner'}) =>
      repository.publish(
        draft: value,
        requestId: 'same-request',
        ownerId: owner,
        municipalityCode: '20001',
      );
  test('serializa contrato y finaliza después de enlazar fotos', () async {
    final result = await publish(
      draft.copyWith(
        photos: [
          BusinessPhoto(
            bytes: Uint8List.fromList('test-image'.codeUnits),
            extension: 'png',
            mimeType: 'image/png',
          ),
        ],
      ),
    );
    expect(result, 'business-id');
    expect(requests.map((r) => r.path), [
      '/rest/v1/rpc/submit_business',
      '/storage/v1/object/business-media/owner/business-id/photo_0.png',
      '/rest/v1/business_photos',
      '/rest/v1/rpc/publish_business',
    ]);
    final payload = jsonDecode(requests.first.body) as Map;
    expect(payload['p_name'], 'Cocina');
    expect(payload['p_whatsapp'], '573001234567');
    expect(payload['p_dishes'], [
      {'name': 'Almuerzo', 'price_cop': 15000},
    ]);
    expect(payload['p_order_url'], 'https://vinapp.co/menu');
    expect(jsonDecode(requests.last.body), {
      'p_business_id': 'business-id',
      'p_expected_photo_count': 1,
    });
  });
  test('reintento ya publicado no vuelve a subir ni publicar', () async {
    published = true;
    expect(await publish(draft), 'business-id');
    expect(requests.length, 1);
  });
  test('sesión diferente no realiza solicitudes', () async {
    await expectLater(
      publish(draft, owner: 'another-user'),
      throwsA(
        isA<BusinessRegistrationFailure>().having(
          (e) => e.key,
          'key',
          'session',
        ),
      ),
    );
    expect(requests, isEmpty);
  });
  test('errores del contrato se convierten a claves de interfaz', () async {
    error = 'BUSINESS_DUPLICATE';
    await expectLater(
      publish(draft),
      throwsA(
        isA<BusinessRegistrationFailure>().having(
          (e) => e.key,
          'key',
          'duplicate',
        ),
      ),
    );
    expect(requests.length, 1);
  });
}
