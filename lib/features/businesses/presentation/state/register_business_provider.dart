import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/data/device_business_photo_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_validator.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
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
    this.ownerId,
    this.municipalityCode,
    this.municipalityName = '',
    this.zones = const AsyncLoading(),
    this.zoneName = '',
  });
  final BusinessDraft draft;
  final int step;
  final bool busy;
  final bool locked;
  final String? error;
  final String? publishedId;
  final String? ownerId;
  final String? municipalityCode;
  final String municipalityName;
  final AsyncValue<List<MunicipalityZone>> zones;
  final String zoneName;
  bool get available => ownerId != null && municipalityCode != null;
  bool get canAddPhoto => draft.photos.length < 5;
  bool get canAddDish => draft.dishes.length < 5;
  String get initialZoneId =>
      draft.zoneId ?? zones.asData?.value.firstOrNull?.id ?? '';

  RegisterBusinessState copyWith({
    BusinessDraft? draft,
    int? step,
    bool? busy,
    bool? locked,
    String? error,
    String? publishedId,
    AsyncValue<List<MunicipalityZone>>? zones,
    String? zoneName,
  }) => RegisterBusinessState(
    draft: draft ?? this.draft,
    step: step ?? this.step,
    busy: busy ?? this.busy,
    locked: locked ?? this.locked,
    error: error,
    publishedId: publishedId ?? this.publishedId,
    ownerId: ownerId,
    municipalityCode: municipalityCode,
    municipalityName: municipalityName,
    zones: zones ?? this.zones,
    zoneName: zoneName ?? this.zoneName,
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
      state = state.copyWith(zones: next, error: state.error);
    });
    return RegisterBusinessState(
      ownerId: repository != null && !auth.$2 ? auth.$1 : null,
      municipalityCode:
          municipality?.isPilot == true && municipality?.code == '20001'
          ? municipality!.code
          : null,
      municipalityName: municipality?.name ?? '',
      zones: ref.read(municipalityZonesProvider),
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

  void _edit(BusinessDraft draft) {
    if (state.busy || state.locked || state.publishedId != null) return;
    state = state.copyWith(draft: draft);
  }

  void setField(BusinessField field, String value) {
    _edit(
      state.draft.copyWith(
        fields: {...state.draft.fields, field: value},
        whatsappConsent: field == BusinessField.whatsapp ? false : null,
      ),
    );
  }

  void setType(BusinessType type) => _edit(state.draft.copyWith(type: type));
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
    );
    state = state.copyWith(zoneName: zone.localizedName(languageCode));
  }

  void reloadZones() => ref.invalidate(municipalityZonesProvider);

  void addDish() {
    if (state.draft.dishes.length >= 5) return;
    _edit(
      state.draft.copyWith(
        dishes: [...state.draft.dishes, const BusinessDishDraft()],
      ),
    );
  }

  void setDish(int index, {String? name, String? price}) {
    final dishes = [...state.draft.dishes];
    dishes[index] = BusinessDishDraft(
      name: name ?? dishes[index].name,
      price: price ?? dishes[index].price,
    );
    _edit(state.draft.copyWith(dishes: dishes));
  }

  void removeDish(int index) => _edit(
    state.draft.copyWith(dishes: [...state.draft.dishes]..removeAt(index)),
  );
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
    state = state.copyWith(busy: true, locked: true);
    try {
      final id = await ref
          .read(businessRegistrationRepositoryProvider)!
          .publish(
            draft: state.draft,
            requestId: _requestId,
            ownerId: state.ownerId!,
            municipalityCode: state.municipalityCode!,
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
