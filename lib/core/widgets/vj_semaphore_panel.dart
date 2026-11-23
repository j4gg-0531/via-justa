import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_card.dart';

/// Luz encendida en la cabina vertical del semáforo (`neutral` mantiene las 3 apagadas).
enum VjSemaphoreLight { green, amber, red, neutral }

/// Encabezado unificado "Semáforo Vertical Puro" compartido entre resultados de precios y contratos.
///
/// Combina color semántico, ícono obligatorio dentro del lente activo y píldora descriptiva
/// para no depender nunca únicamente del color.
class VjSemaphorePanel extends StatelessWidget {
  const VjSemaphorePanel({
    super.key,
    required this.activeLight,
    required this.statusLabel,
    required this.statusIcon,
    required this.headline,
    this.categoryTag,
    this.subMetric,
    this.accentColor,
    this.badgeBackground,
    this.badgeForeground,
    this.trailingDetail,
  });

  final VjSemaphoreLight activeLight;
  final String statusLabel;
  final IconData statusIcon;
  final String headline;
  final String? categoryTag;
  final String? subMetric;
  final Color? accentColor;
  final Color? badgeBackground;
  final Color? badgeForeground;
  final Widget? trailingDetail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disableMotion = MediaQuery.disableAnimationsOf(context);

    final (defaultFg, defaultBg, borderTone) = switch (activeLight) {
      VjSemaphoreLight.green => (
          AppColors.semaphoreGreen,
          AppColors.semaphoreGreenSoft,
          AppColors.semaphoreGreen.withValues(alpha: 0.35),
        ),
      VjSemaphoreLight.amber => (
          AppColors.semaphoreAmber,
          AppColors.semaphoreAmberSoft,
          AppColors.semaphoreAmber.withValues(alpha: 0.35),
        ),
      VjSemaphoreLight.red => (
          AppColors.semaphoreRed,
          AppColors.semaphoreRedSoft,
          AppColors.semaphoreRed.withValues(alpha: 0.35),
        ),
      VjSemaphoreLight.neutral => (
          AppColors.textSecondary,
          AppColors.surfaceSubtle,
          AppColors.border,
        ),
    };

    final fg = accentColor ?? defaultFg;
    final pillBg = badgeBackground ?? defaultBg;
    final pillFg = badgeForeground ?? defaultFg;

    final content = VjCard(
      borderRadius: AppRadius.xl,
      borderColor: borderTone,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cabina vertical del semáforo (rojo arriba, ámbar centro, verde abajo)
              Semantics(
                label: statusLabel,
                child: Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.brandNavySurface),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SemaphoreLens(
                        isActive: activeLight == VjSemaphoreLight.red,
                        activeColor: AppColors.semaphoreRedLens,
                        iconColor: Colors.white,
                        icon: Icons.priority_high_rounded,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SemaphoreLens(
                        isActive: activeLight == VjSemaphoreLight.amber,
                        activeColor: AppColors.semaphoreAmberLens,
                        iconColor: AppColors.brandNavy,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SemaphoreLens(
                        isActive: activeLight == VjSemaphoreLight.green,
                        activeColor: AppColors.semaphoreGreen,
                        iconColor: Colors.white,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoryTag != null && categoryTag!.isNotEmpty) ...[
                      Text(
                        categoryTag!,
                        style: textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: pillFg.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 15, color: pillFg),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              statusLabel,
                              style: textTheme.labelMedium?.copyWith(
                                color: pillFg,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      headline,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 23,
                        height: 1.15,
                      ),
                    ),
                    if (subMetric != null && subMetric!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subMetric!,
                        style: textTheme.bodySmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (trailingDetail != null) ...[
            const SizedBox(height: AppSpacing.md),
            trailingDetail!,
          ],
        ],
      ),
    );

    if (disableMotion) return content;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 10),
              child: child,
            ),
          );
        },
        child: content,
      ),
    );
  }
}

class _SemaphoreLens extends StatelessWidget {
  const _SemaphoreLens({
    required this.isActive,
    required this.activeColor,
    required this.iconColor,
    required this.icon,
  });

  final bool isActive;
  final Color activeColor;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? activeColor : AppColors.brandNavySurface,
        border: Border.all(
          color: isActive ? Colors.white : AppColors.brandNavyMuted,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isActive ? Icon(icon, size: 14, color: iconColor) : null,
    );
  }
}
