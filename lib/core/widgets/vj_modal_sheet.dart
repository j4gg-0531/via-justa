import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';

/// Tono visual del icono y acentos de una hoja o diálogo modal de Vía Justa.
enum VjModalTone { primary, neutral, destructive }

/// Abre una hoja inferior estilizada con el sistema de diseño de Vía Justa.
Future<T?> showVjModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.brandNavy.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: builder,
  );
}

/// Contenedor reutilizable para hojas inferiores (formularios, selectores y lectura larga).
class VjModalSheet extends StatelessWidget {
  const VjModalSheet({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.tone = VjModalTone.primary,
    this.subtitle,
    this.headerBadge,
    this.headerProgress,
    this.footer,
    this.onClose,
    this.showCloseButton = true,
    this.closeEnabled = true,
    this.scrollable = true,
    this.showHeaderDivider = true,
    this.maxHeightFactor = 0.86,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final VjModalTone tone;
  final String? subtitle;
  final Widget? headerBadge;
  final Widget? headerProgress;
  final Widget? footer;
  final VoidCallback? onClose;
  final bool showCloseButton;
  final bool closeEnabled;
  final bool scrollable;
  final bool showHeaderDivider;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(14) / 14;
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight = (media.size.height - keyboardInset).clamp(
      220.0,
      960.0,
    );
    final maxHeight = (availableHeight * maxHeightFactor).clamp(
      200.0,
      availableHeight,
    );
    final useUnifiedScroll =
        scrollable && (textScale >= 1.45 || availableHeight < 440);

    final (iconBg, iconBorder, iconFg) = switch (tone) {
      VjModalTone.primary => (
        AppColors.primarySoft,
        AppColors.primaryBorder,
        AppColors.primary,
      ),
      VjModalTone.neutral => (
        AppColors.surfaceSubtle,
        AppColors.border,
        AppColors.brandNavy,
      ),
      VjModalTone.destructive => (
        errorColor.withValues(alpha: 0.10),
        errorColor.withValues(alpha: 0.25),
        errorColor,
      ),
    };

    final headerSection = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.sm,
        AppSpacing.sm + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: (subtitle == null && headerBadge == null)
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: iconBorder),
                  ),
                  child: Icon(icon, color: iconFg, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: (subtitle == null && headerBadge == null) ? 0 : 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (headerBadge != null) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        headerBadge!,
                      ],
                    ],
                  ),
                ),
              ),
              if (showCloseButton) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: 'common.close'.tr(),
                  onPressed: closeEnabled
                      ? (onClose ?? () => Navigator.of(context).pop())
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (headerProgress != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: headerProgress!,
            ),
          ],
        ],
      ),
    );

    final footerSection = footer == null
        ? null
        : DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: footer,
            ),
          );

    if (useUnifiedScroll) {
      return Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerSection,
                  if (showHeaderDivider)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: child,
                  ),
                  ?footerSection,
                ],
              ),
            ),
          ),
        ),
      );
    }

    final bodyContent = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: child,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: child,
          );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerSection,
              if (showHeaderDivider)
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              Flexible(child: bodyContent),
              ?footerSection,
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila adaptable 50/50 para dos acciones modales; se apila verticalmente si el texto es grande.
class VjModalActionRow extends StatelessWidget {
  const VjModalActionRow({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel,
    this.onCancel,
    this.confirmVariant = VjButtonVariant.primary,
    this.confirmLeadingIcon,
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final VjButtonVariant confirmVariant;
  final IconData? confirmLeadingIcon;

  @override
  Widget build(BuildContext context) {
    final confirmButton = VjButton(
      label: confirmLabel,
      onPressed: onConfirm,
      variant: confirmVariant,
      leadingIcon: confirmLeadingIcon,
      minHeight: 48,
      horizontalPadding: AppSpacing.sm + 4,
    );

    if (cancelLabel == null) {
      return confirmButton;
    }

    final cancelButton = VjButton(
      label: cancelLabel!,
      onPressed: onCancel,
      variant: VjButtonVariant.outlined,
      minHeight: 48,
      horizontalPadding: AppSpacing.sm + 4,
    );

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideBySide = textScale < 1.38 && constraints.maxWidth >= 230;
        if (!useSideBySide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              confirmButton,
              const SizedBox(height: AppSpacing.sm),
              cancelButton,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cancelButton),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(child: confirmButton),
            ],
          ),
        );
      },
    );
  }
}
