import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/demo/demo_data.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/scan/presentation/state/scan_providers.dart';

/// Nombre que el usuario escribió al crear su cuenta (null si no se registró).
class _UserNameNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setName(String name) {
    state = name;
  }

  void clear() {
    state = null;
  }
}

final userNameProvider = NotifierProvider<_UserNameNotifier, String?>(
  _UserNameNotifier.new,
);

/// Nombre para mostrar: el registrado o, si no hay, el de ejemplo (DEMO).
final displayNameProvider = Provider<String>((ref) {
  final raw = ref.watch(userNameProvider)?.trim();
  if (raw == null || raw.isEmpty) {
    return DemoData.userName;
  }
  return raw;
});

/// Controlador centralizado de sesión para gestionar el ciclo de vida del estado de usuario (DEMO).
class SessionController {
  const SessionController(this._ref);

  final Ref _ref;

  /// Restablece íntegramente el estado de la sesión: cierra la sesión remota
  /// (si hay backend) y limpia nombre, perfil, municipio seleccionado,
  /// intereses registrados y filtros de búsqueda.
  void signOut() {
    unawaited(_ref.read(authControllerProvider.notifier).signOut());
    _ref.read(userNameProvider.notifier).clear();
    _ref.read(profileTypeProvider.notifier).clear();
    _ref.read(selectedMunicipalityProvider.notifier).clear();
    _ref.read(municipalityInterestProvider.notifier).clear();
    _ref.read(businessSearchQueryProvider.notifier).clear();
    _ref.read(businessCategoryProvider.notifier).clear();
    _ref.read(priceMapSearchQueryProvider.notifier).clear();
    _ref.read(priceMapCategoryProvider.notifier).clear();
    _ref.read(priceScanProvider.notifier).reset();
    _ref.read(priceContributionProvider.notifier).resetSession();
    _ref.read(scanModeProvider.notifier).reset();
  }
}

final sessionControllerProvider = Provider<SessionController>((ref) {
  return SessionController(ref);
});
