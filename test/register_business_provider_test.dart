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
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

class TestBusinessAuth extends AuthController {
  @override
  AuthState build() => const AuthState(session: AuthSession(userId: 'owner'));
  void clear() => state = const AuthState();
}

class FakeRegistrationRepository implements BusinessRegistrationRepository {
  final requests = <String>[];
  final editedBusinessIds = <String?>[];
  final withdrawnBusinessIds = <String>[];
  bool fail = false;
  bool cleanupFail = false;
  String? discardedPublishedId;
  Completer<String>? pending;
  BusinessDraft loadedDraft = const BusinessDraft(
    fields: {
      BusinessField.name: 'Cocina del patio',
      BusinessField.descriptionEs: 'Comida tradicional preparada cada día.',
      BusinessField.address: 'Calle 10 número 20',
      BusinessField.whatsapp: '573001234567',
    },
    latitude: 10.47,
    longitude: -73.24,
    whatsappConsent: true,
    publicationConsent: true,
  );

  @override
  Future<String> publish({
    required BusinessDraft draft,
    required String requestId,
    required String ownerId,
    required String municipalityCode,
    String? businessId,
  }) async {
    requests.add(requestId);
    editedBusinessIds.add(businessId);
    if (fail) throw const BusinessRegistrationFailure('network');
    return pending == null ? (businessId ?? 'business-id') : pending!.future;
  }

  @override
  Future<BusinessDraft> loadForEdit({
    required String businessId,
    required String ownerId,
  }) async {
    if (fail) throw const BusinessRegistrationFailure('network');
    return loadedDraft;
  }

  @override
  Future<void> withdraw({
    required String businessId,
    required String ownerId,
  }) async {
    if (fail) throw const BusinessRegistrationFailure('network');
    withdrawnBusinessIds.add(businessId);
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
      municipalityZonesProvider.overrideWith(
        (ref) async => [registrationZone],
      ),
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
  test('dueño puede cargar, editar y retirar su negocio publicado', () async {
    await notifier.loadEdit('own-business-1', 'es');
    expect(container.read(registerBusinessProvider).isEditing, isTrue);
    expect(
      container.read(registerBusinessProvider).draft.text(BusinessField.name),
      'Cocina del patio',
    );
    notifier.setType(BusinessType.hotel);
    expect(
      container.read(registerBusinessProvider).draft.type,
      BusinessType.restaurant,
    );
    notifier.setField(BusinessField.name, 'Cocina del patio renovada');
    await notifier.submit();
    expect(repository.editedBusinessIds, ['own-business-1']);
    expect(
      container.read(registerBusinessProvider).publishedId,
      'own-business-1',
    );

    await notifier.withdraw();
    expect(repository.withdrawnBusinessIds, ['own-business-1']);
    expect(container.read(registerBusinessProvider).withdrawn, isTrue);
  });
  test(
    'comparar precio de plato por zona reutiliza semáforo y permite mantener el precio y publicar',
    () async {
      fillRegistration(notifier);
      await container.read(priceCategoriesProvider.future);
      notifier.addDish();
      notifier.setDish(
        0,
        name: 'Almuerzo ejecutivo',
        price: '20000',
        priceCategoryId: 'food_corrientazo',
      );
      await notifier.compareDishPrice(0);

      final state = container.read(registerBusinessProvider);
      final notice = state.dishPriceNoticeFor(state.draft.dishes.first)?.value;
      expect(notice, isNotNull);
      expect(notice!.categoryId, 'food_corrientazo');
      expect(notice.enteredCop, 20000);
      expect(notice.sampleCount, greaterThanOrEqualTo(3));
      expect(notice.medianCop, isNotNull);
      expect(notice.differenceCop, 20000 - notice.medianCop!);

      // El aviso es orientativo y permite mantener el precio y publicar
      await notifier.submit();
      expect(
        container.read(registerBusinessProvider).publishedId,
        'business-id',
      );
    },
  );
  test('galería cancelada, inválida y límite de cinco fotos', () async {
    final photos = _FakePhotos();
    final photoContainer = ProviderContainer(
      overrides: [businessPhotoRepositoryProvider.overrideWithValue(photos)],
    );
    addTearDown(photoContainer.dispose);
    photoContainer.listen(registerBusinessProvider, (_, _) {});
    final controller = photoContainer.read(registerBusinessProvider.notifier);
    await controller.addPhoto();
    expect(
      photoContainer.read(registerBusinessProvider).draft.photos,
      isEmpty,
    );
    photos.fail = true;
    await controller.addPhoto();
    expect(
      photoContainer.read(registerBusinessProvider).error,
      'photoInvalid',
    );
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

  test(
    'identidad estable de plato y secuencia descartan avisos obsoletos al cambiar precio, zona o eliminar platos',
    () async {
      final firstCompleter = Completer<PriceVerdict>();
      final secondCompleter = Completer<PriceVerdict>();
      final dishBCompleter = Completer<PriceVerdict>();
      final calls = <({int submittedCop, String zoneId})>[];
      var callIndex = 0;
      final fakeVerdicts = _ControllablePriceVerdictRepository(
        onEvaluate: (submittedCop, zoneId) {
          calls.add((submittedCop: submittedCop, zoneId: zoneId));
          final current = callIndex++;
          if (current == 0) return firstCompleter.future;
          if (current == 1) return secondCompleter.future;
          return dishBCompleter.future;
        },
      );
      final raceContainer = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(TestBusinessAuth.new),
          businessRegistrationRepositoryProvider.overrideWithValue(repository),
          priceVerdictRepositoryProvider.overrideWithValue(fakeVerdicts),
          municipalityZonesProvider.overrideWith(
            (ref) async => const [
              registrationZone,
              MunicipalityZone(
                id: 'north',
                municipalityCode: '20001',
                nameEs: 'Norte',
                nameEn: 'North',
                sectorHintEs: '',
                sectorHintEn: '',
                centerLat: 10.50,
                centerLng: -73.24,
              ),
            ],
          ),
          priceCategoriesProvider.overrideWith(
            (ref) async => const [
              PriceCategory(
                id: 'food_corrientazo',
                groupKey: 'food',
                nameEs: 'Almuerzo corriente',
                nameEn: 'Daily lunch',
                unitDescriptionEs: 'Por plato',
                unitDescriptionEn: 'Per meal',
              ),
            ],
          ),
        ],
      );
      addTearDown(raceContainer.dispose);
      raceContainer
          .read(selectedMunicipalityProvider.notifier)
          .select(
            const Municipality(
              code: '20001',
              name: 'Valledupar',
              departmentCode: '20',
              isPilot: true,
            ),
          );
      raceContainer.listen(registerBusinessProvider, (_, _) {});
      final n = raceContainer.read(registerBusinessProvider.notifier);
      await raceContainer.read(municipalityZonesProvider.future);
      await raceContainer.read(priceCategoriesProvider.future);
      fillRegistration(n);

      n.addDish();
      n.addDish();
      n.setDish(
        0,
        name: 'Plato A',
        price: '20000',
        priceCategoryId: 'food_corrientazo',
      );
      n.setDish(
        1,
        name: 'Plato B',
        price: '28000',
        priceCategoryId: 'food_corrientazo',
      );

      // Inicia comparación a $20.000 y antes de responder cambia el precio a $10.000.
      final firstFuture = n.compareDishPrice(0);
      await Future<void>.delayed(Duration.zero);
      n.setDish(0, price: '10000');

      final secondFuture = n.compareDishPrice(0);
      await Future<void>.delayed(Duration.zero);

      secondCompleter.complete(
        const PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'center',
          level: PriceVerdictLevel.green,
          submittedCop: 10000,
          n: 10,
          referenceCop: 12000,
          deviationPct: -16.7,
        ),
      );
      await secondFuture;

      firstCompleter.complete(
        const PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'center',
          level: PriceVerdictLevel.red,
          submittedCop: 20000,
          n: 10,
          referenceCop: 12000,
          deviationPct: 66.7,
        ),
      );
      await firstFuture;

      var s = raceContainer.read(registerBusinessProvider);
      expect(s.dishPriceNoticeFor(s.draft.dishes[0])?.value?.enteredCop, 10000);

      // Si cambia de zona mientras Plato B sigue pendiente, Plato B también se descarta.
      final thirdFuture = n.compareDishPrice(1);
      await Future<void>.delayed(Duration.zero);
      n.selectPoint(
        const PickedMapPoint(
          zoneId: 'north',
          latitude: 10.50,
          longitude: -73.24,
          normalizedX: .5,
          normalizedY: .2,
        ),
        'es',
      );
      dishBCompleter.complete(
        const PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'center',
          level: PriceVerdictLevel.red,
          submittedCop: 28000,
          n: 10,
          referenceCop: 12000,
          deviationPct: 133.3,
        ),
      );
      await thirdFuture;
      s = raceContainer.read(registerBusinessProvider);
      expect(s.dishPriceNoticeFor(s.draft.dishes[1]), isNull);
    },
  );

  test(
    'eliminar otro plato no mezcla ni descarta el aviso del plato conservado',
    () async {
      final completer = Completer<PriceVerdict>();
      final fakeVerdicts = _ControllablePriceVerdictRepository(
        onEvaluate: (_, _) => completer.future,
      );
      final deleteContainer = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(TestBusinessAuth.new),
          businessRegistrationRepositoryProvider.overrideWithValue(repository),
          priceVerdictRepositoryProvider.overrideWithValue(fakeVerdicts),
          municipalityZonesProvider.overrideWith(
            (ref) async => const [registrationZone],
          ),
          priceCategoriesProvider.overrideWith(
            (ref) async => const [
              PriceCategory(
                id: 'food_corrientazo',
                groupKey: 'food',
                nameEs: 'Almuerzo corriente',
                nameEn: 'Daily lunch',
                unitDescriptionEs: 'Por plato',
                unitDescriptionEn: 'Per meal',
              ),
            ],
          ),
        ],
      );
      addTearDown(deleteContainer.dispose);
      deleteContainer
          .read(selectedMunicipalityProvider.notifier)
          .select(
            const Municipality(
              code: '20001',
              name: 'Valledupar',
              departmentCode: '20',
              isPilot: true,
            ),
          );
      deleteContainer.listen(registerBusinessProvider, (_, _) {});
      final n = deleteContainer.read(registerBusinessProvider.notifier);
      await deleteContainer.read(municipalityZonesProvider.future);
      await deleteContainer.read(priceCategoriesProvider.future);
      fillRegistration(n);

      n.addDish();
      n.addDish();
      n.setDish(0, name: 'Descartable', price: '12000');
      n.setDish(1, name: 'Conservado', price: '24000');

      final bId = deleteContainer.read(registerBusinessProvider).draft.dishes[1].id;
      final pending = n.compareDishPriceById(bId);
      await Future<void>.delayed(Duration.zero);

      // Elimina el plato 0 mientras el plato 1 espera respuesta; su id sigue siendo estable.
      n.removeDish(0);
      completer.complete(
        const PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'center',
          level: PriceVerdictLevel.red,
          submittedCop: 24000,
          n: 12,
          referenceCop: 14000,
          deviationPct: 71.4,
        ),
      );
      await pending;

      final s = deleteContainer.read(registerBusinessProvider);
      expect(s.draft.dishes.length, 1);
      expect(s.draft.dishes.first.name, 'Conservado');
      expect(s.dishPriceNoticeFor(s.draft.dishes.first)?.value?.enteredCop, 24000);
    },
  );

  test(
    'loadEdit no asigna vup_centro provisional mientras cargan las zonas y resuelve la zona cercana real al completar',
    () async {
      final zonesCompleter = Completer<List<MunicipalityZone>>();
      final editRepo = FakeRegistrationRepository()
        ..loadedDraft = const BusinessDraft(
          fields: {
            BusinessField.name: 'Asadero Norte',
            BusinessField.descriptionEs: 'Comida tradicional en el norte.',
            BusinessField.address: 'Carrera 9 #1-10',
            BusinessField.whatsapp: '573001234567',
          },
          latitude: 10.51,
          longitude: -73.24,
          whatsappConsent: true,
          publicationConsent: true,
        );
      final editContainer = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(TestBusinessAuth.new),
          businessRegistrationRepositoryProvider.overrideWithValue(editRepo),
          municipalityZonesProvider.overrideWith(
            (ref) => zonesCompleter.future,
          ),
        ],
      );
      addTearDown(editContainer.dispose);
      editContainer
          .read(selectedMunicipalityProvider.notifier)
          .select(
            const Municipality(
              code: '20001',
              name: 'Valledupar',
              departmentCode: '20',
              isPilot: true,
            ),
          );
      editContainer.listen(registerBusinessProvider, (_, _) {});
      final n = editContainer.read(registerBusinessProvider.notifier);

      await n.loadEdit('own-north-1', 'es');
      expect(
        editContainer.read(registerBusinessProvider).draft.zoneId,
        isNull,
      );

      zonesCompleter.complete(const [
        MunicipalityZone(
          id: 'vup_centro',
          municipalityCode: '20001',
          nameEs: 'Centro',
          nameEn: 'Downtown',
          sectorHintEs: '',
          sectorHintEn: '',
          centerLat: 10.46,
          centerLng: -73.24,
        ),
        MunicipalityZone(
          id: 'vup_norte',
          municipalityCode: '20001',
          nameEs: 'Norte',
          nameEn: 'North',
          sectorHintEs: '',
          sectorHintEn: '',
          centerLat: 10.505,
          centerLng: -73.24,
        ),
      ]);
      await editContainer.read(municipalityZonesProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(
        editContainer.read(registerBusinessProvider).draft.zoneId,
        'vup_norte',
      );
      expect(editContainer.read(registerBusinessProvider).zoneName, 'Norte');
    },
  );

  test(
    'avanzar a Revisión compara automáticamente, muestra error si falla sin asumir precio justo, reintenta y deja publicar',
    () async {
      var shouldFail = true;
      final evaluatedPrices = <int>[];
      final verdictRepo = _ControllablePriceVerdictRepository(
        onEvaluate: (submittedCop, _) async {
          evaluatedPrices.add(submittedCop);
          if (shouldFail) throw Exception('network timeout');
          return PriceVerdict(
            categoryId: 'food_corrientazo',
            municipalityCode: '20001',
            zoneId: 'center',
            level: PriceVerdictLevel.red,
            submittedCop: submittedCop,
            n: 9,
            referenceCop: 14000,
            deviationPct: 78.6,
          );
        },
      );
      final reviewContainer = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(TestBusinessAuth.new),
          businessRegistrationRepositoryProvider.overrideWithValue(repository),
          priceVerdictRepositoryProvider.overrideWithValue(verdictRepo),
          municipalityZonesProvider.overrideWith(
            (ref) async => const [registrationZone],
          ),
          priceCategoriesProvider.overrideWith(
            (ref) async => const [
              PriceCategory(
                id: 'food_corrientazo',
                groupKey: 'food',
                nameEs: 'Almuerzo corriente',
                nameEn: 'Daily lunch',
                unitDescriptionEs: 'Por plato',
                unitDescriptionEn: 'Per meal',
              ),
            ],
          ),
        ],
      );
      addTearDown(reviewContainer.dispose);
      reviewContainer
          .read(selectedMunicipalityProvider.notifier)
          .select(
            const Municipality(
              code: '20001',
              name: 'Valledupar',
              departmentCode: '20',
              isPilot: true,
            ),
          );
      reviewContainer.listen(registerBusinessProvider, (_, _) {});
      final n = reviewContainer.read(registerBusinessProvider.notifier);
      await reviewContainer.read(municipalityZonesProvider.future);
      await reviewContainer.read(priceCategoriesProvider.future);
      fillRegistration(n);

      n.next(); // paso 0 -> 1
      n.next(); // paso 1 -> 2
      n.addDish();
      n.setDish(
        0,
        name: 'Almuerzo especial',
        price: '25000',
        priceCategoryId: 'food_corrientazo',
      );

      // Sin pulsar "Comparar" manualmente, avanza al paso 3 (Revisión).
      n.next();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      var s = reviewContainer.read(registerBusinessProvider);
      expect(s.step, 3);
      expect(evaluatedPrices, [25000]);
      final dish = s.draft.dishes.first;
      expect(s.dishPriceNoticeFor(dish)?.hasError, isTrue);

      // Reintenta con éxito y muestra advertencia de precio alto sin bloquear publicación.
      shouldFail = false;
      await n.retryDishComparison(dish.id);
      s = reviewContainer.read(registerBusinessProvider);
      expect(
        s.dishPriceNoticeFor(dish)?.value?.level,
        PriceVerdictLevel.red,
      );

      n.setPublicationConsent(true);
      await n.submit();
      expect(
        reviewContainer.read(registerBusinessProvider).publishedId,
        'business-id',
      );
    },
  );
}

class _ControllablePriceVerdictRepository implements PriceVerdictRepository {
  _ControllablePriceVerdictRepository({required this.onEvaluate});

  final Future<PriceVerdict> Function(int submittedCop, String zoneId)
  onEvaluate;

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    String? destinationZoneId,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    required int submittedCop,
    bool includeEventContext = false,
  }) => onEvaluate(submittedCop, zoneId);

  @override
  Future<List<PriceCategory>> getCategories() => throw UnimplementedError();

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) => throw UnimplementedError();

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) => throw UnimplementedError();

  @override
  Future<List<MunicipalityZone>> getZones({String municipalityCode = '20001'}) =>
      throw UnimplementedError();
}
