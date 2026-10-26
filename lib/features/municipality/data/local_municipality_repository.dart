// DATOS DE EJEMPLO locales; se reemplaza por Supabase en la semana 2.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/core/utils/text_normalizer.dart';

class LocalMunicipalityRepository implements MunicipalityRepository {
  LocalMunicipalityRepository({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async {
    if (departmentCode != '20') {
      return <Municipality>[];
    }

    final jsonString = await _assetBundle.loadString(
      'assets/data/municipalities_cesar.json',
    );

    if (jsonString.isEmpty) {
      return <Municipality>[];
    }

    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    final municipalities = jsonList
        .map((e) => Municipality(
              code: e['code'] as String,
              name: e['name'] as String,
              departmentCode: '20',
              isPilot: e['isPilot'] as bool? ?? false,
            ))
        .toList();

    // Ordenar: primero el piloto, luego por nombre normalizado
    municipalities.sort((a, b) {
      if (a.isPilot != b.isPilot) {
        return a.isPilot ? -1 : 1;
      }
      return normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name));
    });

    return municipalities;
  }
}