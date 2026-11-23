import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';

class ViaJustaApp extends ConsumerStatefulWidget {
  const ViaJustaApp({super.key});

  @override
  ConsumerState<ViaJustaApp> createState() => _ViaJustaAppState();
}

class _ViaJustaAppState extends ConsumerState<ViaJustaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final rawCode = locales != null && locales.isNotEmpty
        ? locales.first.languageCode
        : null;
    final code = resolveSupportedLocaleCode(rawCode);
    try {
      if (mounted && context.locale.languageCode != code) {
        context.setLocale(Locale(code));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
