import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/municipality/data/local_municipality_repository.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';

/// Implementación de [MunicipalityRepository] sobre Supabase (`public.municipalities`).
///
/// Dispone de un [fallback] hacia [LocalMunicipalityRepository] para mantener
/// la experiencia local cuando la app corre sin conexión o sin credenciales de backend.
class SupabaseMunicipalityRepository implements MunicipalityRepository {
  SupabaseMunicipalityRepository(
    this._client, {
    MunicipalityRepository? fallback,
  }) : _fallback = fallback ?? LocalMunicipalityRepository();

  final SupabaseClient _client;
  final MunicipalityRepository _fallback;

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async {
    try {
      final response = await _client
          .from('municipalities')
          .select('code, department_code, name, is_pilot')
          .eq('department_code', departmentCode)
          .order('is_pilot', ascending: false)
          .order('name', ascending: true);

      final list = (response as List<dynamic>)
          .map((row) {
            final map = row as Map<String, dynamic>;
            return Municipality(
              code: map['code'] as String,
              departmentCode: map['department_code'] as String,
              name: map['name'] as String,
              isPilot: map['is_pilot'] as bool? ?? false,
            );
          })
          .toList();

      if (list.isEmpty) {
        return await _fallback.getByDepartment(departmentCode);
      }
      return list;
    } catch (_) {
      return await _fallback.getByDepartment(departmentCode);
    }
  }

  @override
  Future<Municipality?> getByCode(String code) async {
    try {
      final row = await _client
          .from('municipalities')
          .select('code, department_code, name, is_pilot')
          .eq('code', code)
          .maybeSingle();

      if (row == null) {
        return await _fallback.getByCode(code);
      }

      return Municipality(
        code: row['code'] as String,
        departmentCode: row['department_code'] as String,
        name: row['name'] as String,
        isPilot: row['is_pilot'] as bool? ?? false,
      );
    } catch (_) {
      return await _fallback.getByCode(code);
    }
  }
}
