import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

enum VjButtonVariant { primary, navy, outlined, tonal, destructive }

/// Botón de ancho completo. Si onPressed es null, queda deshabilitado.
class VjButton extends StatelessWidget {
  const VjButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VjButtonVariant.primary,
    this.leading,
    this.leadingIcon,
    this.trailingIcon,
    this.minHeight = 52,
    this.horizontalPadding = AppSpacing.lg,
  });

  final String label;
  final VoidCallback? onPressed;
  final VjButtonVariant variant;
  final Widget? leading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double minHeight;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final (bg, fg, side) = switch (variant) {
      VjButtonVariant.primary => (
          AppColors.primary,
          Colors.white,
          BorderSide.none,
        ),
      VjButtonVariant.navy => (
          AppColors.brandNavy,
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
          const BorderSide(color: AppColors.primaryBorder),
        ),
      VjButtonVariant.destructive => (
          errorColor,
          Colors.white,
          BorderSide.none,
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
        minimumSize: Size.fromHeight(minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: AppSpacing.md,
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: onPressed == null ? BorderSide.none : side,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ] else if (leadingIcon != null) ...[
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