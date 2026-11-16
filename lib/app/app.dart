import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_theme.dart';

class ViaJustaApp extends ConsumerWidget {
  const ViaJustaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Vía Justa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

/// Comportamiento de scroll global sin efecto elástico ni resplandor en bordes.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Se omite el indicador de overscroll (estiramiento/resplandor) para
    // mantener el scroll fluido sin deformar el contenido al llegar al límite.
    return child;
  }
}
