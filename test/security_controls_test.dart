import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/security/external_uri_guard.dart';
import 'package:via_justa/core/supabase/secure_supabase_local_storage.dart';
import 'package:via_justa/core/supabase/supabase_settings.dart';

class _InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _vault = <String, String>{};

  @override
  Future<bool> containsKey({required String key}) async {
    return _vault.containsKey(key);
  }

  @override
  Future<void> delete({required String key}) async {
    _vault.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _vault[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _vault[key] = value;
  }
}

void main() {
  group('H-01 (OWASP M9) · SecureSupabaseLocalStorage con Keystore/Keychain', () {
    test('persiste, lee y elimina el JSON de sesion en el almacen seguro', () async {
      final memoryVault = _InMemorySecureStore();
      final storage = SecureSupabaseLocalStorage(store: memoryVault);

      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);

      const sampleSessionJson = '{"access_token":"jwt-sample","refresh_token":"rt-sample"}';
      await storage.persistSession(sampleSessionJson);

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), equals(sampleSessionJson));
      expect(
        await memoryVault.containsKey(
          key: SecureSupabaseLocalStorage.defaultStorageKey,
        ),
        isTrue,
      );

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });
  });

  group('H-02 / H-06 (OWASP M1, M5) · SupabaseSettings HTTPS y rechazo de llaves de servidor', () {
    test('acepta unicamente endpoints HTTPS validos y rechaza HTTP en claro', () {
      const insecureHttp = SupabaseSettings(
        url: 'http://vjehsjqmwibmiqmxlsou.supabase.co',
        publishableKey: 'sb_publishable_valid_client_key',
      );
      expect(insecureHttp.isValidHttpsEndpoint, isFalse);
      expect(insecureHttp.isConfigured, isFalse);

      const secureHttps = SupabaseSettings(
        url: 'https://vjehsjqmwibmiqmxlsou.supabase.co',
        publishableKey: 'sb_publishable_valid_client_key',
      );
      expect(secureHttps.isValidHttpsEndpoint, isTrue);
      expect(secureHttps.isConfigured, isTrue);
    });

    test('rechaza llaves privadas service_role, sb_secret_ o tokens sbp_', () {
      const serviceRoleLeak = SupabaseSettings(
        url: 'https://vjehsjqmwibmiqmxlsou.supabase.co',
        publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service_role.secret',
      );
      expect(serviceRoleLeak.isSafePublishableKey, isFalse);
      expect(serviceRoleLeak.isConfigured, isFalse);

      const secretPrefixLeak = SupabaseSettings(
        url: 'https://vjehsjqmwibmiqmxlsou.supabase.co',
        publishableKey: 'sb_secret_1234567890',
      );
      expect(secretPrefixLeak.isSafePublishableKey, isFalse);
      expect(secretPrefixLeak.isConfigured, isFalse);
    });
  });

  group('H-04 (OWASP M4) · ExternalUriGuard validacion de esquemas, USSD y coordenadas', () {
    test('permite solo esquemas https, tel y geo y bloquea javascript, http, file e intent', () {
      expect(
        ExternalUriGuard.isAllowedExternalUri(
          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=10.474,-73.244'),
        ),
        isTrue,
      );
      expect(
        ExternalUriGuard.isAllowedExternalUri(Uri.parse('tel:+573001234567')),
        isTrue,
      );
      expect(
        ExternalUriGuard.isAllowedExternalUri(Uri.parse('http://example.com')),
        isFalse,
      );
      expect(
        ExternalUriGuard.isAllowedExternalUri(Uri.parse('javascript:alert(1)')),
        isFalse,
      );
      expect(
        ExternalUriGuard.isAllowedExternalUri(Uri.parse('file:///data/data/com.example.via_justa/shared_prefs/auth.xml')),
        isFalse,
      );
      expect(
        ExternalUriGuard.isAllowedExternalUri(Uri.parse('intent://scan/#Intent;scheme=zxing;end')),
        isFalse,
      );
    });

    test('bloquea codigos USSD/MMI (*, #) y telefonos fuera de rango E.164', () {
      expect(ExternalUriGuard.buildSafeTelUri('*#06#'), isNull);
      expect(ExternalUriGuard.buildSafeTelUri('#31#3001234567'), isNull);
      expect(ExternalUriGuard.buildSafeTelUri('123'), isNull);

      final validTel = ExternalUriGuard.buildSafeTelUri('+57 (300) 123-4567');
      expect(validTel, isNotNull);
      expect(validTel.toString(), equals('tel:+573001234567'));
    });

    test('valida rango geografico de Colombia al construir rutas hacia Google Maps', () {
      final validValledupar = ExternalUriGuard.buildSafeGoogleMapsDirectionsUri(
        latitude: 10.4742,
        longitude: -73.2436,
      );
      expect(validValledupar, isNotNull);
      expect(validValledupar!.scheme, equals('https'));
      expect(validValledupar.host, equals('www.google.com'));

      final outsideColombia = ExternalUriGuard.buildSafeGoogleMapsDirectionsUri(
        latitude: 40.7128,
        longitude: -74.0060,
      );
      expect(outsideColombia, isNull);

      final nanCoords = ExternalUriGuard.buildSafeGoogleMapsDirectionsUri(
        latitude: double.nan,
        longitude: -73.2436,
      );
      expect(nanCoords, isNull);
    });
  });

  group('H-02 / H-03 (OWASP M5, M7, M8) · Invariantes en configuracion nativa Android', () {
    test('AndroidManifest.xml deshabilita trafico en claro y backups automaticos', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    });

    test('network_security_config.xml exige cleartextTrafficPermitted="false"', () {
      final netConfig = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).readAsStringSync();
      expect(netConfig, contains('cleartextTrafficPermitted="false"'));
    });

    test('build.gradle.kts activa R8 (isMinifyEnabled, isShrinkResources) y desactiva debug en release', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isDebuggable = false'));
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('"proguard-rules.pro"'));
    });
  });
}
