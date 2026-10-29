import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

/// Pantalla de splash con logo y animación de entrada.
/// La redirección hacia `/welcome`, `/onboarding`, `/departments` o `/home`
/// ocurre de forma declarativa en `routerProvider` (`lib/core/router/app_router.dart`).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.92 + (0.08 * value),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 160,
                semanticLabel: 'app.name'.tr(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('app.name'.tr(), style: textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}
