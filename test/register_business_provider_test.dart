import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/auth/presentation/state/auth_state.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_registration_repository.dart';
import 'package:via_justa/features/businesses/presentation/state/register_business_provider.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

class TestBusinessAuth extends AuthController {
  @override
  AuthState build() => const AuthState(session: AuthSession(userId: 'owner'));
  void clear() => state = const AuthState();
}

class FakeRegistrationRepository implements BusinessRegistrationRepository {
  final requests = <String>[];
  bool fail = false;
  bool cleanupFail = false;
  String? discardedPublishedId;
  Completer<String>? pending;
  @override
  Future<String> publish({
    required BusinessDraft draft,
    required String requestId,
    required String ownerId,
    required String municipalityCode,
  }) async {
    requests.add(requestId);
    if (fail) throw const BusinessRegistrationFailure('network');
    return pending == null ? 'business-id' : pending!.future;
  }

  @override
  Future<String?> discard({
    required String requestId,
    required String ownerId,
  }) async {
    if (cleanupFail) throw Exception('offline');
    return discardedPublishedId;
  }
}

class _FakePhotos implements BusinessPhotoRepository {
  BusinessPhoto? photo;
  bool fail = false;
  @override
  Future<BusinessPhoto?> pickPhoto() async {
    if (fail) throw const BusinessRegistrationFailure('photoInvalid');
    return photo;
  }
}

const registrationZone = MunicipalityZone(
  id: 'center',
  municipalityCode: '20001',
  nameEs: 'Centro',
  nameEn: 'Center',
  sectorHintEs: '',
  sectorHintEn: '',
);

ProviderContainer registrationContainer(FakeRegistrationRepository repository) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(TestBusinessAuth.new),
      businessRegistrationRepositoryProvider.overrideWithValue(repository),
      municipalityZonesProvider.overrideWith((ref) async => [registrationZone]),
    ],
  );
  container
      .read(selectedMunicipalityProvider.notifier)
      .select(
        const Municipality(
          code: '20001',
          name: 'Valledupar',
          departmentCode: '20',
          isPilot: true,
        ),
      );
  return container;
}

void fillRegistration(RegisterBusinessNotifier notifier) {
  notifier.setField(BusinessField.name, 'Cocina del patio');
  notifier.setField(
    BusinessField.descriptionEs,
    'Comida tradicional preparada cada día.',
  );
  notifier.setField(BusinessField.address, 'Calle 10 número 20');
  notifier.setField(BusinessField.whatsapp, '+57 3001234567');
  notifier.setWhatsappConsent(true);
  notifier.selectPoint(
    const PickedMapPoint(
      zoneId: 'center',
      latitude: 10.47,
      longitude: -73.24,
      normalizedX: .5,
      normalizedY: .5,
    ),
    'es',
  );
  notifier.setPublicationConsent(true);
}

void main() {
  late FakeRegistrationRepository repository;
  late ProviderContainer container;
  late RegisterBusinessNotifier notifier;
  setUp(() async {
    repository = FakeRegistrationRepository();
    container = registrationContainer(repository);
    container.listen(registerBusinessProvider, (_, _) {});
    await container.read(municipalityZonesProvider.future);
    notifier = container.read(registerBusinessProvider.notifier);
  });
  tearDown(() => container.dispose());
  test('impide avanzar y publicar datos incompletos', () async {
    notifier.next();
    expect(container.read(registerBusinessProvider).error, 'name');
    await notifier.submit();
    expect(repository.requests, isEmpty);
  });
  test('reintento conserva id y borrador hasta publicar', () async {
    fillRegistration(notifier);
    repository.fail = true;
    await notifier.submit();
    notifier.setField(BusinessField.name, 'Cambio bloqueado');
    expect(
      container.read(registerBusinessProvider).draft.text(BusinessField.name),
      'Cocina del patio',
    );
    expect(container.read(registerBusinessProvider).locked, isTrue);
    repository.fail = false;
    await notifier.submit();
    expect(repository.requests[0], repository.requests[1]);
    expect(container.read(registerBusinessProvider).publishedId, 'business-id');
  });
  test(
    'cancelación fallida conserva bloqueo; limpieza permite nueva solicitud',
    () async {
      fillRegistration(notifier);
      repository.fail = true;
      await notifier.submit();
      repository.cleanupFail = true;
      await notifier.discard();
      expect(container.read(registerBusinessProvider).error, 'cleanup');
      expect(container.read(registerBusinessProvider).locked, isTrue);
      repository.cleanupFail = false;
      await notifier.discard();
      await notifier.submit();
      expect(repository.requests[0], isNot(repository.requests[1]));
    },
  );
  test(
    'respuesta perdida reconoce negocio ya publicado al descartar',
    () async {
      fillRegistration(notifier);
      repository.fail = true;
      await notifier.submit();
      repository.discardedPublishedId = 'already-published';
      await notifier.discard();
      expect(
        container.read(registerBusinessProvider).publishedId,
        'already-published',
      );
    },
  );
  test('doble envío y respuesta posterior al cierre de sesión', () async {
    fillRegistration(notifier);
    repository.pending = Completer<String>();
    final first = notifier.submit();
    await notifier.submit();
    expect(repository.requests.length, 1);
    (container.read(authControllerProvider.notifier) as TestBusinessAuth)
        .clear();
    expect(container.read(registerBusinessProvider).available, isFalse);
    repository.pending!.complete('late-business');
    await first;
    expect(container.read(registerBusinessProvider).publishedId, isNull);
  });
  test('cambiar WhatsApp exige renovar consentimiento y limita platos', () {
    fillRegistration(notifier);
    notifier.setField(BusinessField.whatsapp, '573009999999');
    expect(
      container.read(registerBusinessProvider).draft.whatsappConsent,
      isFalse,
    );
    for (var i = 0; i < 6; i++) {
      notifier.addDish();
    }
    expect(container.read(registerBusinessProvider).draft.dishes.length, 5);
  });
  test('galería cancelada, inválida y límite de cinco fotos', () async {
    final photos = _FakePhotos();
    final photoContainer = ProviderContainer(
      overrides: [businessPhotoRepositoryProvider.overrideWithValue(photos)],
    );
    addTearDown(photoContainer.dispose);
    photoContainer.listen(registerBusinessProvider, (_, _) {});
    final controller = photoContainer.read(registerBusinessProvider.notifier);
    await controller.addPhoto();
    expect(photoContainer.read(registerBusinessProvider).draft.photos, isEmpty);
    photos.fail = true;
    await controller.addPhoto();
    expect(photoContainer.read(registerBusinessProvider).error, 'photoInvalid');
    photos.fail = false;
    photos.photo = BusinessPhoto(
      bytes: Uint8List(12),
      extension: 'png',
      mimeType: 'image/png',
    );
    for (var i = 0; i < 6; i++) {
      await controller.addPhoto();
    }
    expect(
      photoContainer.read(registerBusinessProvider).draft.photos.length,
      5,
    );
    expect(photoContainer.read(registerBusinessProvider).busy, isFalse);
    controller.removePhoto(0);
    expect(photoContainer.read(registerBusinessProvider).canAddPhoto, isTrue);
  });
}
