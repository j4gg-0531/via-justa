import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

enum VjBadgeVariant { tonal, navy, neutral, outline }

/// Píldora informativa (badge) con etiqueta, variante e ícono opcional.
class VjBadge extends StatelessWidget {
  const VjBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = VjBadgeVariant.tonal,
  });

  final String label;
  final IconData? icon;
  final VjBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      VjBadgeVariant.tonal => (
          AppColors.primarySoft,
          AppColors.primary,
          Colors.transparent,
        ),
      VjBadgeVariant.navy => (
          AppColors.brandNavy,
          Colors.white,
          Colors.transparent,
        ),
      VjBadgeVariant.neutral => (
          AppColors.surfaceSubtle,
          AppColors.textSecondary,
          Colors.transparent,
        ),
      VjBadgeVariant.outline => (
          AppColors.surface,
          AppColors.textSecondary,
          AppColors.border,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border == Colors.transparent ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
