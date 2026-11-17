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
  bool failUpdateRpc = false;
  bool dropUpdateResponse = false;
  bool commitUpdateBeforeDrop = true;
  bool failReconcile = false;
  Map<String, String> editAttemptStatuses = <String, String>{};
  List<String> referencedPhotosInDb = const ['owner/existing-id/old_photo.png'];
  List<String> removedPathsOnEdit = const ['owner/existing-id/old_photo.png'];

  setUp(() async {
    requests = [];
    published = false;
    error = null;
    failUpdateRpc = false;
    dropUpdateResponse = false;
    commitUpdateBeforeDrop = true;
    failReconcile = false;
    editAttemptStatuses = <String, String>{};
    referencedPhotosInDb = const ['owner/existing-id/old_photo.png'];
    removedPathsOnEdit = const ['owner/existing-id/old_photo.png'];
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
      } else if (request.uri.path.endsWith('update_own_business')) {
        final payload = jsonDecode(body) as Map<String, dynamic>;
        final editId = (payload['p_edit_request_id'] as String?) ?? '';
        if (editId.isNotEmpty && editAttemptStatuses[editId] == 'aborted') {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({
              'message': '[BUSINESS_EDIT_ABORTED]',
              'code': '40001',
              'details': null,
              'hint': null,
            }),
          );
        } else if (failUpdateRpc) {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({
              'message': '[BUSINESS_INVALID_DISH]',
              'code': '22023',
              'details': null,
              'hint': null,
            }),
          );
        } else {
          final photos = (payload['p_photos'] as List?) ?? const [];
          if (!dropUpdateResponse || commitUpdateBeforeDrop) {
            if (editId.isNotEmpty) {
              editAttemptStatuses[editId] = 'committed';
            }
            referencedPhotosInDb = [
              for (final item in photos.whereType<Map>())
                if (item['storage_path'] != null)
                  item['storage_path'].toString(),
            ];
          }
          if (dropUpdateResponse) {
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.destroy();
            return;
          }
          request.response.write(
            jsonEncode({
              'id': 'existing-id',
              'status': 'approved',
              'edit_status': 'committed',
              'removed_photo_paths': removedPathsOnEdit,
            }),
          );
        }
      } else if (request.uri.path.endsWith('reconcile_business_edit_attempt')) {
        if (failReconcile) {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
          return;
        }
        final payload = jsonDecode(body) as Map<String, dynamic>;
        final editId = (payload['p_edit_request_id'] as String?) ?? '';
        final candidates = [
          for (final item in (payload['p_candidate_photo_paths'] as List?) ?? const [])
            if (item != null) item.toString(),
        ];
        if (editAttemptStatuses[editId] == 'committed') {
          request.response.write(
            jsonEncode({
              'business_id': 'existing-id',
              'edit_request_id': editId,
              'edit_status': 'committed',
              'removed_photo_paths': removedPathsOnEdit,
              'deletable_photo_paths': const <String>[],
            }),
          );
        } else {
          editAttemptStatuses[editId] = 'aborted';
          final deletable = [
            for (final c in candidates)
              if (!referencedPhotosInDb.contains(c)) c,
          ];
          request.response.write(
            jsonEncode({
              'business_id': 'existing-id',
              'edit_request_id': editId,
              'edit_status': 'aborted',
              'removed_photo_paths': const <String>[],
              'deletable_photo_paths': deletable,
            }),
          );
        }
      } else if (request.uri.path.endsWith('submit_business')) {
        request.response.write(
          jsonEncode({
            'id': 'business-id',
            'status': published ? 'approved' : 'pending',
          }),
        );
      } else if (request.uri.path.contains('/storage/v1/object/list/')) {
        request.response.write(
          jsonEncode([
            {
              'name': 'photo_0.png',
              'id': 'file-1',
              'updated_at': '2026-01-01T00:00:00Z',
              'created_at': '2026-01-01T00:00:00Z',
              'last_accessed_at': '2026-01-01T00:00:00Z',
              'metadata': <String, dynamic>{},
            },
          ]),
        );
      } else if (request.uri.path.contains('/storage/') &&
          request.method == 'DELETE') {
        request.response.write('[]');
      } else if (request.uri.path.contains('/storage/')) {
        request.response.write(
          jsonEncode({'Key': 'business-media/owner/business-id/photo_0.png'}),
        );
      } else {
        request.response.write('[]');
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
    latitude: 10.47,
    longitude: -73.24,
    whatsappConsent: true,
    dishes: [BusinessDishDraft(name: 'Almuerzo', price: '15000')],
  );
  Future<String> publish(
    BusinessDraft value, {
    String owner = 'owner',
    String? businessId,
  }) => repository.publish(
    draft: value,
    requestId: 'same-request',
    ownerId: owner,
    municipalityCode: '20001',
    businessId: businessId,
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
  test(
    'editar negocio sube nuevas fotos primero, llama RPC transaccional y limpia fotos viejas después',
    () async {
      final result = await publish(
        draft.copyWith(
          photos: [
            BusinessPhoto(
              bytes: Uint8List.fromList('kept'.codeUnits),
              extension: 'png',
              mimeType: 'image/png',
              storagePath: 'owner/existing-id/kept_0.png',
            ),
            BusinessPhoto(
              bytes: Uint8List.fromList('new-img'.codeUnits),
              extension: 'png',
              mimeType: 'image/png',
            ),
          ],
        ),
        businessId: 'existing-id',
      );
      expect(result, 'existing-id');
      expect(requests.map((r) => '${r.method} ${r.path}').toList(), [
        predicate<String>(
          (s) => s.startsWith(
            'POST /storage/v1/object/business-media/owner/existing-id/edit_samerequest_',
          ),
        ),
        'POST /rest/v1/rpc/update_own_business',
        'DELETE /storage/v1/object/business-media',
      ]);

      final rpcPayload = jsonDecode(requests[1].body) as Map<String, dynamic>;
      final rpcPhotos = (rpcPayload['p_photos'] as List).cast<Map>();
      expect(rpcPhotos[0], {
        'storage_path': 'owner/existing-id/kept_0.png',
        'position': 0,
        'is_cover': true,
      });
      expect(
        rpcPhotos[1]['storage_path'],
        startsWith('owner/existing-id/edit_samerequest_'),
      );
      expect(rpcPhotos[1]['position'], 1);
      expect(rpcPhotos[1]['is_cover'], false);
      final cleanupPayload =
          jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(cleanupPayload['prefixes'], ['owner/existing-id/old_photo.png']);
    },
  );
  test(
    'si la RPC transaccional de edición falla, reconcilia en servidor y limpia únicamente las fotos nuevas autorizadas tras abortar',
    () async {
      failUpdateRpc = true;
      await expectLater(
        publish(
          draft.copyWith(
            photos: [
              BusinessPhoto(
                bytes: Uint8List.fromList('new-img'.codeUnits),
                extension: 'png',
                mimeType: 'image/png',
              ),
            ],
          ),
          businessId: 'existing-id',
        ),
        throwsA(isA<BusinessRegistrationFailure>()),
      );

      expect(requests.map((r) => '${r.method} ${r.path}').toList(), [
        predicate<String>(
          (s) => s.startsWith(
            'POST /storage/v1/object/business-media/owner/existing-id/edit_samerequest_',
          ),
        ),
        'POST /rest/v1/rpc/update_own_business',
        'POST /rest/v1/rpc/reconcile_business_edit_attempt',
        'DELETE /storage/v1/object/business-media',
      ]);
      final uploadedPath = requests.first.path.replaceFirst(
        '/storage/v1/object/business-media/',
        '',
      );
      final rollbackCleanup =
          jsonDecode(requests[3].body) as Map<String, dynamic>;
      expect(rollbackCleanup['prefixes'], [uploadedPath]);
    },
  );
  test(
    'guardado exitoso con respuesta perdida reconcilia committed en servidor, conserva fotos nuevas y limpia desplazadas',
    () async {
      dropUpdateResponse = true;
      commitUpdateBeforeDrop = true;
      final result = await publish(
        draft.copyWith(
          photos: [
            BusinessPhoto(
              bytes: Uint8List.fromList('new-img'.codeUnits),
              extension: 'png',
              mimeType: 'image/png',
            ),
          ],
        ),
        businessId: 'existing-id',
      );

      expect(result, 'existing-id');
      expect(requests.map((r) => '${r.method} ${r.path}').toList(), [
        predicate<String>(
          (s) => s.startsWith(
            'POST /storage/v1/object/business-media/owner/existing-id/edit_samerequest_',
          ),
        ),
        'POST /rest/v1/rpc/update_own_business',
        'POST /rest/v1/rpc/reconcile_business_edit_attempt',
        'DELETE /storage/v1/object/business-media',
      ]);
      final cleanupPayload =
          jsonDecode(requests[3].body) as Map<String, dynamic>;
      expect(cleanupPayload['prefixes'], ['owner/existing-id/old_photo.png']);
    },
  );
  test(
    'si la reconciliación tras corte es incierta, conserva fotos y al reintentar reconcilia committed sin duplicar',
    () async {
      dropUpdateResponse = true;
      commitUpdateBeforeDrop = true;
      failReconcile = true;
      final editedDraft = draft.copyWith(
        photos: [
          BusinessPhoto(
            bytes: Uint8List.fromList('new-img'.codeUnits),
            extension: 'png',
            mimeType: 'image/png',
          ),
        ],
      );
      await expectLater(
        publish(editedDraft, businessId: 'existing-id'),
        throwsA(anything),
      );
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);

      requests.clear();
      failReconcile = false;
      final retryResult = await publish(editedDraft, businessId: 'existing-id');
      expect(retryResult, 'existing-id');
      expect(requests.map((r) => '${r.method} ${r.path}').toList(), [
        'POST /rest/v1/rpc/reconcile_business_edit_attempt',
        'DELETE /storage/v1/object/business-media',
      ]);
      final cleanupPayload =
          jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(cleanupPayload['prefixes'], ['owner/existing-id/old_photo.png']);
    },
  );
  test(
    'si la reconciliación tras corte es incierta y el intento previo no confirmó, el reintento aborta y limpia el huérfano antes de subir de nuevo',
    () async {
      dropUpdateResponse = true;
      commitUpdateBeforeDrop = false;
      failReconcile = true;
      final editedDraft = draft.copyWith(
        photos: [
          BusinessPhoto(
            bytes: Uint8List.fromList('new-img'.codeUnits),
            extension: 'png',
            mimeType: 'image/png',
          ),
        ],
      );
      await expectLater(
        publish(editedDraft, businessId: 'existing-id'),
        throwsA(anything),
      );
      final orphanPath = requests.first.path.replaceFirst(
        '/storage/v1/object/business-media/',
        '',
      );
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);

      requests.clear();
      dropUpdateResponse = false;
      failReconcile = false;
      final retryResult = await publish(editedDraft, businessId: 'existing-id');
      expect(retryResult, 'existing-id');
      expect(requests.map((r) => '${r.method} ${r.path}').toList(), [
        'POST /rest/v1/rpc/reconcile_business_edit_attempt',
        'DELETE /storage/v1/object/business-media',
        predicate<String>(
          (s) => s.startsWith(
            'POST /storage/v1/object/business-media/owner/existing-id/edit_samerequest_',
          ),
        ),
        'POST /rest/v1/rpc/update_own_business',
        'DELETE /storage/v1/object/business-media',
      ]);
      final orphanCleanup =
          jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(orphanCleanup['prefixes'], [orphanPath]);
    },
  );
  test('retirar negocio limpia archivos de Storage y elimina fila', () async {
    await repository.withdraw(businessId: 'existing-id', ownerId: 'owner');
    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'POST /storage/v1/object/list/business-media',
      'DELETE /storage/v1/object/business-media',
      'DELETE /rest/v1/businesses',
    ]);
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
