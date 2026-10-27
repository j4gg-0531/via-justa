import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';

/// Contenedor persistente principal de navegación para las 5 pestañas de Vía Justa.
class AppScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        // Si no estamos en la pestaña de Inicio, el botón atrás regresa a Inicio.
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return true; // Evento consumido
        }
        return false; // Permitir que el sistema maneje el pop
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primarySoft,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            destinations: [
              NavigationDestination(
                icon: const Icon(
                  Icons.home_outlined,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.home,
                  color: AppColors.primary,
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
                  Icons.map,
                  color: AppColors.primary,
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
                  Icons.document_scanner,
                  color: AppColors.primary,
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
                  Icons.storefront,
                  color: AppColors.primary,
                ),
                label: 'nav.businesses'.tr(),
                tooltip: 'nav.businesses'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.person_outline,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.person,
                  color: AppColors.primary,
                ),
                label: 'nav.profile'.tr(),
                tooltip: 'nav.profile'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
