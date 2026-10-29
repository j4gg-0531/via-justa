import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

void main() {
  group('ContractAnalysisLevel', () {
    test('parses green, yellow, and red case-insensitively and with surrounding whitespace', () {
      expect(ContractAnalysisLevel.fromString('green'), ContractAnalysisLevel.green);
      expect(ContractAnalysisLevel.fromString('GREEN '), ContractAnalysisLevel.green);
      expect(ContractAnalysisLevel.fromString('yellow'), ContractAnalysisLevel.yellow);
      expect(ContractAnalysisLevel.fromString(' Yellow'), ContractAnalysisLevel.yellow);
      expect(ContractAnalysisLevel.fromString('red'), ContractAnalysisLevel.red);
      expect(ContractAnalysisLevel.fromString(' RED '), ContractAnalysisLevel.red);
    });

    test('throws FormatException for null, empty or invalid level string', () {
      expect(() => ContractAnalysisLevel.fromString(null), throwsA(isA<FormatException>()));
      expect(() => ContractAnalysisLevel.fromString(''), throwsA(isA<FormatException>()));
      expect(() => ContractAnalysisLevel.fromString('   '), throwsA(isA<FormatException>()));
      expect(() => ContractAnalysisLevel.fromString('blue'), throwsA(isA<FormatException>()));
      expect(() => ContractAnalysisLevel.fromString('orange'), throwsA(isA<FormatException>()));
    });
  });

  group('ContractKeyPoint', () {
    test('parses valid map and trims text', () {
      final point = ContractKeyPoint.fromMap({
        'title': '  Monto del canon  ',
        'detail': r'  $1.200.000 COP mensual  ',
      });
      expect(point.title, 'Monto del canon');
      expect(point.detail, r'$1.200.000 COP mensual');
      expect(point.toMap(), {
        'title': 'Monto del canon',
        'detail': r'$1.200.000 COP mensual',
      });
    });

    test('throws FormatException when title or detail is missing, invalid or empty', () {
      expect(() => ContractKeyPoint.fromMap({'detail': 'ok'}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': '', 'detail': 'ok'}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': '   ', 'detail': 'ok'}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': 123, 'detail': 'ok'}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': 'ok'}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': 'ok', 'detail': ''}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': 'ok', 'detail': '   '}), throwsA(isA<FormatException>()));
      expect(() => ContractKeyPoint.fromMap({'title': 'ok', 'detail': null}), throwsA(isA<FormatException>()));
    });
  });

  group('ContractAnalyzedClause', () {
    test('parses clause with verified legal_reference', () {
      final clause = ContractAnalyzedClause.fromMap({
        'excerpt': '  Cláusula tercera: No reparaciones.  ',
        'issue': '  Obligación de mantenimiento legal vulnerada.  ',
        'recommendation': '  Exigir ajuste antes de firmar.  ',
        'legal_reference': '  Ley 820 de 2003, Art. 8  ',
      });
      expect(clause.excerpt, 'Cláusula tercera: No reparaciones.');
      expect(clause.issue, 'Obligación de mantenimiento legal vulnerada.');
      expect(clause.recommendation, 'Exigir ajuste antes de firmar.');
      expect(clause.legalReference, 'Ley 820 de 2003, Art. 8');
      expect(clause.toMap()['legal_reference'], 'Ley 820 de 2003, Art. 8');
    });

    test('preserves legal_reference as null when omitted, null or whitespace (rule: no invented laws)', () {
      final clauseNoRef = ContractAnalyzedClause.fromMap({
        'excerpt': 'El canon sube según decida el arrendador.',
        'issue': 'Incremento unilateral no estipulado.',
        'recommendation': 'Pactar ajuste según IPC.',
      });
      expect(clauseNoRef.legalReference, isNull);
      expect(clauseNoRef.toMap()['legal_reference'], isNull);

      final clauseNullRef = ContractAnalyzedClause.fromMap({
        'excerpt': 'El canon sube según decida el arrendador.',
        'issue': 'Incremento unilateral no estipulado.',
        'recommendation': 'Pactar ajuste según IPC.',
        'legal_reference': null,
      });
      expect(clauseNullRef.legalReference, isNull);

      final clauseWhitespaceRef = ContractAnalyzedClause.fromMap({
        'excerpt': 'El canon sube según decida el arrendador.',
        'issue': 'Incremento unilateral no estipulado.',
        'recommendation': 'Pactar ajuste según IPC.',
        'legal_reference': '    ',
      });
      expect(clauseWhitespaceRef.legalReference, isNull);
    });

    test('throws FormatException if legal_reference is not a string or null', () {
      expect(
        () => ContractAnalyzedClause.fromMap({
          'excerpt': 'Texto',
          'issue': 'Problema',
          'recommendation': 'Recomendación',
          'legal_reference': 12345,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when excerpt, issue or recommendation are empty or missing', () {
      expect(
        () => ContractAnalyzedClause.fromMap({
          'issue': 'Problema',
          'recommendation': 'Recomendación',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ContractAnalyzedClause.fromMap({
          'excerpt': '   ',
          'issue': 'Problema',
          'recommendation': 'Recomendación',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ContractAnalyzedClause.fromMap({
          'excerpt': 'Texto',
          'issue': '',
          'recommendation': 'Recomendación',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ContractAnalyzedClause.fromMap({
          'excerpt': 'Texto',
          'issue': 'Problema',
          'recommendation': '   ',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ContractAnalysisResult.fromMap', () {
    Map<String, dynamic> createSampleMap({
      String level = 'yellow',
      String generalRec = 'El contrato presenta condiciones aceptables con 1 punto a revisar.',
      List<dynamic>? keyPoints,
      List<dynamic>? clauses,
      String disclaimer = 'Análisis asistido por IA de carácter orientativo.',
      String locale = 'es',
    }) {
      return {
        'level': level,
        'general_recommendation': generalRec,
        'key_points': keyPoints ??
            [
              {'title': 'Canon de arrendamiento', 'detail': r'$950.000 COP mensuales'},
              {'title': 'Duración inicial', 'detail': '12 meses con prórroga automática'},
            ],
        'clauses': clauses ??
            [
              {
                'excerpt': 'No se autorizan mascotas ni visitas después de las 8 p.m.',
                'issue': 'Restricción desproporcionada sobre el uso privado del inmueble.',
                'recommendation': 'Negociar cláusula de convivencia acorde con la copropiedad.',
                'legal_reference': null,
              },
            ],
        'disclaimer': disclaimer,
        'locale': locale,
      };
    }

    test('deserializes complete valid response with level yellow and preserves isDemo flag', () {
      final map = createSampleMap();
      final result = ContractAnalysisResult.fromMap(map, isDemo: true);

      expect(result.level, ContractAnalysisLevel.yellow);
      expect(result.generalRecommendation, 'El contrato presenta condiciones aceptables con 1 punto a revisar.');
      expect(result.keyPoints.length, 2);
      expect(result.keyPoints.first.title, 'Canon de arrendamiento');
      expect(result.clauses.length, 1);
      expect(result.clauses.first.excerpt, 'No se autorizan mascotas ni visitas después de las 8 p.m.');
      expect(result.clauses.first.legalReference, isNull);
      expect(result.disclaimer, 'Análisis asistido por IA de carácter orientativo.');
      expect(result.locale, 'es');
      expect(result.isDemo, isTrue);
    });

    test('deserializes valid response with level green and level red', () {
      final greenResult = ContractAnalysisResult.fromMap(createSampleMap(level: 'green'));
      expect(greenResult.level, ContractAnalysisLevel.green);

      final redResult = ContractAnalysisResult.fromMap(createSampleMap(level: 'red'));
      expect(redResult.level, ContractAnalysisLevel.red);
    });

    test('supports language field as fallback for locale', () {
      final map = createSampleMap();
      map.remove('locale');
      map['language'] = 'en';

      final result = ContractAnalysisResult.fromMap(map);
      expect(result.locale, 'en');
    });

    test('serializes toMap and performs round-trip without loss', () {
      final original = ContractAnalysisResult.fromMap(createSampleMap());
      final map = original.toMap();
      final reconstructed = ContractAnalysisResult.fromMap(map);

      expect(reconstructed.level, original.level);
      expect(reconstructed.generalRecommendation, original.generalRecommendation);
      expect(reconstructed.keyPoints.length, original.keyPoints.length);
      expect(reconstructed.clauses.length, original.clauses.length);
      expect(reconstructed.disclaimer, original.disclaimer);
      expect(reconstructed.locale, original.locale);
    });

    test('throws FormatException if level is missing, invalid or not a string', () {
      final mapNoLevel = createSampleMap();
      mapNoLevel.remove('level');
      expect(() => ContractAnalysisResult.fromMap(mapNoLevel), throwsA(isA<FormatException>()));

      final mapInvalidLevel = createSampleMap(level: 'danger');
      expect(() => ContractAnalysisResult.fromMap(mapInvalidLevel), throwsA(isA<FormatException>()));

      final mapNumLevel = createSampleMap();
      mapNumLevel['level'] = 1;
      expect(() => ContractAnalysisResult.fromMap(mapNumLevel), throwsA(isA<FormatException>()));
    });

    test('throws FormatException if general_recommendation is missing or empty', () {
      final mapNoRec = createSampleMap();
      mapNoRec.remove('general_recommendation');
      expect(() => ContractAnalysisResult.fromMap(mapNoRec), throwsA(isA<FormatException>()));

      final mapEmptyRec = createSampleMap(generalRec: '    ');
      expect(() => ContractAnalysisResult.fromMap(mapEmptyRec), throwsA(isA<FormatException>()));
    });

    test('throws FormatException if key_points is not a list or exceeds maxContractKeyPoints', () {
      final mapNotList = createSampleMap();
      mapNotList['key_points'] = 'no es lista';
      expect(() => ContractAnalysisResult.fromMap(mapNotList), throwsA(isA<FormatException>()));

      final oversizedKeyPoints = List.generate(
        maxContractKeyPoints + 1,
        (i) => {'title': 'Punto $i', 'detail': 'Detalle $i'},
      );
      final mapOversized = createSampleMap(keyPoints: oversizedKeyPoints);
      expect(() => ContractAnalysisResult.fromMap(mapOversized), throwsA(isA<FormatException>()));
    });

    test('throws FormatException if a key_point is not a map or has invalid fields', () {
      final mapInvalidItem = createSampleMap(keyPoints: ['cadena']);
      expect(() => ContractAnalysisResult.fromMap(mapInvalidItem), throwsA(isA<FormatException>()));

      final mapEmptyField = createSampleMap(keyPoints: [{'title': '   ', 'detail': 'Detalle'}]);
      expect(() => ContractAnalysisResult.fromMap(mapEmptyField), throwsA(isA<FormatException>()));
    });

    test('throws FormatException if clauses is not a list or exceeds maxContractAnalyzedClauses', () {
      final mapNotList = createSampleMap();
      mapNotList['clauses'] = 123;
      expect(() => ContractAnalysisResult.fromMap(mapNotList), throwsA(isA<FormatException>()));

      final oversizedClauses = List.generate(
        maxContractAnalyzedClauses + 1,
        (i) => {
          'excerpt': 'Extracto $i',
          'issue': 'Problema $i',
          'recommendation': 'Recomendación $i',
        },
      );
      final mapOversized = createSampleMap(clauses: oversizedClauses);
      expect(() => ContractAnalysisResult.fromMap(mapOversized), throwsA(isA<FormatException>()));
    });

    test('throws FormatException if disclaimer or locale are missing or empty', () {
      final mapNoDisclaimer = createSampleMap();
      mapNoDisclaimer.remove('disclaimer');
      expect(() => ContractAnalysisResult.fromMap(mapNoDisclaimer), throwsA(isA<FormatException>()));

      final mapEmptyDisclaimer = createSampleMap(disclaimer: '   ');
      expect(() => ContractAnalysisResult.fromMap(mapEmptyDisclaimer), throwsA(isA<FormatException>()));

      final mapNoLocale = createSampleMap();
      mapNoLocale.remove('locale');
      expect(() => ContractAnalysisResult.fromMap(mapNoLocale), throwsA(isA<FormatException>()));

      final mapEmptyLocale = createSampleMap(locale: '   ');
      expect(() => ContractAnalysisResult.fromMap(mapEmptyLocale), throwsA(isA<FormatException>()));
    });
  });

  group('ContractAnalysisError and ContractAnalysisException', () {
    test('resolves error codes from wire code strings (§4.5)', () {
      expect(ContractAnalysisError.fromCode('AUTH_UNAUTHORIZED'), ContractAnalysisError.authUnauthorized);
      expect(ContractAnalysisError.fromCode('INVALID_INPUT_EMPTY'), ContractAnalysisError.invalidInputEmpty);
      expect(ContractAnalysisError.fromCode('TEXT_TOO_LONG'), ContractAnalysisError.textTooLong);
      expect(ContractAnalysisError.fromCode('AI_DAILY_LIMIT_EXCEEDED'), ContractAnalysisError.aiDailyLimitExceeded);
      expect(ContractAnalysisError.fromCode('AI_SERVICE_UNAVAILABLE'), ContractAnalysisError.aiServiceUnavailable);
      expect(ContractAnalysisError.fromCode('NETWORK_UNAVAILABLE'), ContractAnalysisError.networkUnavailable);
      expect(ContractAnalysisError.fromCode('TIMEOUT'), ContractAnalysisError.timeout);
      expect(ContractAnalysisError.fromCode('AI_RESPONSE_INVALID'), ContractAnalysisError.aiResponseInvalid);
      expect(ContractAnalysisError.fromCode('UNKNOWN_CODE'), ContractAnalysisError.aiResponseInvalid);
      expect(ContractAnalysisError.fromCode(null), ContractAnalysisError.aiResponseInvalid);
    });

    test('maps HTTP status codes to typed ContractAnalysisError (§4.5)', () {
      expect(ContractAnalysisError.fromHttpStatusCode(401), ContractAnalysisError.authUnauthorized);
      expect(ContractAnalysisError.fromHttpStatusCode(403), ContractAnalysisError.authUnauthorized);
      expect(ContractAnalysisError.fromHttpStatusCode(400), ContractAnalysisError.invalidInputEmpty);
      expect(ContractAnalysisError.fromHttpStatusCode(422), ContractAnalysisError.invalidInputEmpty);
      expect(ContractAnalysisError.fromHttpStatusCode(413), ContractAnalysisError.textTooLong);
      expect(ContractAnalysisError.fromHttpStatusCode(429), ContractAnalysisError.aiDailyLimitExceeded);
      expect(ContractAnalysisError.fromHttpStatusCode(502), ContractAnalysisError.aiServiceUnavailable);
      expect(ContractAnalysisError.fromHttpStatusCode(503), ContractAnalysisError.aiServiceUnavailable);
      expect(ContractAnalysisError.fromHttpStatusCode(504), ContractAnalysisError.aiServiceUnavailable);
      expect(ContractAnalysisError.fromHttpStatusCode(500), ContractAnalysisError.aiServiceUnavailable);
    });

    test('ContractAnalysisException formats message cleanly without leaking sensitive text', () {
      const ex1 = ContractAnalysisException(ContractAnalysisError.authUnauthorized);
      expect(ex1.toString(), 'ContractAnalysisException(AUTH_UNAUTHORIZED)');

      const ex2 = ContractAnalysisException(
        ContractAnalysisError.aiDailyLimitExceeded,
        'Límite diario alcanzado',
      );
      expect(ex2.toString(), 'ContractAnalysisException(AI_DAILY_LIMIT_EXCEEDED: Límite diario alcanzado)');
    });
  });
}
