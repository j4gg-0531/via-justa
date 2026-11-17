import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstracción mínima de almacén clave-valor cifrado (Android Keystore / iOS Keychain).
///
/// Permite inyectar un doble de prueba en tests unitarios sin depender de MethodChannels.
abstract interface class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<bool> containsKey({required String key});
}

/// Implementación de producción respaldada por [FlutterSecureStorage] v11+,
/// que utiliza cifrado AES-GCM con llaves protegidas en Android Keystore
/// (sin depender de `EncryptedSharedPreferences` obsoleto) y Keychain en iOS.
class KeystoreSecureKeyValueStore implements SecureKeyValueStore {
  const KeystoreSecureKeyValueStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<bool> containsKey({required String key}) {
    return _storage.containsKey(key: key);
  }
}

/// Implementación de [LocalStorage] para `supabase_flutter` que persiste el
/// JSON de sesión (`access_token` y `refresh_token`) cifrado mediante
/// Android Keystore / iOS Keychain en lugar de `SharedPreferences` en texto plano
/// (Corrección H-01 / OWASP Mobile Top 10 2024: M9 Insecure Data Storage).
class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({
    SecureKeyValueStore? store,
    this.storageKey = defaultStorageKey,
  }) : _store = store ?? const KeystoreSecureKeyValueStore();

  static const String defaultStorageKey = 'co.viajusta.supabase.auth.session';

  final SecureKeyValueStore _store;
  final String storageKey;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    return _store.read(key: storageKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await _store.read(key: storageKey);
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _store.write(key: storageKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _store.delete(key: storageKey);
  }
}
