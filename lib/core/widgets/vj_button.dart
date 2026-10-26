import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

enum VjButtonVariant { primary, outlined, tonal }

/// Botón de ancho completo. Si onPressed es null, queda deshabilitado.
class VjButton extends StatelessWidget {
  const VjButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VjButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final VjButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (variant) {
      VjButtonVariant.primary => (
          AppColors.primary,
          Colors.white,
          BorderSide.none,
        ),
      VjButtonVariant.outlined => (
          AppColors.surface,
          AppColors.textPrimary,
          const BorderSide(color: AppColors.border),
        ),
      VjButtonVariant.tonal => (
          AppColors.primarySoft,
          AppColors.primary,
          const BorderSide(color: Color(0xFFDBEAFE)),
        ),
    };

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: onPressed == null ? BorderSide.none : side,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(trailingIcon, size: 20),
          ],
        ],
      ),
    );
  }
}