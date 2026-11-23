import 'package:via_justa/features/city/domain/city_overview.dart';

export 'package:via_justa/features/city/domain/city_overview.dart'
    show normalizeCityLocale, resolveSafeCitySourceUri;

/// Filtra y ordena las fichas culturales por sección manteniendo un orden
/// determinístico (`sortOrder`, luego orden canónico de sección y título).
List<CityContentItem> filterCityContentBySection(
  List<CityContentItem> items,
  CityContentSection? section,
) {
  final filtered = <CityContentItem>[];
  for (final item in items) {
    if (section == null || item.section == section) {
      filtered.add(item);
    }
  }
  filtered.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    final bySection = a.section.index.compareTo(b.section.index);
    if (bySection != 0) return bySection;
    return a.title.compareTo(b.title);
  });
  return filtered;
}

/// Obtiene las secciones disponibles en orden canónico, sin duplicados.
List<CityContentSection> availableCitySections(List<CityContentItem> items) {
  final present = <CityContentSection>{};
  for (final item in items) {
    present.add(item.section);
  }
  final ordered = <CityContentSection>[];
  for (final section in CityContentSection.values) {
    if (present.contains(section)) {
      ordered.add(section);
    }
  }
  return ordered;
}

/// Modo de presentación del banner de eventos en `HomePage`.
enum CityBannerMode {
  /// Hay al menos un evento real (o DEMO en modo sin conexión) activo hoy.
  activeEvent,

  /// No hay evento activo hoy, pero existe un próximo evento programado.
  upcomingEvent,

  /// No hay eventos activos ni próximos para mostrar en el inicio.
  noActiveEvent,
}

/// Resultado determinístico de la selección del banner de eventos en `HomePage`.
class CityEventBannerDecision {
  const CityEventBannerDecision({
    required this.mode,
    this.event,
    required this.isDemo,
  });

  final CityBannerMode mode;
  final CityEvent? event;
  final bool isDemo;
}

/// Elige el evento principal para el banner de `HomePage`:
/// 1. Excluye cualquier evento `DEMO` si la app opera en modo en vivo.
/// 2. Prioriza eventos realmente activos sobre próximos, y reales sobre DEMO.
/// 3. Si solo existen eventos pasados o ninguno elegible, oculta el banner.
CityEventBannerDecision selectCityEventBanner(
  List<CityEvent> events, {
  required bool isDemoMode,
}) {
  final eligible = <CityEvent>[];
  for (final event in events) {
    if (!isDemoMode && event.isDemo) continue;
    eligible.add(event);
  }

  final active = <CityEvent>[];
  final upcoming = <CityEvent>[];
  for (final event in eligible) {
    if (event.temporalStatus == CityEventTemporalStatus.active &&
        event.isCurrentlyActive) {
      active.add(event);
    } else if (event.temporalStatus == CityEventTemporalStatus.upcoming) {
      upcoming.add(event);
    }
  }

  int compareEventPriority(CityEvent a, CityEvent b) {
    if (a.isDemo != b.isDemo) {
      return a.isDemo ? 1 : -1;
    }
    return a.startsAt.compareTo(b.startsAt);
  }

  if (active.isNotEmpty) {
    active.sort(compareEventPriority);
    final chosen = active.first;
    return CityEventBannerDecision(
      mode: CityBannerMode.activeEvent,
      event: chosen,
      isDemo: chosen.isDemo,
    );
  }

  if (upcoming.isNotEmpty) {
    upcoming.sort(compareEventPriority);
    final chosen = upcoming.first;
    return CityEventBannerDecision(
      mode: CityBannerMode.upcomingEvent,
      event: chosen,
      isDemo: chosen.isDemo,
    );
  }

  return const CityEventBannerDecision(
    mode: CityBannerMode.noActiveEvent,
    isDemo: false,
  );
}
