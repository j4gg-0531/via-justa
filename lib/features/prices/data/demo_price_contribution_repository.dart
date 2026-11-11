import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';

/// Implementación DEMO en memoria del repositorio de aportes ciudadanos de precios (M10).
class DemoPriceContributionRepository implements PriceContributionRepository {
  final List<PriceContributionRecord> _sessionRecords =
      <PriceContributionRecord>[];
  int _counter = 0;

  @override
  Future<PriceContributionRecord> submitContribution({
    required String categoryId,
    required String municipalityCode,
    required String zoneId,
    required int amountCop,
    String? placeNote,
    String? destinationZoneId,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    _counter++;
    final record = PriceContributionRecord(
      id: 'demo_contrib_$_counter',
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      destinationZoneId: destinationZoneId,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      amountCop: amountCop,
      placeNote: sanitizeContributionNote(placeNote ?? ''),
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      isDemo: true,
    );
    _sessionRecords.insert(0, record);
    return record;
  }

  @override
  Future<List<PriceContributionRecord>> getSubmittedContributions() async {
    return List<PriceContributionRecord>.unmodifiable(_sessionRecords);
  }

  @override
  void clearSessionContributions() {
    _sessionRecords.clear();
  }
}
