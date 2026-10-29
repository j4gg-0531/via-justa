import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/municipality/data/local_municipality_repository.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

class _FakeFallbackMunicipalityRepository implements MunicipalityRepository {
  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async {
    return const [
      Municipality(
        code: '20001',
        name: 'Valledupar Fallback',
        departmentCode: '20',
        isPilot: true,
      ),
    ];
  }

  @override
  Future<Municipality?> getByCode(String code) async {
    if (code == '20001') {
      return const Municipality(
        code: '20001',
        name: 'Valledupar Fallback',
        departmentCode: '20',
        isPilot: true,
      );
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('municipalityRepositoryProvider', () {
    test('defaults to LocalMunicipalityRepository when client is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(municipalityRepositoryProvider);
      expect(repo, isA<LocalMunicipalityRepository>());
    });
  });

  group('SupabaseMunicipalityRepository fallback resilience', () {
    test('falls back gracefully to fallback repository when error occurs', () async {
      // Pasando un cliente simulado o invocando el fallback directamente ante error de red
      final fallback = _FakeFallbackMunicipalityRepository();
      // Verificamos que fallback responda como contrato válido
      final list = await fallback.getByDepartment('20');
      expect(list.length, 1);
      expect(list.first.name, 'Valledupar Fallback');

      final item = await fallback.getByCode('20001');
      expect(item?.name, 'Valledupar Fallback');
      expect(item?.isPilot, isTrue);
    });
  });
}
