/// Tema de cada paso en la ruta de llegada e instalación para migrantes en Valledupar.
enum SettlerInstallationTopic {
  leaseContract,
  civicGuidance,
  referenceFares,
  localDirectory,
}

/// Paso verificable de la ruta de instalación (`ProfileType.settler`).
class SettlerInstallationStep {
  const SettlerInstallationStep({
    required this.id,
    required this.topic,
    required this.titleKey,
    required this.descriptionKey,
    required this.ctaKey,
  });

  final String id;
  final SettlerInstallationTopic topic;
  final String titleKey;
  final String descriptionKey;
  final String ctaKey;
}

/// Catálogo de pasos de orientación e instalación en el municipio piloto.
const List<SettlerInstallationStep> kSettlerInstallationSteps =
    <SettlerInstallationStep>[
      SettlerInstallationStep(
        id: 'lease_law_820',
        topic: SettlerInstallationTopic.leaseContract,
        titleKey: 'home.settler_step_lease_title',
        descriptionKey: 'home.settler_step_lease_desc',
        ctaKey: 'home.settler_step_lease_cta',
      ),
      SettlerInstallationStep(
        id: 'civic_rights',
        topic: SettlerInstallationTopic.civicGuidance,
        titleKey: 'home.settler_step_rights_title',
        descriptionKey: 'home.settler_step_rights_desc',
        ctaKey: 'home.settler_step_rights_cta',
      ),
      SettlerInstallationStep(
        id: 'reference_fares',
        topic: SettlerInstallationTopic.referenceFares,
        titleKey: 'home.settler_step_fares_title',
        descriptionKey: 'home.settler_step_fares_desc',
        ctaKey: 'home.settler_step_fares_cta',
      ),
      SettlerInstallationStep(
        id: 'local_directory',
        topic: SettlerInstallationTopic.localDirectory,
        titleKey: 'home.settler_step_directory_title',
        descriptionKey: 'home.settler_step_directory_desc',
        ctaKey: 'home.settler_step_directory_cta',
      ),
    ];

/// Alterna el estado completado de un paso válido del checklist de instalación.
Set<String> toggleSettlerChecklistStep(
  Set<String> completedIds,
  String stepId,
) {
  final isKnownStep = kSettlerInstallationSteps.any(
    (step) => step.id == stepId,
  );
  if (!isKnownStep) {
    return Set<String>.unmodifiable(completedIds);
  }
  final next = Set<String>.from(completedIds);
  if (!next.remove(stepId)) {
    next.add(stepId);
  }
  return Set<String>.unmodifiable(next);
}

/// Cuenta cuántos pasos del catálogo están marcados como completados.
int countCompletedSettlerSteps(Set<String> completedIds) {
  var count = 0;
  for (final step in kSettlerInstallationSteps) {
    if (completedIds.contains(step.id)) {
      count++;
    }
  }
  return count;
}

/// Calcula el progreso proporcional (0.0 a 1.0) del checklist de instalación.
double settlerChecklistProgress(Set<String> completedIds) {
  if (kSettlerInstallationSteps.isEmpty) return 0;
  return countCompletedSettlerSteps(completedIds) /
      kSettlerInstallationSteps.length;
}
