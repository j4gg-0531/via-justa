import 'package:via_justa/features/contracts/domain/contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Escenarios simulados disponibles en el gateway de demostración para `VJ-14`.
enum DemoContractAnalysisScenario {
  /// Contrato estándar sin cláusulas de alto riesgo (verde).
  successGreen,

  /// Contrato con observaciones habituales a revisar antes de firmar (amarillo).
  successYellow,

  /// Contrato con cláusulas potencialmente abusivas de alto riesgo (rojo).
  successRed,

  /// Sesión no iniciada o token inválido (HTTP 401).
  errorAuthUnauthorized,

  /// Texto extraído vacío o ilegible (HTTP 400).
  errorInvalidInputEmpty,

  /// Texto superior al límite permitido de 15.000 caracteres (HTTP 413).
  errorTextTooLong,

  /// Cuota diaria agotada (HTTP 429).
  errorAiDailyLimitExceeded,

  /// Falla o indisponibilidad temporal del servicio LLM / Edge Function (HTTP 502).
  errorAiServiceUnavailable,

  /// Sin conexión a Internet en el dispositivo.
  errorNetworkUnavailable,

  /// Tiempo de espera agotado sin respuesta del servidor.
  errorTimeout,

  /// Respuesta del servicio que no cumple el esquema JSON esperado.
  errorAiResponseInvalid,
}

/// Implementación DEMO de [ContractAnalysisGateway] para pruebas y modo sin backend.
///
/// Todas las respuestas de éxito están explícitamente rotuladas como `[DEMO]` y
/// cumplen estrictamente el esquema §4.4 de `docs/contrato-datos-v1.md`.
class DemoContractAnalysisGateway implements ContractAnalysisGateway {
  const DemoContractAnalysisGateway({
    this.scenario = DemoContractAnalysisScenario.successYellow,
    this.simulatedLatency = Duration.zero,
  });

  /// Escenario activo que simulará el gateway.
  final DemoContractAnalysisScenario scenario;

  /// Latencia artificial opcional para pruebas de asincronía y cancelación.
  final Duration simulatedLatency;

  @override
  Future<Map<String, dynamic>> analyzeContractRaw({
    required String text,
    required String locale,
  }) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }

    // Detecta banderas de simulación embebidas en el texto para pruebas flexibles
    final effectiveScenario = _resolveScenario(text) ?? scenario;

    switch (effectiveScenario) {
      case DemoContractAnalysisScenario.successGreen:
        return _buildGreenResponse(locale);
      case DemoContractAnalysisScenario.successYellow:
        return _buildYellowResponse(locale);
      case DemoContractAnalysisScenario.successRed:
        return _buildRedResponse(locale);
      case DemoContractAnalysisScenario.errorAuthUnauthorized:
        throw const ContractAnalysisException(
          ContractAnalysisError.authUnauthorized,
          'Sesión requerida para analizar documentos',
        );
      case DemoContractAnalysisScenario.errorInvalidInputEmpty:
        throw const ContractAnalysisException(
          ContractAnalysisError.invalidInputEmpty,
          'El documento no contiene texto legible',
        );
      case DemoContractAnalysisScenario.errorTextTooLong:
        throw const ContractAnalysisException(
          ContractAnalysisError.textTooLong,
          'El texto supera el tamaño máximo permitido de 15.000 caracteres',
        );
      case DemoContractAnalysisScenario.errorAiDailyLimitExceeded:
        throw const ContractAnalysisException(
          ContractAnalysisError.aiDailyLimitExceeded,
          'Has alcanzado el límite diario de análisis de contratos',
        );
      case DemoContractAnalysisScenario.errorAiServiceUnavailable:
        throw const ContractAnalysisException(
          ContractAnalysisError.aiServiceUnavailable,
          'El servicio de análisis no está disponible temporalmente',
        );
      case DemoContractAnalysisScenario.errorNetworkUnavailable:
        throw const ContractAnalysisException(
          ContractAnalysisError.networkUnavailable,
          'Sin conexión de red',
        );
      case DemoContractAnalysisScenario.errorTimeout:
        throw const ContractAnalysisException(
          ContractAnalysisError.timeout,
          'La solicitud superó el tiempo máximo de espera',
        );
      case DemoContractAnalysisScenario.errorAiResponseInvalid:
        // Retorna un mapa sin los campos requeridos para verificar el rechazo en fromMap
        return <String, dynamic>{
          'invalid_field': true,
          'level': 'purple_unknown',
        };
    }
  }

  DemoContractAnalysisScenario? _resolveScenario(String text) {
    if (text.contains('#demo:green')) return DemoContractAnalysisScenario.successGreen;
    if (text.contains('#demo:yellow')) return DemoContractAnalysisScenario.successYellow;
    if (text.contains('#demo:red')) return DemoContractAnalysisScenario.successRed;
    if (text.contains('#demo:auth_error')) return DemoContractAnalysisScenario.errorAuthUnauthorized;
    if (text.contains('#demo:empty_error')) return DemoContractAnalysisScenario.errorInvalidInputEmpty;
    if (text.contains('#demo:long_error')) return DemoContractAnalysisScenario.errorTextTooLong;
    if (text.contains('#demo:limit_error')) return DemoContractAnalysisScenario.errorAiDailyLimitExceeded;
    if (text.contains('#demo:service_error')) return DemoContractAnalysisScenario.errorAiServiceUnavailable;
    if (text.contains('#demo:network_error')) return DemoContractAnalysisScenario.errorNetworkUnavailable;
    if (text.contains('#demo:timeout_error')) return DemoContractAnalysisScenario.errorTimeout;
    if (text.contains('#demo:invalid_json')) return DemoContractAnalysisScenario.errorAiResponseInvalid;

    // Reconocimiento inteligente de los 3 contratos sintéticos de prueba
    final lower = text.toLowerCase();
    if (lower.contains('mantenimiento preventivo') ||
        lower.contains('preventive maintenance') ||
        lower.contains('servicios locales')) {
      return DemoContractAnalysisScenario.successGreen;
    }
    if (lower.contains('reajuste semestral') ||
        lower.contains('semi-annual increase') ||
        lower.contains('tres (3) cánones') ||
        lower.contains('three (3) monthly rents')) {
      return DemoContractAnalysisScenario.successRed;
    }
    if (lower.contains('depósito en efectivo') ||
        lower.contains('deposito en efectivo') ||
        lower.contains('cash security deposit')) {
      return DemoContractAnalysisScenario.successYellow;
    }

    return null;
  }

  Map<String, dynamic> _buildGreenResponse(String locale) {
    final isEn = locale.toLowerCase().startsWith('en');
    return <String, dynamic>{
      'level': 'green',
      'general_recommendation': isEn
          ? '[DEMO] The lease contract is balanced and complies with standard tenancy regulations in Colombia.'
          : '[DEMO] El contrato de arrendamiento es balanceado y cumple con las condiciones estándar de vivienda urbana.',
      'key_points': <Map<String, dynamic>>[
        {
          'title': isEn ? '[DEMO] Monthly Rent' : '[DEMO] Canon de Arrendamiento',
          'detail': isEn
              ? 'Agreed at \$950,000 COP with annual increase tied to official CPI.'
              : 'Pactado en \$950.000 COP con incremento anual según el IPC certificado por el DANE.',
        },
        {
          'title': isEn ? '[DEMO] Initial Term' : '[DEMO] Vigencia Inicial',
          'detail': isEn
              ? '12 months with mutual 3-month written notice for non-renewal.'
              : '12 meses con preaviso mutuo por escrito de 3 meses para terminación.',
        },
      ],
      'clauses': <Map<String, dynamic>>[
        {
          'excerpt': isEn
              ? 'Maintenance for normal wear and tear corresponds to the landlord.'
              : 'Las reparaciones locativas por desgaste natural corresponden al arrendador.',
          'issue': isEn
              ? 'Balanced allocation of property maintenance duties.'
              : 'Distribución equilibrada y conforme a la ley sobre el mantenimiento del inmueble.',
          'legal_reference': 'Ley 820 de 2003, Artículo 8',
          'recommendation': isEn
              ? 'Retain written receipts for all routine maintenance performed.'
              : 'Conservar comprobantes escritos de cualquier arreglo acordado.',
        },
      ],
      'disclaimer': isEn
          ? '[DEMO] This analysis is assisted by artificial intelligence for educational and guidance purposes only. It does not replace professional legal advice.'
          : '[DEMO] El presente análisis es asistido por inteligencia artificial con fines pedagógicos y orientativos. No sustituye la asesoría jurídica profesional.',
      'locale': isEn ? 'en' : 'es',
    };
  }

  Map<String, dynamic> _buildYellowResponse(String locale) {
    final isEn = locale.toLowerCase().startsWith('en');
    return <String, dynamic>{
      'level': 'yellow',
      'general_recommendation': isEn
          ? '[DEMO] The contract is generally acceptable but contains 1 clause that warrants clarification before signing.'
          : '[DEMO] El contrato presenta condiciones generales aceptables con 1 punto que requiere aclaración previa antes de firmar.',
      'key_points': <Map<String, dynamic>>[
        {
          'title': isEn ? '[DEMO] Deposit and Guarantee' : '[DEMO] Depósito y Garantías',
          'detail': isEn
              ? 'A 2-month security deposit is requested in advance.'
              : 'Se solicita un depósito en efectivo equivalente a dos cánones mensuales.',
        },
        {
          'title': isEn ? '[DEMO] Utility Services' : '[DEMO] Servicios Públicos',
          'detail': isEn
              ? 'Tenant is responsible for water, power, and gas during the lease term.'
              : 'Los servicios de agua, energía y gas corren por cuenta del arrendatario.',
        },
      ],
      'clauses': <Map<String, dynamic>>[
        {
          'excerpt': isEn
              ? 'Tenant must provide a 6-month advance notice to terminate the lease.'
              : 'El arrendatario deberá notificar con 6 meses de anticipación su intención de no renovar.',
          'issue': isEn
              ? 'The required notice period exceeds the standard 3-month legal timeframe.'
              : 'El preaviso exigido supera el plazo legal estándar de 3 meses estipulado para vivienda urbana.',
          'legal_reference': 'Ley 820 de 2003, Artículo 24',
          'recommendation': isEn
              ? 'Request adjusting the notice window to the standard 3-month term before signing.'
              : 'Solicitar que el preaviso se ajuste a los 3 meses legales antes de suscribir el contrato.',
        },
      ],
      'disclaimer': isEn
          ? '[DEMO] This analysis is assisted by artificial intelligence for educational and guidance purposes only. It does not replace professional legal advice.'
          : '[DEMO] El presente análisis es asistido por inteligencia artificial con fines pedagógicos y orientativos. No sustituye la asesoría jurídica profesional.',
      'locale': isEn ? 'en' : 'es',
    };
  }

  Map<String, dynamic> _buildRedResponse(String locale) {
    final isEn = locale.toLowerCase().startsWith('en');
    return <String, dynamic>{
      'level': 'red',
      'general_recommendation': isEn
          ? '[DEMO] Warning: The contract contains potentially abusive clauses that disproportionately waive tenant rights.'
          : '[DEMO] Alerta: El contrato contiene cláusulas desproporcionadas o potencialmente abusivas que vulneran derechos del arrendatario.',
      'key_points': <Map<String, dynamic>>[
        {
          'title': isEn ? '[DEMO] Rent Adjustments' : '[DEMO] Reajuste del Canon',
          'detail': isEn
              ? 'Landlord reserves unilateral right to increase rent by 25% at any time.'
              : 'El arrendador se reserva la facultad de reajustar el canon unilateralmente en un 25% en cualquier momento.',
        },
        {
          'title': isEn ? '[DEMO] Dispute Resolution' : '[DEMO] Resolución de Conflictos',
          'detail': isEn
              ? 'Waives judicial recourse and mandates costly private arbitration.'
              : 'Renuncia expresa a la vía judicial ordinaria e impone arbitraje privado con costos a cargo del arrendatario.',
        },
      ],
      'clauses': <Map<String, dynamic>>[
        {
          'excerpt': isEn
              ? 'The tenant renounces any right to claim compensation for structural defects or damages.'
              : 'El arrendatario renuncia a exigir indemnización por vicios ocultos o reparaciones estructurales del inmueble.',
          'issue': isEn
              ? 'Potentially abusive clause that transfers landlord structural obligations exclusively to the tenant.'
              : 'Cláusula presuntamente ineficaz que traslada al arrendatario la responsabilidad de daños estructurales propios del inmueble.',
          'legal_reference': 'Ley 820 de 2003, Artículo 8',
          'recommendation': isEn
              ? 'Do not sign with this clause included; request immediate removal or legal review.'
              : 'No firmar con esta disposición incluida; exigir su eliminación o consultar asesoría profesional.',
        },
        {
          'excerpt': isEn
              ? 'Immediate eviction without court process upon any alleged minor breach.'
              : 'Desalojo inmediato sin trámite judicial ante cualquier retraso de un día en el pago.',
          'issue': isEn
              ? 'Arbitrary eviction clause without due legal process.'
              : 'Vulnera el debido proceso y los procedimientos legales de restitución de inmueble.',
          'legal_reference': null, // Regla de integridad: sin referencia legal inventada
          'recommendation': isEn
              ? 'Reject this clause completely as it violates fundamental rights.'
              : 'Rechazar esta cláusula en su totalidad por vulnerar garantías mínimas de defensa.',
        },
      ],
      'disclaimer': isEn
          ? '[DEMO] This analysis is assisted by artificial intelligence for educational and guidance purposes only. It does not replace professional legal advice.'
          : '[DEMO] El presente análisis es asistido por inteligencia artificial con fines pedagógicos y orientativos. No sustituye la asesoría jurídica profesional.',
      'locale': isEn ? 'en' : 'es',
    };
  }
}
