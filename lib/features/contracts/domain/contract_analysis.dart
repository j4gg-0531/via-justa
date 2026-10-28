/// Nivel de atención orientativa para una cláusula de contrato analizada.
enum ContractClauseAttention {
  /// Cláusula estándar dentro de lo habitual
  standard,

  /// Cláusula que requiere revisión o aclaración antes de firmar
  reviewRequired,
}

/// Punto individual explicado en lenguaje sencillo dentro de un análisis de contrato.
class ContractClausePoint {
  const ContractClausePoint({
    required this.id,
    required this.titleEs,
    required this.titleEn,
    required this.explanationEs,
    required this.explanationEn,
    required this.attention,
  });

  final String id;
  final String titleEs;
  final String titleEn;
  final String explanationEs;
  final String explanationEn;
  final ContractClauseAttention attention;

  String localizedTitle(String languageCode) =>
      languageCode == 'en' ? titleEn : titleEs;

  String localizedExplanation(String languageCode) =>
      languageCode == 'en' ? explanationEn : explanationEs;
}

/// Entidad inmutable que representa el resumen orientativo de un contrato (DEMO en VJ-04; Gemini Edge Function en VJ-14).
class ContractAnalysis {
  const ContractAnalysis({
    required this.id,
    required this.contractTypeEs,
    required this.contractTypeEn,
    required this.points,
    this.isDemo = true,
  });

  final String id;
  final String contractTypeEs;
  final String contractTypeEn;

  /// Puntos clave explicados en lenguaje claro (mínimo 2 puntos en el ejemplo DEMO).
  final List<ContractClausePoint> points;

  /// Indica si el resultado pertenece al modo demostración sin análisis de documento real.
  final bool isDemo;

  String localizedContractType(String languageCode) =>
      languageCode == 'en' ? contractTypeEn : contractTypeEs;
}
