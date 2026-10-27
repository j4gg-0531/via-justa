import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/demo/demo_data.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

void main() {
  group('Session lifecycle and clean logout', () {
    test(
        'logging out completely resets state and new login has zero leftover data from previous user',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sessionController = container.read(sessionControllerProvider);

      // --- 1. Sesión de Usuario A ---
      container.read(userNameProvider.notifier).setName('Carlos Vives');
      container.read(profileTypeProvider.notifier).select(ProfileType.settler);
      container.read(selectedMunicipalityProvider.notifier).select(
            const Municipality(
              code: '20001',
              name: 'Valledupar',
              departmentCode: '20',
              isPilot: true,
            ),
          );
      container.read(municipalityInterestProvider.notifier).register('20001');
      container.read(businessSearchQueryProvider.notifier).updateQuery('Taxis');
      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.transport);

      // Verificación de datos de Usuario A
      expect(container.read(userNameProvider), 'Carlos Vives');
      expect(container.read(displayNameProvider), 'Carlos Vives');
      expect(container.read(profileTypeProvider), ProfileType.settler);
      expect(container.read(selectedMunicipalityProvider)?.name, 'Valledupar');
      expect(container.read(municipalityInterestProvider), {'20001'});
      expect(container.read(businessSearchQueryProvider), 'Taxis');
      expect(
        container.read(businessCategoryProvider),
        BusinessCategory.transport,
      );

      // --- 2. Cierre de sesión (Logout centralizado) ---
      sessionController.signOut();

      // Verificación de que ningún dato de Usuario A persiste
      expect(container.read(userNameProvider), isNull);
      expect(container.read(displayNameProvider), DemoData.userName);
      expect(container.read(profileTypeProvider), isNull);
      expect(container.read(selectedMunicipalityProvider), isNull);
      expect(container.read(municipalityInterestProvider), isEmpty);
      expect(container.read(businessSearchQueryProvider), isEmpty);
      expect(container.read(businessCategoryProvider), isNull);

      // --- 3. Sesión de Usuario B (Nuevo ingreso) ---
      container.read(userNameProvider.notifier).setName('Ana María');
      container.read(profileTypeProvider.notifier).select(ProfileType.resident);
      container.read(selectedMunicipalityProvider.notifier).select(
            const Municipality(
              code: '20011',
              name: 'Aguachica',
              departmentCode: '20',
              isPilot: false,
            ),
          );
      container.read(municipalityInterestProvider.notifier).register('20011');
      container.read(businessSearchQueryProvider.notifier).updateQuery('Café');
      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.food);

      // Verificación de que solo existen los datos de Usuario B sin residuos
      expect(container.read(userNameProvider), 'Ana María');
      expect(container.read(displayNameProvider), 'Ana María');
      expect(container.read(profileTypeProvider), ProfileType.resident);
      expect(container.read(selectedMunicipalityProvider)?.name, 'Aguachica');
      expect(container.read(municipalityInterestProvider), {'20011'});
      expect(
        container.read(municipalityInterestProvider),
        isNot(contains('20001')),
      );
      expect(container.read(businessSearchQueryProvider), 'Café');
      expect(
        container.read(businessCategoryProvider),
        BusinessCategory.food,
      );
    });
  });
}
