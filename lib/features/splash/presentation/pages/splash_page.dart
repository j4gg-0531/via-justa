import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_brand_logo.dart';

/// Pantalla de arranque con emblema Hero compartido hacia la bienvenida.
/// La redirección hacia `/welcome`, `/onboarding`, `/departments` o `/home`
/// ocurre de forma declarativa en `routerProvider` (`lib/core/router/app_router.dart`).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disableMotion = MediaQuery.disableAnimationsOf(context);

    final emblem = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'app.name'.tr(),
          child: const VjBrandLogo(
            size: 112,
            heroTag: 'vj-brand-logo',
            padding: 16,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'app.name'.tr(),
          style: textTheme.headlineMedium,
        ),
      ],
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.9,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              AppColors.background,
            ],
          ),
        ),
        child: Center(
          child: disableMotion
              ? emblem
              : TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.90 + (0.10 * value),
                        child: child,
                      ),
                    );
                  },
                  child: emblem,
                ),
        ),
      ),
    );
  }
}
