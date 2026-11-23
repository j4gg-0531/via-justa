import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';

/// Abre un diálogo centrado de confirmación o aviso breve con cabecera centrada y botones 50/50.
Future<bool?> showVjConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  VjModalTone tone = VjModalTone.primary,
  bool barrierDismissible = true,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.brandNavy.withValues(alpha: 0.45),
    builder: (dialogContext) => VjConfirmDialog(
      icon: icon,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
      onConfirm: () {
        Navigator.of(dialogContext).pop(true);
        onConfirm?.call();
      },
      onCancel: () {
        Navigator.of(dialogContext).pop(false);
        onCancel?.call();
      },
    ),
  );
}

/// Diálogo compacto estilizado: icono y título centrados + botones 50/50 adaptables.
class VjConfirmDialog extends StatelessWidget {
  const VjConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel,
    this.onCancel,
    this.tone = VjModalTone.primary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final VjModalTone tone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;

    final (iconBg, iconBorder, iconFg, confirmVariant) = switch (tone) {
      VjModalTone.primary => (
        AppColors.primarySoft,
        AppColors.primaryBorder,
        AppColors.primary,
        VjButtonVariant.primary,
      ),
      VjModalTone.neutral => (
        AppColors.surfaceSubtle,
        AppColors.border,
        AppColors.brandNavy,
        VjButtonVariant.navy,
      ),
      VjModalTone.destructive => (
        errorColor.withValues(alpha: 0.10),
        errorColor.withValues(alpha: 0.25),
        errorColor,
        VjButtonVariant.destructive,
      ),
    };

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: iconBorder),
                  ),
                  child: Icon(icon, color: iconFg, size: 24),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              VjModalActionRow(
                cancelLabel: cancelLabel,
                onCancel: onCancel,
                confirmLabel: confirmLabel,
                onConfirm: onConfirm,
                confirmVariant: confirmVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
