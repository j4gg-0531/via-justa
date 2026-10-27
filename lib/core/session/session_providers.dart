import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/demo/demo_data.dart';

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
  return ref.watch(userNameProvider) ?? DemoData.userName;
});
