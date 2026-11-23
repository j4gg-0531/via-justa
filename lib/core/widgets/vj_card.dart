import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

/// Tarjeta interactiva con sombra sutil y estado seleccionado opcional.
class VjCard extends StatelessWidget {
  const VjCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppRadius.lg,
    this.elevated = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = BorderRadius.circular(borderRadius);
    final effectiveBg = backgroundColor ?? AppColors.surface;
    final effectiveBorder = selected
        ? AppColors.primary
        : (borderColor ?? AppColors.border.withValues(alpha: 0.85));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorder,
          width: selected ? 2 : 1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.brandNavy.withValues(
                    alpha: selected ? 0.08 : 0.04,
                  ),
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: effectiveRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}