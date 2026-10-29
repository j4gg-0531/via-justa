/// Niveles de semáforo de riesgo para un contrato analizado (§4.4 de `docs/contrato-datos-v1.md`).
enum ContractAnalysisLevel {
  /// Contrato estándar y balanceado; condiciones habituales sin alertas críticas.
  green('green'),

  /// Contrato con puntos de atención que requieren aclaración o negociación previa.
  yellow('yellow'),

  /// Contrato con cláusulas potencialmente abusivas, desproporcionadas o de alto riesgo.
  red('red');

  const ContractAnalysisLevel(this.wireValue);

  /// Valor serializado en el esquema JSON retornado por Gemini / Edge Function.
  final String wireValue;

  /// Parsea el nivel a partir de la cadena JSON estricta (`green`, `yellow`, `red`).
  /// Lanza [FormatException] si el valor es nulo o desconocido.
  static ContractAnalysisLevel fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      throw const FormatException('El nivel de riesgo del contrato es obligatorio.');
    }
    final normalized = value.trim().toLowerCase();
    for (final level in ContractAnalysisLevel.values) {
      if (level.wireValue == normalized) {
        return level;
      }
    }
    throw FormatException(
      'Nivel de riesgo inválido: "$value". Se esperaba "green", "yellow" o "red".',
    );
  }
}

/// Punto clave descriptivo extraído del contrato (canon, plazos, prórroga, etc.).
class ContractKeyPoint {
  const ContractKeyPoint({
    required this.title,
    required this.detail,
  });

  /// Título conciso del aspecto identificado (p. ej. "Monto y canon de arriendo").
  final String title;

  /// Detalle explicativo de la condición pactada.
  final String detail;

  /// Deserializa un punto clave desde un mapa JSON con validación estricta de tipos y no vacíos.
  factory ContractKeyPoint.fromMap(Map<String, dynamic> map) {
    final rawTitle = map['title'];
    if (rawTitle is! String || rawTitle.trim().isEmpty) {
      throw const FormatException(
        'Cada punto clave (key_point) debe tener un "title" no vacío.',
      );
    }

    final rawDetail = map['detail'];
    if (rawDetail is! String || rawDetail.trim().isEmpty) {
      throw const FormatException(
        'Cada punto clave (key_point) debe tener un "detail" no vacío.',
      );
    }

    return ContractKeyPoint(
      title: rawTitle.trim(),
      detail: rawDetail.trim(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'title': title,
    'detail': detail,
  };
}

/// Cláusula específica del contrato identificada con observaciones o advertencias.
class ContractAnalyzedClause {
  const ContractAnalyzedClause({
    required this.excerpt,
    required this.issue,
    required this.recommendation,
    this.legalReference,
  });

  /// Fragmento literal citado del contrato que suscita la observación.
  final String excerpt;

  /// Explicación del motivo de alerta o potencial abuso en lenguaje sencillo.
  final String issue;

  /// Recomendación práctica y orientativa para el usuario antes de firmar.
  final String recommendation;

  /// Cita legal verificada si aplica; `null` si no existe o no pudo contrastarse.
  /// **Regla de integridad:** no se inventan referencias legales; si no es certera queda `null`.
  final String? legalReference;

  /// Deserializa una cláusula con validación estricta; `legal_reference` es opcional/nullable.
  factory ContractAnalyzedClause.fromMap(Map<String, dynamic> map) {
    final rawExcerpt = map['excerpt'];
    if (rawExcerpt is! String || rawExcerpt.trim().isEmpty) {
      throw const FormatException(
        'Cada cláusula analizada debe incluir un "excerpt" no vacío.',
      );
    }

    final rawIssue = map['issue'];
    if (rawIssue is! String || rawIssue.trim().isEmpty) {
      throw const FormatException(
        'Cada cláusula analizada debe incluir un "issue" no vacío.',
      );
    }

    final rawRecommendation = map['recommendation'];
    if (rawRecommendation is! String || rawRecommendation.trim().isEmpty) {
      throw const FormatException(
        'Cada cláusula analizada debe incluir una "recommendation" no vacía.',
      );
    }

    final rawLegalRef = map['legal_reference'];
    final String? legalRef;
    if (rawLegalRef == null) {
      legalRef = null;
    } else if (rawLegalRef is String) {
      final trimmed = rawLegalRef.trim();
      legalRef = trimmed.isEmpty ? null : trimmed;
    } else {
      throw const FormatException(
        'El campo "legal_reference" debe ser una cadena o null.',
      );
    }

    return ContractAnalyzedClause(
      excerpt: rawExcerpt.trim(),
      issue: rawIssue.trim(),
      recommendation: rawRecommendation.trim(),
      legalReference: legalRef,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'excerpt': excerpt,
    'issue': issue,
    'recommendation': recommendation,
    'legal_reference': legalReference,
  };
}

/// Límite máximo de puntos clave permitidos por contrato analizado.
const int maxContractKeyPoints = 10;

/// Límite máximo de cláusulas analizadas permitidas por contrato.
const int maxContractAnalyzedClauses = 20;

/// Resultado estructurado del análisis de un contrato mediante IA (§4.4 de `docs/contrato-datos-v1.md`).
class ContractAnalysisResult {
  const ContractAnalysisResult({
    required this.level,
    required this.generalRecommendation,
    required this.keyPoints,
    required this.clauses,
    required this.disclaimer,
    required this.locale,
    this.isDemo = false,
  });

  /// Nivel general del semáforo asignado al contrato (`green`, `yellow`, `red`).
  final ContractAnalysisLevel level;

  /// Resumen ejecutivo y recomendación general en lenguaje claro.
  final String generalRecommendation;

  /// Aspectos contractuales clave destacados (canon, duración, garantías, etc.).
  final List<ContractKeyPoint> keyPoints;

  /// Cláusulas observadas con su fragmento, problema y recomendación.
  final List<ContractAnalyzedClause> clauses;

  /// Aviso legal obligatorio: orientativo, no vinculante, no sustituye asesoría jurídica.
  final String disclaimer;

  /// Código de idioma de la respuesta (`es` o `en`).
  final String locale;

  /// Indica si el análisis proviene de un gateway de demostración sin procesamiento real.
  final bool isDemo;

  /// Deserializa estrictamente el mapa retornado por el servicio de análisis de contratos.
  /// Lanza [FormatException] ante campos faltantes, tipos inválidos, listas fuera de límites
  /// o textos en blanco.
  factory ContractAnalysisResult.fromMap(
    Map<String, dynamic> map, {
    bool isDemo = false,
  }) {
    // 1. Nivel de riesgo
    final rawLevel = map['level'];
    if (rawLevel is! String) {
      throw const FormatException(
        'El campo "level" es obligatorio y debe ser una cadena ("green", "yellow", "red").',
      );
    }
    final level = ContractAnalysisLevel.fromString(rawLevel);

    // 2. Recomendación general
    final rawGeneralRec = map['general_recommendation'];
    if (rawGeneralRec is! String || rawGeneralRec.trim().isEmpty) {
      throw const FormatException(
        'El campo "general_recommendation" es obligatorio y no puede estar vacío.',
      );
    }

    // 3. Puntos clave (key_points)
    final rawKeyPoints = map['key_points'];
    if (rawKeyPoints is! List) {
      throw const FormatException(
        'El campo "key_points" es obligatorio y debe ser una lista.',
      );
    }
    if (rawKeyPoints.length > maxContractKeyPoints) {
      throw FormatException(
        'La lista "key_points" contiene ${rawKeyPoints.length} elementos; el máximo permitido es $maxContractKeyPoints.',
      );
    }
    final keyPoints = <ContractKeyPoint>[];
    for (var i = 0; i < rawKeyPoints.length; i++) {
      final item = rawKeyPoints[i];
      if (item is! Map<String, dynamic>) {
        if (item is Map) {
          keyPoints.add(ContractKeyPoint.fromMap(Map<String, dynamic>.from(item)));
          continue;
        }
        throw FormatException(
          'El elemento $i de "key_points" debe ser un objeto JSON (Map).',
        );
      }
      keyPoints.add(ContractKeyPoint.fromMap(item));
    }

    // 4. Cláusulas analizadas (clauses)
    final rawClauses = map['clauses'];
    if (rawClauses is! List) {
      throw const FormatException(
        'El campo "clauses" es obligatorio y debe ser una lista.',
      );
    }
    if (rawClauses.length > maxContractAnalyzedClauses) {
      throw FormatException(
        'La lista "clauses" contiene ${rawClauses.length} elementos; el máximo permitido es $maxContractAnalyzedClauses.',
      );
    }
    final clauses = <ContractAnalyzedClause>[];
    for (var i = 0; i < rawClauses.length; i++) {
      final item = rawClauses[i];
      if (item is! Map<String, dynamic>) {
        if (item is Map) {
          clauses.add(ContractAnalyzedClause.fromMap(Map<String, dynamic>.from(item)));
          continue;
        }
        throw FormatException(
          'El elemento $i de "clauses" debe ser un objeto JSON (Map).',
        );
      }
      clauses.add(ContractAnalyzedClause.fromMap(item));
    }

    // 5. Aviso de descargo de responsabilidad (disclaimer)
    final rawDisclaimer = map['disclaimer'];
    if (rawDisclaimer is! String || rawDisclaimer.trim().isEmpty) {
      throw const FormatException(
        'El campo "disclaimer" es obligatorio y no puede estar vacío.',
      );
    }

    // 6. Idioma/locale
    final rawLocale = map['locale'] ?? map['language'];
    if (rawLocale is! String || rawLocale.trim().isEmpty) {
      throw const FormatException(
        'El campo "locale" es obligatorio y no puede estar vacío.',
      );
    }

    return ContractAnalysisResult(
      level: level,
      generalRecommendation: rawGeneralRec.trim(),
      keyPoints: List<ContractKeyPoint>.unmodifiable(keyPoints),
      clauses: List<ContractAnalyzedClause>.unmodifiable(clauses),
      disclaimer: rawDisclaimer.trim(),
      locale: rawLocale.trim().toLowerCase(),
      isDemo: isDemo,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'level': level.wireValue,
    'general_recommendation': generalRecommendation,
    'key_points': keyPoints.map((k) => k.toMap()).toList(),
    'clauses': clauses.map((c) => c.toMap()).toList(),
    'disclaimer': disclaimer,
    'locale': locale,
  };
}

/// Errores tipados del análisis de contratos (§4.5 de `docs/contrato-datos-v1.md` y fallos de infraestructura).
enum ContractAnalysisError {
  /// Sesión requerida para analizar documentos (HTTP 401).
  authUnauthorized('AUTH_UNAUTHORIZED'),

  /// El documento no contiene texto legible (HTTP 400).
  invalidInputEmpty('INVALID_INPUT_EMPTY'),

  /// El texto supera el límite permitido de 15.000 caracteres (HTTP 413).
  textTooLong('TEXT_TOO_LONG'),

  /// Se alcanzó el límite diario de análisis de contratos (HTTP 429).
  aiDailyLimitExceeded('AI_DAILY_LIMIT_EXCEEDED'),

  /// El servicio de análisis o la Edge Function no está disponible (HTTP 502/503/504).
  aiServiceUnavailable('AI_SERVICE_UNAVAILABLE'),

  /// No hay conexión de red disponible en el dispositivo móvil.
  networkUnavailable('NETWORK_UNAVAILABLE'),

  /// La solicitud superó el tiempo máximo de espera sin respuesta del servidor.
  timeout('TIMEOUT'),

  /// La respuesta recibida no cumple con el esquema JSON o contiene campos corruptos.
  aiResponseInvalid('AI_RESPONSE_INVALID');

  const ContractAnalysisError(this.code);

  /// Código de error estándar para identificación y telemetría interna.
  final String code;

  /// Resuelve el error a partir de un código textual devuelto por la Edge Function.
  static ContractAnalysisError fromCode(String? code) {
    if (code == null) return ContractAnalysisError.aiResponseInvalid;
    final normalized = code.trim().toUpperCase();
    for (final err in ContractAnalysisError.values) {
      if (err.code == normalized) {
        return err;
      }
    }
    return ContractAnalysisError.aiResponseInvalid;
  }

  /// Mapea códigos de estado HTTP comunes a errores tipados de análisis.
  static ContractAnalysisError fromHttpStatusCode(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return ContractAnalysisError.authUnauthorized;
      case 400:
      case 422:
        return ContractAnalysisError.invalidInputEmpty;
      case 413:
        return ContractAnalysisError.textTooLong;
      case 429:
        return ContractAnalysisError.aiDailyLimitExceeded;
      case 502:
      case 503:
      case 504:
        return ContractAnalysisError.aiServiceUnavailable;
      default:
        return ContractAnalysisError.aiServiceUnavailable;
    }
  }
}

/// Excepción tipada para fallos durante el flujo de análisis de contratos.
class ContractAnalysisException implements Exception {
  const ContractAnalysisException(this.error, [this.message]);

  /// Error tipado de la operación.
  final ContractAnalysisError error;

  /// Mensaje técnico opcional para depuración (sin exponer secretos ni texto íntegro).
  final String? message;

  @override
  String toString() =>
      'ContractAnalysisException(${error.code}${message != null ? ': $message' : ''})';
}
