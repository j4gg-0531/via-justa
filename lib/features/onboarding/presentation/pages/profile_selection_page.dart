import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';
import 'package:via_justa/features/onboarding/presentation/widgets/profile_option_card.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

/// Pantalla 2 · Onboarding: selección de perfil.
class ProfileSelectionPage extends ConsumerWidget {
  const ProfileSelectionPage({super.key});

  /// Selecciona el perfil en memoria y lo guarda en el servidor cuando el
  /// backend ya lo admite (D11: `resident` todavía no).
  Future<void> _selectProfile(
    BuildContext context,
    WidgetRef ref,
    ProfileType type,
  ) async {
    ref.read(profileTypeProvider.notifier).select(type);
    final persisted = await ref
        .read(authControllerProvider.notifier)
        .persistProfileType(type);
    if (!persisted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.error.profile_type_pending'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(profileTypeProvider);
    final displayName = ref.watch(displayNameProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              IconButton(
                tooltip: 'common.back'.tr(),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(48, 48),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'onboarding.greeting'.tr(
                          namedArgs: {'name': displayName},
                        ),
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'onboarding.subtitle'.tr(),
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ProfileOptionCard(
                        icon: Icons.luggage_outlined,
                        title: 'onboarding.visitor.title'.tr(),
                        description: 'onboarding.visitor.description'.tr(),
                        selected: selected == ProfileType.visitor,
                        onTap: () =>
                            _selectProfile(context, ref, ProfileType.visitor),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ProfileOptionCard(
                        icon: Icons.home_work_outlined,
                        title: 'onboarding.settler.title'.tr(),
                        description: 'onboarding.settler.description'.tr(),
                        selected: selected == ProfileType.settler,
                        badge: 'onboarding.settler.badge'.tr(),
                        onTap: () =>
                            _selectProfile(context, ref, ProfileType.settler),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ProfileOptionCard(
                        icon: Icons.storefront_outlined,
                        title: 'onboarding.resident.title'.tr(),
                        description: 'onboarding.resident.description'.tr(),
                        selected: selected == ProfileType.resident,
                        onTap: () =>
                            _selectProfile(context, ref, ProfileType.resident),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
              VjButton(
                label: 'common.continue'.tr(),
                trailingIcon: Icons.arrow_forward,
                onPressed: selected == null
                    ? null
                    : () => context.push(AppRoutes.departmentMap),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
