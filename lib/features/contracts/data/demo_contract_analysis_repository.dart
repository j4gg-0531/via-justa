import 'package:via_justa/features/contracts/data/demo_contract_analysis_gateway.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';

/// Implementación DEMO del repositorio de análisis de contratos con dos puntos de ejemplo en ES/EN.
class DemoContractAnalysisRepository implements ContractAnalysisRepository {
  const DemoContractAnalysisRepository({
    this.gateway = const DemoContractAnalysisGateway(),
  });

  final DemoContractAnalysisGateway gateway;

  static const ContractAnalysis demoSample = ContractAnalysis(
    id: 'demo-lease-valledupar-01',
    contractTypeEs: '[DEMO] Contrato de arrendamiento de vivienda urbana',
    contractTypeEn: '[DEMO] Urban residential lease agreement',
    isDemo: true,
    points: <ContractClausePoint>[
      ContractClausePoint(
        id: 'clause-1-ipc',
        titleEs: '1. Incremento anual sujeto al IPC (Estándar)',
        titleEn: '1. Annual rent increase tied to CPI (Standard)',
        explanationEs:
            'Ejemplo demostrativo: la cláusula indica que el canon solo sube una vez cumplido el año y hasta el límite del IPC certificado por el DANE.',
        explanationEn:
            'Demo example: the clause states that rent only increases after 12 months and up to the CPI limit certified by DANE.',
        attention: ContractClauseAttention.standard,
      ),
      ContractClausePoint(
        id: 'clause-2-penalty',
        titleEs: '2. Penalidad por terminación anticipada (Revisar antes de firmar)',
        titleEn: '2. Early termination penalty (Review before signing)',
        explanationEs:
            'Ejemplo demostrativo: exige pagar 3 cánones mensuales sin preaviso. Conviene acordar por escrito el plazo legal de preaviso antes de firmar.',
        explanationEn:
            'Demo example: requires paying 3 monthly rents upon early exit. Confirm the written notice period before signing.',
        attention: ContractClauseAttention.reviewRequired,
      ),
    ],
  );

  @override
  Future<ContractAnalysis> getDemoSampleAnalysis() async {
    return demoSample;
  }

  @override
  Future<ContractAnalysisResult> analyzeContract({
    required String text,
    required String locale,
  }) async {
    final raw = await gateway.analyzeContractRaw(
      text: text,
      locale: locale,
    );
    return ContractAnalysisResult.fromMap(raw, isDemo: true);
  }
}
