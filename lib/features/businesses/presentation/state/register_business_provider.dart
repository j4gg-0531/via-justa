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
    this.dishPriceNotices = const <int, AsyncValue<BusinessPriceNotice>>{},
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
  final Map<int, AsyncValue<BusinessPriceNotice>> dishPriceNotices;

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
    Map<int, AsyncValue<BusinessPriceNotice>>? dishPriceNotices,
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

  @override
  RegisterBusinessState build() {
    _generation++;
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
          resolvedZoneName = nearest.nameEs;
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
    Map<int, AsyncValue<BusinessPriceNotice>>? dishPriceNotices,
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
    state = state.copyWith(busy: true, editingId: businessId);
    try {
      var loaded = await ref
          .read(businessRegistrationRepositoryProvider)!
          .loadForEdit(businessId: businessId, ownerId: state.ownerId!);
      if (!ref.mounted || generation != _generation) return;
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
      } else if (loaded.latitude != null && loaded.longitude != null) {
        loaded = loaded.copyWith(zoneId: 'vup_centro');
      }
      state = state.copyWith(
        busy: false,
        draft: loaded,
        zoneName: zoneName,
        dishPriceNotices: const <int, AsyncValue<BusinessPriceNotice>>{},
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
    final clearedDishes = [
      for (final dish in state.draft.dishes)
        BusinessDishDraft(name: dish.name, price: dish.price),
    ];
    _edit(
      state.draft.copyWith(type: type, dishes: clearedDishes),
      dishPriceNotices: const <int, AsyncValue<BusinessPriceNotice>>{},
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
    final zone = state.zones.asData?.value
        .where((zone) => zone.id == point.zoneId)
        .firstOrNull;
    if (zone == null) return;
    _edit(
      state.draft.copyWith(
        latitude: point.latitude,
        longitude: point.longitude,
        zoneId: point.zoneId,
      ),
      dishPriceNotices: const <int, AsyncValue<BusinessPriceNotice>>{},
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
          BusinessDishDraft(priceCategoryId: defaultCategoryId),
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
    final nextCategoryId = clearCategory
        ? null
        : (priceCategoryId ?? current.priceCategoryId);
    final dishes = [...state.draft.dishes];
    dishes[index] = BusinessDishDraft(
      name: name ?? current.name,
      price: price ?? current.price,
      priceCategoryId: nextCategoryId,
    );
    final notices = {...state.dishPriceNotices};
    if (price != null || priceCategoryId != null || clearCategory) {
      notices.remove(index);
    }
    _edit(state.draft.copyWith(dishes: dishes), dishPriceNotices: notices);
  }

  void removeDish(int index) {
    if (index < 0 || index >= state.draft.dishes.length) return;
    final updatedNotices = <int, AsyncValue<BusinessPriceNotice>>{};
    for (final entry in state.dishPriceNotices.entries) {
      if (entry.key < index) {
        updatedNotices[entry.key] = entry.value;
      } else if (entry.key > index) {
        updatedNotices[entry.key - 1] = entry.value;
      }
    }
    _edit(
      state.draft.copyWith(dishes: [...state.draft.dishes]..removeAt(index)),
      dishPriceNotices: updatedNotices,
    );
  }

  /// Compara de forma privada y orientativa el precio de un plato o servicio con la mediana de la zona,
  /// reutilizando el semáforo existente (`priceVerdictRepositoryProvider`).
  Future<void> compareDishPrice(int index) async {
    if (state.busy ||
        state.locked ||
        index < 0 ||
        index >= state.draft.dishes.length) {
      return;
    }
    final dish = state.draft.dishes[index];
    final amountCop = int.tryParse(dish.price.trim());
    final categoryId =
        dish.priceCategoryId ?? state.comparableCategories.firstOrNull?.id;
    if (amountCop == null ||
        amountCop < 500 ||
        amountCop > 20000000 ||
        categoryId == null) {
      return;
    }

    PriceCategory? category = state.comparableCategories
        .where((c) => c.id == categoryId)
        .firstOrNull;
    if (category == null) {
      final loadedCategories = await ref.read(priceCategoriesProvider.future);
      category = comparableCategoriesForBusinessType(
        state.draft.type,
        loadedCategories,
      ).where((c) => c.id == categoryId).firstOrNull;
    }
    if (category == null) return;

    final generation = _generation;
    final zoneId = state.draft.zoneId?.trim().isNotEmpty == true
        ? state.draft.zoneId!
        : (state.initialZoneId.isNotEmpty ? state.initialZoneId : 'vup_centro');
    final municipalityCode = state.municipalityCode ?? '20001';

    state = state.copyWith(
      dishPriceNotices: {
        ...state.dishPriceNotices,
        index: const AsyncLoading<BusinessPriceNotice>(),
      },
      error: state.error,
    );

    try {
      final verdict = await ref
          .read(priceVerdictRepositoryProvider)
          .evaluatePrice(
            categoryId: category.id,
            municipalityCode: municipalityCode,
            zoneId: zoneId,
            destinationZoneId: category.groupKey == 'transport' ? zoneId : null,
            originLatitude: state.draft.latitude,
            originLongitude: state.draft.longitude,
            destinationLatitude: state.draft.latitude,
            destinationLongitude: state.draft.longitude,
            submittedCop: amountCop,
          );
      if (!ref.mounted || generation != _generation) return;
      final notice = buildBusinessPriceNotice(
        category: category,
        verdict: verdict,
      );
      state = state.copyWith(
        dishPriceNotices: {
          ...state.dishPriceNotices,
          index: AsyncData<BusinessPriceNotice>(notice),
        },
        error: state.error,
      );
    } catch (err, st) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          dishPriceNotices: {
            ...state.dishPriceNotices,
            index: AsyncError<BusinessPriceNotice>(err, st),
          },
          error: state.error,
        );
      }
    }
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
    state = state.copyWith(
      error: error,
      step: error == null ? state.step + 1 : state.step,
    );
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
    ref.invalidate(allBusinessesProvider);
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
      ref.invalidate(allBusinessesProvider);
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
