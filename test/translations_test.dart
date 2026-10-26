import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Translations parity', () {
    late Map<String, dynamic> esJson;
    late Map<String, dynamic> enJson;
    late Map<String, dynamic> esFlat;
    late Map<String, dynamic> enFlat;

    setUpAll(() {
      final esFile = File('assets/translations/es.json');
      final enFile = File('assets/translations/en.json');

      esJson = json.decode(esFile.readAsStringSync()) as Map<String, dynamic>;
      enJson = json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;

      esFlat = _flattenJson(esJson);
      enFlat = _flattenJson(enJson);
    });

    test('es.json and en.json have exactly the same keys', () {
      final missingInEn = esFlat.keys.where((k) => !enFlat.containsKey(k)).toList();
      final missingInEs = enFlat.keys.where((k) => !esFlat.containsKey(k)).toList();

      expect(
        missingInEn,
        isEmpty,
        reason: 'Keys present in es.json but missing in en.json: $missingInEn',
      );
      expect(
        missingInEs,
        isEmpty,
        reason: 'Keys present in en.json but missing in es.json: $missingInEs',
      );
    });
  });
}

Map<String, dynamic> _flattenJson(Map<String, dynamic> json, [String prefix = '']) {
  final result = <String, dynamic>{};
  json.forEach((key, value) {
    final newKey = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      result.addAll(_flattenJson(value, newKey));
    } else {
      result[newKey] = value;
    }
  });
  return result;
}