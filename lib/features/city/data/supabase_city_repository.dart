import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';

/// Repositorio conectado a Supabase que consume las RPC oficiales
/// `public.get_city_overview` y `public.get_city_events_status` (`VJ-15`).
///
/// Cuando hay cliente de Supabase configurado nunca realiza fallback silencioso
/// a datos de demostración; cualquier error se propaga tipado como
/// [CityLoadException].
class SupabaseCityRepository implements CityRepository {
  const SupabaseCityRepository(this._client);

  final SupabaseClient _client;

  /// Convierte el payload JSONB retornado por `public.get_city_overview`.
  static CityOverview parseOverview(
    Map<String, dynamic> row, {
    bool includeDemo = false,
  }) {
    final municipalityCode = (row['municipality_code'] as String?)?.trim() ?? '';
    final requestedLocale = normalizeCityLocale(
      row['requested_locale'] as String?,
    );

    final rawContent = row['content'];
    final content = <CityContentItem>[];
    var anyFallback = false;

    if (rawContent is List) {
      for (final dynamic rawItem in rawContent) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final isDemo = (item['is_demo'] as bool?) ?? false;
        if (!includeDemo && isDemo) continue;

        final section = CityContentSection.fromApiValue(
          item['section']?.toString(),
        );
        if (section == null) continue;

        final title = (item['title'] as String?)?.trim() ?? '';
        final body = (item['body'] as String?)?.trim() ?? '';
        final sourceCitation =
            (item['source_citation'] as String?)?.trim() ?? '';
        if (title.isEmpty || body.isEmpty) continue;

        final isFallback = (item['is_locale_fallback'] as bool?) ?? false;
        if (isFallback) anyFallback = true;

        content.add(
          CityContentItem(
            id: (item['id'] ?? '').toString(),
            municipalityCode:
                (item['municipality_code'] as String?)?.trim() ??
                municipalityCode,
            slug: (item['slug'] as String?)?.trim() ?? '',
            section: section,
            requestedLocale: normalizeCityLocale(
              (item['requested_locale'] as String?) ?? requestedLocale,
            ),
            resolvedLocale: normalizeCityLocale(
              (item['resolved_locale'] as String?) ?? 'es',
            ),
            isLocaleFallback: isFallback,
            title: title,
            body: body,
            imagePath: _nullableTrimmed(item['image_path']),
            imageLicense: _nullableTrimmed(item['image_license']),
            sourceCitation: sourceCitation,
            sourceUrl: _nullableTrimmed(item['source_url']),
            sortOrder: (item['sort_order'] as num?)?.toInt() ?? 0,
            isDemo: isDemo,
          ),
        );
      }
    }

    final rawEvents = row['events'];
    final events = rawEvents is List
        ? parseEventRows(rawEvents, includeDemo: includeDemo)
        : const <CityEvent>[];

    return CityOverview(
      municipalityCode: municipalityCode,
      municipalityName: (row['municipality_name'] as String?)?.trim() ?? '',
      departmentCode: (row['department_code'] as String?)?.trim() ?? '',
      isPilot: (row['is_pilot'] as bool?) ?? false,
      requestedLocale: requestedLocale,
      hasLocaleFallback:
          ((row['has_locale_fallback'] as bool?) ?? false) || anyFallback,
      content: content,
      events: events,
    );
  }

  /// Convierte filas devueltas por `public.get_city_events_status`.
  static List<CityEvent> parseEventRows(
    List<dynamic> rows, {
    bool includeDemo = false,
  }) {
    final result = <CityEvent>[];
    for (final dynamic rawItem in rows) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final isDemo = (item['is_demo'] as bool?) ?? false;
      if (!includeDemo && isDemo) continue;

      final name = (item['name'] as String?)?.trim() ?? '';
      final startsAt = DateTime.tryParse(item['starts_at']?.toString() ?? '');
      final endsAt = DateTime.tryParse(item['ends_at']?.toString() ?? '');
      final temporalStatus = CityEventTemporalStatus.fromApiValue(
        item['temporal_status']?.toString(),
      );
      if (name.isEmpty ||
          startsAt == null ||
          endsAt == null ||
          temporalStatus == null) {
        continue;
      }

      result.add(
        CityEvent(
          id: (item['id'] ?? '').toString(),
          municipalityCode:
              (item['municipality_code'] as String?)?.trim() ?? '',
          name: name,
          descriptionEs: _nullableTrimmed(item['description_es']),
          descriptionEn: _nullableTrimmed(item['description_en']),
          venue: _nullableTrimmed(item['venue']),
          startsAt: startsAt,
          endsAt: endsAt,
          temporalStatus: temporalStatus,
          isCurrentlyActive:
              (item['is_currently_active'] as bool?) ??
              (temporalStatus == CityEventTemporalStatus.active),
          isDemo: isDemo,
          sourceCitation: _nullableTrimmed(item['source_citation']),
        ),
      );
    }
    return result;
  }

  /// Traduce errores de red o RPC de PostgreSQL a [CityLoadException].
  static CityLoadException mapError(Object error) {
    if (error is CityLoadException) return error;

    if (error is SocketException || error is TimeoutException) {
      return CityLoadException(CityLoadErrorKind.network, error.toString());
    }

    if (error is PostgrestException) {
      final code = error.code?.trim();
      final message = error.message;
      if (code == 'P0002' ||
          message.contains('[CITY_MUNICIPALITY_NOT_FOUND]')) {
        return CityLoadException(CityLoadErrorKind.notFound, message);
      }
      if (code == '22023' ||
          message.contains('[CITY_MUNICIPALITY_NOT_PILOT]')) {
        return CityLoadException(CityLoadErrorKind.notPilot, message);
      }
      return CityLoadException(CityLoadErrorKind.unknown, message);
    }

    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('TimeoutException')) {
      return CityLoadException(CityLoadErrorKind.network, text);
    }

    return CityLoadException(CityLoadErrorKind.unknown, text);
  }

  static String? _nullableTrimmed(Object? value) {
    if (value is! String) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  @override
  Future<CityOverview> getCityOverview({
    required String municipalityCode,
    required String localeCode,
    bool includeDemo = false,
  }) async {
    try {
      final dynamic raw = await _client.rpc<dynamic>(
        'get_city_overview',
        params: <String, dynamic>{
          'p_municipality_code': municipalityCode.trim(),
          'p_locale': normalizeCityLocale(localeCode),
          'p_include_demo': includeDemo,
        },
      );
      if (raw is! Map) {
        throw const CityLoadException(
          CityLoadErrorKind.unknown,
          'Unexpected response shape from get_city_overview',
        );
      }
      return parseOverview(
        Map<String, dynamic>.from(raw),
        includeDemo: includeDemo,
      );
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<CityEvent>> getCityEvents({
    required String municipalityCode,
    bool includeDemo = false,
  }) async {
    try {
      final dynamic raw = await _client.rpc<dynamic>(
        'get_city_events_status',
        params: <String, dynamic>{
          'p_municipality_code': municipalityCode.trim(),
          'p_include_demo': includeDemo,
        },
      );
      if (raw is! List) {
        return const <CityEvent>[];
      }
      return parseEventRows(raw, includeDemo: includeDemo);
    } catch (error) {
      throw mapError(error);
    }
  }
}
