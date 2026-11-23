import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/currency/currency_formatter.dart';
import 'package:via_justa/core/currency/currency_storage.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';

final currencyPreferenceStorageProvider = Provider<CurrencyPreferenceStorage>((
  ref,
) {
  return const SecureCurrencyPreferenceStorage();
});

final currencyRateRepositoryProvider = Provider<CurrencyRateRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    return SupabaseCurrencyRateRepository(client);
  }
  return const DefaultCurrencyRateRepository();
});

/// Tasa orientativa COP por 1 USD (lee de `app_config` si existe, o usa 4.100).
final copPerUsdRateProvider = FutureProvider<int>((ref) {
  return ref.watch(currencyRateRepositoryProvider).fetchCopPerUsdRate();
});

/// Valor sincrónico de la tasa orientativa para formateo inmediato en pantallas.
final activeCopPerUsdRateProvider = Provider<int>((ref) {
  return ref.watch(copPerUsdRateProvider).asData?.value ?? kDefaultCopPerUsd;
});

/// Preferencia explícita de moneda (`null` = automático según idioma activo).
class CurrencyPreferenceNotifier extends Notifier<CurrencyDisplayMode?> {
  bool _hydrated = false;
  bool _userChanged = false;

  @override
  CurrencyDisplayMode? build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }
    return null;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(currencyPreferenceStorageProvider)
        .loadOverride();
    if (!ref.mounted || _userChanged) return;
    if (stored != null && state == null) {
      state = stored;
    }
  }

  Future<void> select(CurrencyDisplayMode mode) async {
    _userChanged = true;
    state = mode;
    await ref.read(currencyPreferenceStorageProvider).saveOverride(mode);
  }

  /// Vuelve al comportamiento automático por idioma (`es` → COP, `en` → COP + USD).
  Future<void> clearOverride() async {
    _userChanged = true;
    state = null;
    await ref.read(currencyPreferenceStorageProvider).saveOverride(null);
  }
}

final currencyOverrideProvider =
    NotifierProvider<CurrencyPreferenceNotifier, CurrencyDisplayMode?>(
      CurrencyPreferenceNotifier.new,
    );

/// Modo de moneda efectivo dado el código de idioma actual de la interfaz (`es` o `en`).
final effectiveCurrencyModeProvider =
    Provider.family<CurrencyDisplayMode, String>((ref, languageCode) {
      final override = ref.watch(currencyOverrideProvider);
      return resolveEffectiveCurrencyMode(
        userOverride: override,
        languageCode: languageCode,
      );
    });
