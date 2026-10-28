import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/features/scan/domain/scan_mode.dart';
import 'package:via_justa/features/scan/presentation/state/scan_providers.dart';

/// Pantalla 6 (M06) · Escanear precio o contrato con selector interactivo y visor ilustrado.
class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('scan.dialog_title'.tr()),
        content: Text('scan.dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(scanModeProvider);
    final modeNotifier = ref.read(scanModeProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Título y descripción
              Text(
                'scan.title'.tr(),
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'scan.subtitle'.tr(),
                style: textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Selector segmentado: Precio vs Contrato
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScanModeTab(
                        label: 'scan.tab_price'.tr(),
                        icon: Icons.receipt_long_outlined,
                        selected: selectedMode == ScanMode.price,
                        onTap: () => modeNotifier.selectMode(ScanMode.price),
                      ),
                    ),
                    Expanded(
                      child: _ScanModeTab(
                        label: 'scan.tab_contract'.tr(),
                        icon: Icons.assignment_outlined,
                        selected: selectedMode == ScanMode.contract,
                        onTap: () => modeNotifier.selectMode(ScanMode.contract),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Tarjeta explicativa según el modo
              VjCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          selectedMode == ScanMode.price
                              ? Icons.price_check
                              : Icons.gavel_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            selectedMode == ScanMode.price
                                ? 'scan.price_header'.tr()
                                : 'scan.contract_header'.tr(),
                            style: textTheme.titleMedium,
                          ),
                        ),
                        VjBadge(label: 'common.coming_soon'.tr()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      selectedMode == ScanMode.price
                          ? 'scan.price_description'.tr()
                          : 'scan.contract_description'.tr(),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Visor ilustrado de escaneo
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Marco de visor
                      Container(
                        width: 200,
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selectedMode == ScanMode.price
                                ? Icons.receipt
                                : Icons.description,
                            size: 48,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'scan.camera_ready'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'scan.camera_preview_label'.tr(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Nota de honestidad DEMO
              Center(
                child: Text(
                  'scan.demo_note'.tr(),
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: VjButton(
                      label: 'scan.action_photo'.tr(),
                      leadingIcon: Icons.camera_alt_outlined,
                      onPressed: () => _showInfoDialog(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showInfoDialog(context),
                      icon: const Icon(Icons.file_upload_outlined, size: 20),
                      label: Text('scan.action_gallery'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestaña del selector segmentado
class _ScanModeTab extends StatelessWidget {
  const _ScanModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: selected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
