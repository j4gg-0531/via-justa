/// Nivel cerrado de veredicto del semáforo de precios.
enum PriceVerdictLevel {
  /// Dentro del rango justo (desviación <= 15%)
  green,

  /// Variación moderada por encima de la mediana (15% < desviación <= 40%)
  yellow,

  /// Alerta de sobrecobro significativo (desviación > 40%)
  red,

  /// Muestra comunitaria insuficiente (N < 3): sin color de semáforo ni umbral
  insufficient;

  /// Convierte de forma segura el valor textual del contrato JSON (`docs/contrato-datos-v1.md`).
  static PriceVerdictLevel fromWire(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'green':
        return PriceVerdictLevel.green;
      case 'yellow':
        return PriceVerdictLevel.yellow;
      case 'red':
        return PriceVerdictLevel.red;
      case 'insufficient':
        return PriceVerdictLevel.insufficient;
      default:
        throw FormatException('Unknown PriceVerdictLevel: $raw');
    }
  }
}

/// Contexto opcional de temporada o evento activo en el municipio (`public.events`).
class PriceEventContext {
  const PriceEventContext({
    required this.eventName,
    required this.eventReferenceCop,
    required this.eventDeviationPct,
    this.isDemo = true,
  });

  /// Nombre del evento (ej. "[DEMO] Festival de la Leyenda Vallenata").
  final String eventName;

  /// Mediana de referencia observada durante el evento en COP.
  final int eventReferenceCop;

  /// Porcentaje de desviación respecto a la mediana del evento.
  final double eventDeviationPct;

  /// Indica si el contexto de evento es un dato de demostración.
  final bool isDemo;

  factory PriceEventContext.fromMap(Map<String, dynamic> map) {
    final name = map['event_name'] as String?;
    final refCop = map['event_reference_cop'] as int?;
    final devPct = (map['event_deviation_pct'] as num?)?.toDouble();
    if (name == null || name.trim().isEmpty || refCop == null || refCop <= 0 || devPct == null) {
      throw const FormatException('Invalid PriceEventContext payload');
    }
    return PriceEventContext(
      eventName: name,
      eventReferenceCop: refCop,
      eventDeviationPct: devPct,
      isDemo: map['is_demo'] as bool? ?? true,
    );
  }
}

/// Resultado inmutable de evaluación del semáforo de precios (M07 / M20).
/// Conciliado con el contrato RPC `calculate_price_verdict` en `docs/contrato-datos-v1.md`.
class PriceVerdict {
  const PriceVerdict({
    required this.categoryId,
    required this.municipalityCode,
    this.zoneId = 'vup_centro',
    required this.level,
    required this.submittedCop,
    required this.n,
    this.referenceCop,
    this.deviationPct,
    this.recommendedCapCop,
    this.windowDays = 60,
    this.eventContext,
    this.lowPriceWarning = false,
    this.isDemo = true,
  }) : assert(submittedCop > 0, 'submittedCop must be positive'),
       assert(n >= 0, 'sample size n cannot be negative');

  /// Categoría comparable evaluada.
  final String categoryId;

  /// Código DIVIPOLA del municipio evaluado (ej. `'20001'`).
  final String municipalityCode;

  /// Identificador de la zona del municipio donde se calculó la mediana (ej. `'vup_norte'`, `'vup_centro'`, `'vup_sur'`).
  final String zoneId;

  /// Nivel del veredicto (`green`, `yellow`, `red`, `insufficient`).
  final PriceVerdictLevel level;

  /// Monto consultado por el usuario en pesos colombianos (COP).
  final int submittedCop;

  /// Mediana estadística de referencia en la zona en COP (nulo cuando `isInsufficient` es `true`).
  final int? referenceCop;

  /// Desviación porcentual frente a la mediana de la zona (nulo cuando `isInsufficient` es `true`).
  final double? deviationPct;

  /// Tope recomendado (+15% sobre la mediana de la zona; nulo cuando `isInsufficient` es `true`).
  final int? recommendedCapCop;

  /// Tamaño de muestra comunitaria en la zona (cantidad de reportes válidos en la ventana).
  final int n;

  /// Alias semántico alineado con `sample_count` del contrato SQL.
  int get sampleCount => n;

  /// Ventana temporal en días de los reportes considerados (por defecto 60 días).
  final int windowDays;

  /// Contexto opcional de evento cuando existe temporada activa en el municipio.
  final PriceEventContext? eventContext;

  /// Alerta cuando el monto es sospechosamente bajo (`desviación < -40%`).
  final bool lowPriceWarning;

  /// Indica si el veredicto proviene de fixtures DEMO.
  final bool isDemo;

  /// Indica si la muestra es insuficiente (`n < 3` o `level == insufficient`).
  bool get isInsufficient => level == PriceVerdictLevel.insufficient;

  ///Construye y valida un `PriceVerdict` a partir del esquema JSON del contrato de datos.
  factory PriceVerdict.fromMap(
    Map<String, dynamic> map, {
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
  }) {
    final rawLevel = map['level'] as String?;
    if (rawLevel == null) {
      throw const FormatException('Missing level in PriceVerdict');
    }
    final level = PriceVerdictLevel.fromWire(rawLevel);
    final submitted = map['amount_cop'] as int?;
    if (submitted == null || submitted <= 0) {
      throw const FormatException('Invalid amount_cop in PriceVerdict');
    }
    final sampleCount = map['sample_count'] as int? ?? 0;
    if (sampleCount < 0) {
      throw const FormatException('Invalid sample_count in PriceVerdict');
    }

    final isInsufficient = level == PriceVerdictLevel.insufficient;
    final referenceCop = isInsufficient ? null : map['reference_cop'] as int?;
    final deviationPct = isInsufficient
        ? null
        : (map['deviation_percent'] as num?)?.toDouble();
    final recommendedCapCop =
        isInsufficient ? null : map['recommended_cap_cop'] as int?;

    if (!isInsufficient && (referenceCop == null || referenceCop <= 0 || deviationPct == null)) {
      throw const FormatException(
        'Non-insufficient PriceVerdict requires positive reference_cop and deviation_percent',
      );
    }

    final eventMap = map['event_details'] as Map<String, dynamic>?;
    final resolvedZoneId = map['zone_id'] as String? ?? zoneId;

    return PriceVerdict(
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: resolvedZoneId,
      level: level,
      submittedCop: submitted,
      referenceCop: referenceCop,
      deviationPct: deviationPct,
      recommendedCapCop: recommendedCapCop,
      n: sampleCount,
      windowDays: map['window_days'] as int? ?? 60,
      eventContext:
          eventMap != null ? PriceEventContext.fromMap(eventMap) : null,
      lowPriceWarning:
          !isInsufficient && (map['underpriced_alert'] as bool? ?? false),
      isDemo: map['is_demo'] as bool? ?? true,
    );
  }
}

/// Valida y convierte un texto de monto en COP a entero positivo.
/// Retorna `null` si está vacío, contiene caracteres no numéricos o es `<= 0`.
int? parseCopAmount(String rawInput) {
  final cleaned = rawInput.replaceAll(RegExp(r'[\s\.,\$]'), '');
  if (cleaned.isEmpty) return null;
  final parsed = int.tryParse(cleaned);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

/// Formatea un monto entero en pesos colombianos con separador de miles (ej. `$15.000 COP`).
String formatCop(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final sign = amount < 0 ? '-' : '';
  return '$sign\$${buffer.toString()} COP';
}

/// Formatea el porcentaje de desviación con signo explícito (ej. `+25.0%` o `-10.0%`).
String formatDeviationPct(double pct) {
  final rounded = pct.toStringAsFixed(1);
  if (pct > 0) {
    return '+$rounded%';
  }
  return '$rounded%';
}
