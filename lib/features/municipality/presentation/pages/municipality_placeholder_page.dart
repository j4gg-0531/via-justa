import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pantalla temporal para un municipio (Paso 5). El Paso 6 la reemplaza.
class MunicipalityPlaceholderPage extends StatelessWidget {
  const MunicipalityPlaceholderPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Text(
          'municipality.placeholder'.tr(namedArgs: {'code': code}),
        ),
      ),
    );
  }
}