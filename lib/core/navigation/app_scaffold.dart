import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

/// Contenedor persistente principal de navegación para las 5 pestañas de Vía Justa.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemoMode = ref.watch(isDemoModeProvider);

    return BackButtonListener(
      onBackButtonPressed: () async {
        // Si hay una hoja modal, diálogo o ruta apilada encima, dejar que el Navigator la cierre primero.
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          return false;
        }
        // Si no estamos en la pestaña de Inicio, el botón atrás regresa a Inicio.
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return true; // Evento consumido
        }
        return false; // Permitir que el sistema maneje el pop
      },
      child: Scaffold(
        body: Column(
          children: [
            if (isDemoMode) const _GlobalDemoNoticeBanner(),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.brandNavy
                      : AppColors.textMuted,
                );
              }),
            ),
            child: NavigationBar(
              height: 68,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.brandNavy,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              destinations: [
                NavigationDestination(
                  icon: const Icon(
                    Icons.home_outlined,
                    color: AppColors.textMuted,
                  ),
                  selectedIcon: const Icon(
                    Icons.home_rounded,
                    color: Colors.white,
                  ),
                  label: 'nav.home'.tr(),
                  tooltip: 'nav.home'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(
                    Icons.map_outlined,
                    color: AppColors.textMuted,
                  ),
                  selectedIcon: const Icon(
                    Icons.map_rounded,
                    color: Colors.white,
                  ),
                  label: 'nav.map'.tr(),
                  tooltip: 'nav.map'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(
                    Icons.document_scanner_outlined,
                    color: AppColors.textMuted,
                  ),
                  selectedIcon: const Icon(
                    Icons.document_scanner_rounded,
                    color: Colors.white,
                  ),
                  label: 'nav.scan'.tr(),
                  tooltip: 'nav.scan'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.textMuted,
                  ),
                  selectedIcon: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                  ),
                  label: 'nav.businesses'.tr(),
                  tooltip: 'nav.businesses'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textMuted,
                  ),
                  selectedIcon: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                  ),
                  label: 'nav.profile'.tr(),
                  tooltip: 'nav.profile'.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Único aviso global discreto cuando la aplicación corre en modo muestra sin Supabase.
class _GlobalDemoNoticeBanner extends StatelessWidget {
  const _GlobalDemoNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'common.global_demo_banner'.tr(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
