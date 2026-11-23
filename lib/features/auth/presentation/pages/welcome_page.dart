import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_brand_logo.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_text.dart';

/// Pantalla de bienvenida (Opción B · Hero Navy) con coreografía de entrada:
/// 1) El emblema aparece centrado sobre lienzo claro con pulso breve.
/// 2) El fondo transita a azul marino profundo mientras el logo sube al hero.
/// 3) El título, subtítulo y el panel curvo inferior con acciones emergen suavemente.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseProgress;
  late final Animation<double> _logoFlight;
  late final Animation<Color?> _backgroundColor;
  late final Animation<double> _auraOpacity;
  late final Animation<double> _headlineOpacity;
  late final Animation<Offset> _headlineSlide;
  late final Animation<double> _dockOpacity;
  late final Animation<Offset> _dockSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _pulseProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.34, curve: Curves.easeOutCubic),
    );
    _logoFlight = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.66, curve: Curves.easeInOutCubic),
    );
    _backgroundColor = ColorTween(
      begin: AppColors.background,
      end: AppColors.brandNavy,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.22, 0.64, curve: Curves.easeInOut),
      ),
    );
    _auraOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.78, curve: Curves.easeOut),
    );
    _headlineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.84, curve: Curves.easeOutCubic),
    );
    _headlineSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.84, curve: Curves.easeOutCubic),
      ),
    );
    _dockOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.58, 1.0, curve: Curves.easeOutCubic),
    );
    _dockSlide = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.58, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disableMotion = MediaQuery.disableAnimationsOf(context);

    if (disableMotion && _controller.value != 1.0) {
      _controller.value = 1.0;
    }

    final headlineGroup = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'app.name'.tr(),
          style: textTheme.headlineLarge?.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'login.tagline'.tr(),
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.surface.withValues(alpha: 0.80),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final bottomDock = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl + 6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VjButton(
              label: 'welcome.sign_in'.tr(),
              onPressed: () => context.push(AppRoutes.login),
            ),
            const SizedBox(height: AppSpacing.md),
            VjButton(
              label: 'welcome.create_account'.tr(),
              variant: VjButtonVariant.outlined,
              onPressed: () => context.push(AppRoutes.register),
            ),
            const SizedBox(height: AppSpacing.lg),
            LegalText(
              prefix: 'login.legal_prefix'.tr(),
            ),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final bgColor = disableMotion
                ? AppColors.brandNavy
                : (_backgroundColor.value ?? AppColors.brandNavy);
            final flightT = disableMotion ? 1.0 : _logoFlight.value;
            final pulseT = disableMotion ? 1.0 : _pulseProgress.value;
            final auraT = disableMotion ? 1.0 : _auraOpacity.value;

            return Scaffold(
              backgroundColor: bgColor,
              body: DecoratedBox(
                decoration: BoxDecoration(
                  color: bgColor,
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.52),
                    radius: 0.98,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.30 * auraT),
                      bgColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final travelOffset =
                          ((constraints.maxHeight * 0.25).clamp(48.0, 175.0)) *
                          (1.0 - flightT);
                      final logoScale = 1.24 - (0.24 * flightT);

                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  AppSpacing.xxl,
                                  AppSpacing.xl,
                                  AppSpacing.xl,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: AppSpacing.md),
                                    Transform.translate(
                                      offset: Offset(0, travelOffset),
                                      child: Transform.scale(
                                        scale: logoScale,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          clipBehavior: Clip.none,
                                          children: [
                                            if (pulseT < 1.0)
                                              Transform.scale(
                                                scale: 1.0 + (0.62 * pulseT),
                                                child: Opacity(
                                                  opacity: (1.0 - pulseT) * 0.45,
                                                  child: Container(
                                                    width: 88,
                                                    height: 88,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppRadius.xl,
                                                          ),
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            const VjBrandLogo(
                                              size: 88,
                                              heroTag: 'vj-brand-logo',
                                              padding: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    disableMotion
                                        ? headlineGroup
                                        : FadeTransition(
                                            opacity: _headlineOpacity,
                                            child: SlideTransition(
                                              position: _headlineSlide,
                                              child: headlineGroup,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                              disableMotion
                                  ? bottomDock
                                  : FadeTransition(
                                      opacity: _dockOpacity,
                                      child: SlideTransition(
                                        position: _dockSlide,
                                        child: bottomDock,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
