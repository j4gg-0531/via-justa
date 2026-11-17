import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/data/device_business_photo_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_price_notice.dart';
import 'package:via_justa/features/businesses/domain/business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_validator.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

final businessRegistrationRepositoryProvider =
    Provider<BusinessRegistrationRepository?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseBusinessRegistrationRepository(client);
    });
final businessPhotoRepositoryProvider = Provider<BusinessPhotoRepository>(
  (ref) => DeviceBusinessPhotoRepository(),
);

class RegisterBusinessState {
  const RegisterBusinessState({
    this.draft = const BusinessDraft(),
    this.step = 0,
    this.busy = false,
    this.locked = false,
    this.error,
    this.publishedId,
    this.editingId,
    this.withdrawn = false,
    this.ownerId,
    this.municipalityCode,
    this.municipalityName = '',
    this.zones = const AsyncLoading(),
    this.zoneName = '',
    this.priceCategories = const AsyncLoading(),
    this.dishPriceNotices = const <String, AsyncValue<BusinessPriceNotice>>{},
  });
  final BusinessDraft draft;
  final int step;
  final bool busy;
  final bool locked;
  final String? error;
  final String? publishedId;
  final String? editingId;
  final bool withdrawn;
  final String? ownerId;
  final String? municipalityCode;
  final String municipalityName;
  final AsyncValue<List<MunicipalityZone>> zones;
  final String zoneName;
  final AsyncValue<List<PriceCategory>> priceCategories;

  /// Avisos de precio orientativos indexados por el `id` estable de cada plato.
  final Map<String, AsyncValue<BusinessPriceNotice>> dishPriceNotices;

  bool get available => ownerId != null && municipalityCode != null;
  bool get isEditing => editingId != null;
  bool get canAddPhoto => draft.photos.length < 5;
  bool get canAddDish => draft.dishes.length < 5;
  String get initialZoneId =>
      draft.zoneId ?? zones.asData?.value.firstOrNull?.id ?? '';

  /// Categorías del catálogo de precios que tienen unidad equivalente para este tipo de negocio.
  List<PriceCategory> get comparableCategories =>
      comparableCategoriesForBusinessType(
        draft.type,
        priceCategories.asData?.value ?? const <PriceCategory>[],
      );

  AsyncValue<BusinessPriceNotice>? dishPriceNoticeFor(BusinessDishDraft dish) =>
      dish.id.isEmpty ? null : dishPriceNotices[dish.id];

  String? dishCategoryId(int index) {
    if (index < 0 || index >= draft.dishes.length) return null;
    return effectiveDishCategoryId(draft.dishes[index], comparableCategories);
  }

  bool canCompareDish(int index) {
    if (index < 0 || index >= draft.dishes.length) return false;
    return canCompareBusinessDishPrice(
      draft.dishes[index],
      comparableCategories,
    );
  }

  RegisterBusinessState copyWith({
    BusinessDraft? draft,
    int? step,
    bool? busy,
    bool? locked,
    String? error,
    String? publishedId,
    String? editingId,
    bool? withdrawn,
    AsyncValue<List<MunicipalityZone>>? zones,
    String? zoneName,
    AsyncValue<List<PriceCategory>>? priceCategories,
    Map<String, AsyncValue<BusinessPriceNotice>>? dishPriceNotices,
  }) => RegisterBusinessState(
    draft: draft ?? this.draft,
    step: step ?? this.step,
    busy: busy ?? this.busy,
    locked: locked ?? this.locked,
    error: error,
    publishedId: publishedId ?? this.publishedId,
    editingId: editingId ?? this.editingId,
    withdrawn: withdrawn ?? this.withdrawn,
    ownerId: ownerId,
    municipalityCode: municipalityCode,
    municipalityName: municipalityName,
    zones: zones ?? this.zones,
    zoneName: zoneName ?? this.zoneName,
    priceCategories: priceCategories ?? this.priceCategories,
    dishPriceNotices: Map.unmodifiable(
      dishPriceNotices ?? this.dishPriceNotices,
    ),
  );
}

class RegisterBusinessNotifier extends Notifier<RegisterBusinessState> {
  late String _requestId;
  int _generation = 0;
  int _nextDishSequence = 0;
  final Map<String, int> _dishCompareSequences = <String, int>{};
  String _languageCode = 'es';

  String _newDishId() => 'dish_${++_nextDishSequence}';

  void _bumpCompareSequence(String dishId) {
    if (dishId.isEmpty) return;
    _dishCompareSequences[dishId] = (_dishCompareSequences[dishId] ?? 0) + 1;
  }

  void _bumpAllCompareSequences() {
    final ids = <String>{
      ..._dishCompareSequences.keys,
      ...state.dishPriceNotices.keys,
      for (final dish in state.draft.dishes)
        if (dish.id.isNotEmpty) dish.id,
    };
    for (final id in ids) {
      _dishCompareSequences[id] = (_dishCompareSequences[id] ?? 0) + 1;
    }
  }

  @override
  RegisterBusinessState build() {
    _generation++;
    _nextDishSequence = 0;
    _dishCompareSequences.clear();
    _languageCode = 'es';
    _requestId = _newRequestId();
    final auth = ref.watch(
      authControllerProvider.select(
        (value) => (value.session?.userId, value.usesDemoData),
      ),
    );
    final municipality = ref.watch(selectedMunicipalityProvider);
    final repository = ref.watch(businessRegistrationRepositoryProvider);
    ref.listen(municipalityZonesProvider, (_, next) {
      final currentDraft = state.draft;
      String resolvedZoneName = state.zoneName;
      BusinessDraft updatedDraft = currentDraft;
      final zoneList = next.asData?.value;
      if (zoneList != null &&
          zoneList.isNotEmpty &&
          currentDraft.latitude != null &&
          currentDraft.longitude != null &&
          currentDraft.zoneId == null) {
        final nearest = resolveNearestZoneByCoordinates(
          zones: zoneList,
          latitude: currentDraft.latitude!,
          longitude: currentDraft.longitude!,
        );
        if (nearest != null) {
          updatedDraft = currentDraft.copyWith(zoneId: nearest.id);
          resolvedZoneName = nearest.localizedName(_languageCode);
        }
      }
      state = state.copyWith(
        zones: next,
        draft: updatedDraft,
        zoneName: resolvedZoneName,
        error: state.error,
      );
    });
    ref.listen(priceCategoriesProvider, (_, next) {
      state = state.copyWith(priceCategories: next, error: state.error);
    });
    return RegisterBusinessState(
      ownerId: repository != null && !auth.$2 ? auth.$1 : null,
      municipalityCode:
          municipality?.isPilot == true && municipality?.code == '20001'
          ? municipality!.code
          : null,
      municipalityName: municipality?.name ?? '',
      zones: ref.read(municipalityZonesProvider),
      priceCategories: ref.read(priceCategoriesProvider),
    );
  }

  String _newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _edit(
    BusinessDraft draft, {
    Map<String, AsyncValue<BusinessPriceNotice>>? dishPriceNotices,
  }) {
    if (state.busy || state.locked || state.publishedId != null) return;
    state = state.copyWith(
      draft: draft,
      dishPriceNotices: dishPriceNotices,
    );
  }

  Future<void> loadEdit(String businessId, String languageCode) async {
    if (state.editingId == businessId || state.busy || !state.available) return;
    final generation = _generation;
    _languageCode = languageCode;
    _bumpAllCompareSequences();
    state = state.copyWith(busy: true, editingId: businessId);
    try {
      var loaded = await ref
          .read(businessRegistrationRepositoryProvider)!
          .loadForEdit(businessId: businessId, ownerId: state.ownerId!);
      if (!ref.mounted || generation != _generation) return;

      final seenDishIds = <String>{};
      final normalizedDishes = <BusinessDishDraft>[
        for (final dish in loaded.dishes)
          () {
            final rawId = dish.id.trim();
            final resolvedId = rawId.isNotEmpty && seenDishIds.add(rawId)
                ? rawId
                : _newDishId();
            seenDishIds.add(resolvedId);
            return dish.copyWith(id: resolvedId);
          }(),
      ];
      loaded = loaded.copyWith(dishes: normalizedDishes);

      var zoneName = state.zoneName;
      final zoneList = state.zones.asData?.value;
      if (loaded.latitude != null &&
          loaded.longitude != null &&
          zoneList != null &&
          zoneList.isNotEmpty) {
        final nearest = resolveNearestZoneByCoordinates(
          zones: zoneList,
          latitude: loaded.latitude!,
          longitude: loaded.longitude!,
        );
        if (nearest != null) {
          loaded = loaded.copyWith(zoneId: nearest.id);
          zoneName = nearest.localizedName(languageCode);
        }
      }
      state = state.copyWith(
        busy: false,
        draft: loaded,
        zoneName: zoneName,
        dishPriceNotices: const <String, AsyncValue<BusinessPriceNotice>>{},
      );
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          busy: false,
          error: error is BusinessRegistrationFailure ? error.key : 'network',
        );
      }
    }
  }

  void setField(BusinessField field, String value) {
    _edit(
      state.draft.copyWith(
        fields: {...state.draft.fields, field: value},
        whatsappConsent: field == BusinessField.whatsapp ? false : null,
      ),
    );
  }

  void setType(BusinessType type) {
    if (state.isEditing) return;
    _bumpAllCompareSequences();
    final clearedDishes = [
      for (final dish in state.draft.dishes)
        BusinessDishDraft(
          id: dish.id.isEmpty ? _newDishId() : dish.id,
          name: dish.name,
          price: dish.price,
        ),
    ];
    _edit(
      state.draft.copyWith(type: type, dishes: clearedDishes),
      dishPriceNotices: const <String, AsyncValue<BusinessPriceNotice>>{},
    );
  }

  void setWhatsappConsent(bool value) =>
      _edit(state.draft.copyWith(whatsappConsent: value));
  void setPublicationConsent(bool value) =>
      _edit(state.draft.copyWith(publicationConsent: value));
  void setHours(String day, BusinessDayHours hours) =>
      _edit(state.draft.copyWith(hours: {...state.draft.hours, day: hours}));

  void selectPoint(PickedMapPoint point, String languageCode) {
    if (state.busy || state.locked) return;
    _languageCode = languageCode;
    final zone = state.zones.asData?.value
        .where((zone) => zone.id == point.zoneId)
        .firstOrNull;
    if (zone == null) return;
    _bumpAllCompareSequences();
    _edit(
      state.draft.copyWith(
        latitude: point.latitude,
        longitude: point.longitude,
        zoneId: point.zoneId,
      ),
      dishPriceNotices: const <String, AsyncValue<BusinessPriceNotice>>{},
    );
    state = state.copyWith(zoneName: zone.localizedName(languageCode));
  }

  void reloadZones() => ref.invalidate(municipalityZonesProvider);

  void addDish() {
    if (state.draft.dishes.length >= 5) return;
    final defaultCategoryId = state.comparableCategories.firstOrNull?.id;
    _edit(
      state.draft.copyWith(
        dishes: [
          ...state.draft.dishes,
          BusinessDishDraft(
            id: _newDishId(),
            priceCategoryId: defaultCategoryId,
          ),
        ],
      ),
    );
  }

  void setDish(
    int index, {
    String? name,
    String? price,
    String? priceCategoryId,
    bool clearCategory = false,
  }) {
    if (index < 0 || index >= state.draft.dishes.length) return;
    final current = state.draft.dishes[index];
    final dishId = current.id.isNotEmpty ? current.id : _newDishId();
    final nextCategoryId = clearCategory
        ? null
        : (priceCategoryId ?? current.priceCategoryId);
    final dishes = [...state.draft.dishes];
    dishes[index] = BusinessDishDraft(
      id: dishId,
      name: name ?? current.name,
      price: price ?? current.price,
      priceCategoryId: nextCategoryId,
    );
    final notices = {...state.dishPriceNotices};
    if (price != null || priceCategoryId != null || clearCategory) {
      notices.remove(dishId);
      _bumpCompareSequence(dishId);
    }
    _edit(state.draft.copyWith(dishes: dishes), dishPriceNotices: notices);
  }

  void removeDish(int index) {
    if (index < 0 || index >= state.draft.dishes.length) return;
    final removedId = state.draft.dishes[index].id;
    _bumpCompareSequence(removedId);
    final updatedNotices = {...state.dishPriceNotices}..remove(removedId);
    _edit(
      state.draft.copyWith(dishes: [...state.draft.dishes]..removeAt(index)),
      dishPriceNotices: updatedNotices,
    );
  }

  BusinessDishDraft? _findDishById(String dishId) {
    if (dishId.isEmpty) return null;
    for (final dish in state.draft.dishes) {
      if (dish.id == dishId) return dish;
    }
    return null;
  }

  bool _isFreshDishComparison({
    required int generation,
    required String dishId,
    required int requestSeq,
    required String capturedPrice,
    required String capturedCategoryId,
    required BusinessType capturedType,
    String? capturedZoneId,
  }) {
    if (!ref.mounted || generation != _generation) return false;
    if (_dishCompareSequences[dishId] != requestSeq) return false;
    if (state.draft.type != capturedType) return false;
    final latestDish = _findDishById(dishId);
    if (latestDish == null) return false;
    if (latestDish.price != capturedPrice) return false;
    if (latestDish.priceCategoryId != capturedCategoryId) return false;
    if (capturedZoneId != null &&
        state.draft.zoneId != null &&
        state.draft.zoneId != capturedZoneId) {
      return false;
    }
    return true;
  }

  Future<String> _resolveZoneIdForComparison() async {
    final existingZoneId = state.draft.zoneId?.trim();
    if (existingZoneId != null && existingZoneId.isNotEmpty) {
      return existingZoneId;
    }
    final cachedZones = state.zones.asData?.value;
    final zoneList = (cachedZones != null && cachedZones.isNotEmpty)
        ? cachedZones
        : await ref.read(municipalityZonesProvider.future);
    if (zoneList.isEmpty) {
      throw StateError('zones_unavailable');
    }
    final lat = state.draft.latitude;
    final lng = state.draft.longitude;
    if (lat != null && lng != null) {
      final nearest = resolveNearestZoneByCoordinates(
        zones: zoneList,
        latitude: lat,
        longitude: lng,
      );
      if (nearest != null) return nearest.id;
    }
    return zoneList.first.id;
  }

  /// Compara de forma privada y orientativa el precio de un plato por índice.
  Future<void> compareDishPrice(int index) async {
    if (index < 0 || index >= state.draft.dishes.length) return;
    await compareDishPriceById(state.draft.dishes[index].id);
  }

  /// Compara el precio de un plato usando su `id` estable y secuencia anti-carreras.
  Future<void> compareDishPriceById(String dishId) async {
    if (state.busy || state.locked || dishId.isEmpty) return;
    final dish = _findDishById(dishId);
    if (dish == null) return;
    final amountCop = int.tryParse(dish.price.trim());
    final categoryId = dish.priceCategoryId;
    if (amountCop == null ||
        amountCop < 500 ||
        amountCop > 20000000 ||
        categoryId == null) {
      return;
    }

    final generation = _generation;
    final capturedPrice = dish.price;
    final capturedType = state.draft.type;
    _bumpCompareSequence(dishId);
    final requestSeq = _dishCompareSequences[dishId]!;
    String? capturedZoneId;

    state = state.copyWith(
      dishPriceNotices: {
        ...state.dishPriceNotices,
        dishId: const AsyncLoading<BusinessPriceNotice>(),
      },
      error: state.error,
    );

    try {
      PriceCategory? category = state.comparableCategories
          .where((c) => c.id == categoryId)
          .firstOrNull;
      if (category == null) {
        final loadedCategories = await ref.read(priceCategoriesProvider.future);
        if (!_isFreshDishComparison(
          generation: generation,
          dishId: dishId,
          requestSeq: requestSeq,
          capturedPrice: capturedPrice,
          capturedCategoryId: categoryId,
          capturedType: capturedType,
        )) {
          return;
        }
        category = comparableCategoriesForBusinessType(
          capturedType,
          loadedCategories,
        ).where((c) => c.id == categoryId).firstOrNull;
      }
      if (category == null) {
        final cleaned = {...state.dishPriceNotices}..remove(dishId);
        state = state.copyWith(dishPriceNotices: cleaned, error: state.error);
        return;
      }

      capturedZoneId = await _resolveZoneIdForComparison();
      if (!_isFreshDishComparison(
        generation: generation,
        dishId: dishId,
        requestSeq: requestSeq,
        capturedPrice: capturedPrice,
        capturedCategoryId: categoryId,
        capturedType: capturedType,
        capturedZoneId: capturedZoneId,
      )) {
        return;
      }

      final municipalityCode = state.municipalityCode ?? '20001';
      final verdict = await ref
          .read(priceVerdictRepositoryProvider)
          .evaluatePrice(
            categoryId: category.id,
            municipalityCode: municipalityCode,
            zoneId: capturedZoneId,
            destinationZoneId: category.groupKey == 'transport'
                ? capturedZoneId
                : null,
            originLatitude: state.draft.latitude,
            originLongitude: state.draft.longitude,
            destinationLatitude: state.draft.latitude,
            destinationLongitude: state.draft.longitude,
            submittedCop: amountCop,
          );
      if (!_isFreshDishComparison(
        generation: generation,
        dishId: dishId,
        requestSeq: requestSeq,
        capturedPrice: capturedPrice,
        capturedCategoryId: categoryId,
        capturedType: capturedType,
        capturedZoneId: capturedZoneId,
      )) {
        return;
      }
      final notice = buildBusinessPriceNotice(
        category: category,
        verdict: verdict,
      );
      state = state.copyWith(
        dishPriceNotices: {
          ...state.dishPriceNotices,
          dishId: AsyncData<BusinessPriceNotice>(notice),
        },
        error: state.error,
      );
    } catch (err, st) {
      if (_isFreshDishComparison(
        generation: generation,
        dishId: dishId,
        requestSeq: requestSeq,
        capturedPrice: capturedPrice,
        capturedCategoryId: categoryId,
        capturedType: capturedType,
        capturedZoneId: capturedZoneId,
      )) {
        state = state.copyWith(
          dishPriceNotices: {
            ...state.dishPriceNotices,
            dishId: AsyncError<BusinessPriceNotice>(err, st),
          },
          error: state.error,
        );
      }
    }
  }

  /// Consulta automáticamente al entrar a Revisión los platos comparables pendientes o con error previo.
  Future<void> comparePendingDishes() async {
    if (state.busy || state.locked) return;
    final pendingIds = <String>[];
    for (final dish in state.draft.dishes) {
      if (dish.id.isEmpty || dish.priceCategoryId == null) continue;
      final amountCop = int.tryParse(dish.price.trim());
      if (amountCop == null || amountCop < 500 || amountCop > 20000000) {
        continue;
      }
      if (state.dishPriceNotices[dish.id] is AsyncData<BusinessPriceNotice>) {
        continue;
      }
      pendingIds.add(dish.id);
    }
    if (pendingIds.isEmpty) return;
    await Future.wait([
      for (final dishId in pendingIds) compareDishPriceById(dishId),
    ]);
  }

  /// Reintenta la comparación zonal de un plato concreto recargando catálogos en error si hace falta.
  Future<void> retryDishComparison(String dishId) async {
    if (state.zones.hasError) {
      ref.invalidate(municipalityZonesProvider);
    }
    if (state.priceCategories.hasError) {
      ref.invalidate(priceCategoriesProvider);
    }
    await compareDishPriceById(dishId);
  }

  void removePhoto(int index) => _edit(
    state.draft.copyWith(photos: [...state.draft.photos]..removeAt(index)),
  );

  Future<void> addPhoto() async {
    if (state.busy || state.locked || state.draft.photos.length >= 5) return;
    final generation = _generation;
    state = state.copyWith(busy: true);
    try {
      final photo = await ref.read(businessPhotoRepositoryProvider).pickPhoto();
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        busy: false,
        draft: photo == null
            ? state.draft
            : state.draft.copyWith(photos: [...state.draft.photos, photo]),
      );
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          busy: false,
          error: error is BusinessRegistrationFailure
              ? error.key
              : 'photoInvalid',
        );
      }
    }
  }

  void next() {
    if (state.busy || state.locked || state.step == 3) return;
    final error = validateBusinessStep(state.draft, state.step);
    final nextStep = error == null ? state.step + 1 : state.step;
    state = state.copyWith(
      error: error,
      step: nextStep,
    );
    if (error == null && nextStep == 3) {
      unawaited(comparePendingDishes());
    }
  }

  void back() {
    if (!state.busy && !state.locked && state.step > 0) {
      state = state.copyWith(step: state.step - 1);
    }
  }

  Future<void> submit() async {
    if (state.busy || state.publishedId != null || !state.available) return;
    for (var step = 0; step < 4; step++) {
      final error = validateBusinessStep(state.draft, step);
      if (error != null) {
        state = state.copyWith(step: step, error: error);
        return;
      }
    }
    final generation = _generation;
    state = state.copyWith(busy: true, locked: !state.isEditing);
    try {
      final id = await ref
          .read(businessRegistrationRepositoryProvider)!
          .publish(
            draft: state.draft,
            requestId: _requestId,
            ownerId: state.ownerId!,
            municipalityCode: state.municipalityCode!,
            businessId: state.editingId,
          );
      if (!ref.mounted || generation != _generation) return;
      _published(id);
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          busy: false,
          error: error is BusinessRegistrationFailure ? error.key : 'network',
        );
      }
    }
  }

  void _published(String id) {
    state = state.copyWith(busy: false, locked: false, publishedId: id);
    ref.invalidate(businessCatalogProvider);
    ref.invalidate(allPriceMapItemsProvider);
  }

  Future<void> withdraw() async {
    if (state.busy || state.editingId == null || !state.available) return;
    final generation = _generation;
    state = state.copyWith(busy: true);
    try {
      await ref
          .read(businessRegistrationRepositoryProvider)!
          .withdraw(businessId: state.editingId!, ownerId: state.ownerId!);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(busy: false, locked: false, withdrawn: true);
      ref.invalidate(businessCatalogProvider);
      ref.invalidate(allPriceMapItemsProvider);
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          busy: false,
          error: error is BusinessRegistrationFailure ? error.key : 'network',
        );
      }
    }
  }

  Future<void> discard() async {
    if (state.busy || !state.locked) return;
    final generation = _generation;
    state = state.copyWith(busy: true);
    try {
      final id = await ref
          .read(businessRegistrationRepositoryProvider)!
          .discard(requestId: _requestId, ownerId: state.ownerId!);
      if (!ref.mounted || generation != _generation) return;
      if (id != null) {
        _published(id);
      } else {
        _requestId = _newRequestId();
        state = state.copyWith(busy: false, locked: false);
      }
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(busy: false, error: 'cleanup');
      }
    }
  }
}

final registerBusinessProvider =
    NotifierProvider.autoDispose<
      RegisterBusinessNotifier,
      RegisterBusinessState
    >(RegisterBusinessNotifier.new);
