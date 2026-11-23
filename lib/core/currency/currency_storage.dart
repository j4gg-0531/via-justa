import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/core/currency/currency_formatter.dart';

/// Persistencia local de la preferencia de moneda seleccionada por el usuario.
abstract class CurrencyPreferenceStorage {
  Future<CurrencyDisplayMode?> loadOverride();
  Future<void> saveOverride(CurrencyDisplayMode? mode);
}

class SecureCurrencyPreferenceStorage implements CurrencyPreferenceStorage {
  const SecureCurrencyPreferenceStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const String _key = 'via_justa.currency_display_mode';

  final FlutterSecureStorage _storage;

  @override
  Future<CurrencyDisplayMode?> loadOverride() async {
    try {
      return CurrencyDisplayMode.fromStorage(await _storage.read(key: _key));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveOverride(CurrencyDisplayMode? mode) async {
    try {
      if (mode == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: mode.storageValue);
      }
    } catch (_) {}
  }
}

/// Obtiene la tasa orientativa COP por USD desde `public.app_config` si está configurada.
abstract class CurrencyRateRepository {
  Future<int> fetchCopPerUsdRate();
}

class DefaultCurrencyRateRepository implements CurrencyRateRepository {
  const DefaultCurrencyRateRepository();

  @override
  Future<int> fetchCopPerUsdRate() async => kDefaultCopPerUsd;
}

class SupabaseCurrencyRateRepository implements CurrencyRateRepository {
  const SupabaseCurrencyRateRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<int> fetchCopPerUsdRate() async {
    try {
      final row = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'price_verdict_rules')
          .maybeSingle();
      if (row == null) return kDefaultCopPerUsd;
      final value = row['value'];
      if (value is Map<String, dynamic>) {
        return parseValidCopPerUsdRate(value['usd_exchange_rate_cop']);
      }
      return kDefaultCopPerUsd;
    } catch (_) {
      return kDefaultCopPerUsd;
    }
  }
}
