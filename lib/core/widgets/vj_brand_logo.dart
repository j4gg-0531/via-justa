import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

/// Emblema institucional reutilizable de Vía Justa con etiqueta Hero opcional.
class VjBrandLogo extends StatelessWidget {
  const VjBrandLogo({
    super.key,
    this.size = 86,
    this.heroTag,
    this.borderRadius = AppRadius.xl,
    this.padding = 12,
  });

  final double size;
  final Object? heroTag;
  final double borderRadius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
      ),
    );

    if (heroTag == null) return mark;

    return Hero(
      tag: heroTag!,
      child: Material(
        type: MaterialType.transparency,
        child: mark,
      ),
    );
  }
}
