import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/home/domain/settler_installation_guide.dart';

/// Estado inmutable del checklist de instalación para el perfil `ProfileType.settler`.
class SettlerChecklistState {
  const SettlerChecklistState({
    this.completedIds = const <String>{},
  });

  final Set<String> completedIds;

  int get completedCount => countCompletedSettlerSteps(completedIds);

  int get totalCount => kSettlerInstallationSteps.length;

  bool isCompleted(String stepId) => completedIds.contains(stepId);
}

/// Notifier que gestiona el progreso del usuario en la ruta de instalación.
class SettlerChecklistNotifier extends Notifier<SettlerChecklistState> {
  @override
  SettlerChecklistState build() => const SettlerChecklistState();

  void toggle(String stepId) {
    state = SettlerChecklistState(
      completedIds: toggleSettlerChecklistStep(state.completedIds, stepId),
    );
  }

  void clear() {
    if (state.completedIds.isEmpty) return;
    state = const SettlerChecklistState();
  }
}

final settlerChecklistProvider =
    NotifierProvider<SettlerChecklistNotifier, SettlerChecklistState>(
      SettlerChecklistNotifier.new,
    );
