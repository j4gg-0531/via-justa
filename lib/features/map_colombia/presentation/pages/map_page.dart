import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_shape.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';
import 'package:via_justa/features/municipality/domain/city_visual_identity.dart';
import 'package:via_justa/features/municipality/presentation/widgets/city_cultural_illustration.dart';

/// Pantalla 3 (M03 · VJ-09) · Mapa editorial en blanco de los 33 territorios de
/// Colombia (32 departamentos + Bogotá, D.C.) que cambia de color al seleccionar
/// un departamento, manteniendo una pista sutil sobre el piloto en Cesar.
class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  void _openDepartment(
    BuildContext context,
    WidgetRef ref,
    Department department,
  ) {
    FocusScope.of(context).unfocus();
    ref.read(selectedDepartmentProvider.notifier).selectDepartment(department);
    if (department.isAvailable) {
      context.push(AppRoutes.departmentPath(department.code));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('map.unavailable'.tr())),
        );
    }
  }

  void _handleCanvasTap(
    BuildContext context,
    WidgetRef ref,
    Offset localPosition,
  ) {
    FocusScope.of(context).unfocus();
    final previous = ref.read(selectedDepartmentProvider);
    final hit = ref
        .read(selectedDepartmentProvider.notifier)
        .selectAtCanvasOffset(localPosition.dx, localPosition.dy);
    if (hit == null) {
      ref.read(selectedDepartmentProvider.notifier).clear();
      return;
    }
    // Si el usuario vuelve a tocar el departamento piloto ya resaltado, entra directo.
    if (previous?.code == hit.code && hit.isAvailable) {
      context.push(AppRoutes.departmentPath(hit.code));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometryAsync = ref.watch(colombiaMapGeometryProvider);
    final features = ref.watch(colombiaMapFeaturesProvider);
    final selectedDepartment = ref.watch(selectedDepartmentProvider);
    final hasQuery = ref.watch(hasDepartmentQueryProvider);
    final suggestions = ref.watch(filteredDepartmentsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Lienzo editorial en blanco con resaltado dinámico al seleccionar
          Positioned.fill(
            child: Semantics(
              label: 'map.semantics'.tr(),
              child: _buildMapBody(
                context: context,
                ref: ref,
                geometryAsync: geometryAsync,
                features: features,
                selectedDepartment: selectedDepartment,
              ),
            ),
          ),

          // 2. Buscador flotante superior con retorno y accesos rápidos
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'common.back'.tr(),
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.onboarding);
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: VjSearchField(
                            hint: 'map.search_hint'.tr(),
                            onChanged: ref
                                .read(departmentQueryProvider.notifier)
                                .setQuery,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MapQuickChip(
                          icon: Icons.public,
                          label: 'map.san_andres_inset'.tr(),
                          isSelected:
                              selectedDepartment?.code ==
                              Departments.sanAndres.code,
                          onTap: () => ref
                              .read(selectedDepartmentProvider.notifier)
                              .selectDepartment(Departments.sanAndres),
                        ),
                        if (selectedDepartment != null)
                          _MapQuickChip(
                            icon: Icons.refresh,
                            label: 'map.clear_selection'.tr(),
                            isSelected: false,
                            onTap: () => ref
                                .read(selectedDepartmentProvider.notifier)
                                .clear(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Sugerencias desplegables del buscador (33 territorios)
          if (hasQuery)
            Positioned(
              top: 96,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: VjCard(
                  padding: EdgeInsets.zero,
                  child: suggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'municipality.no_results'.tr(),
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: suggestions.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final dept = suggestions[index];
                            final deptIdentity =
                                CityVisualIdentityCatalog.forDepartment(
                                  dept.code,
                                );
                            return ListTile(
                              leading: DepartmentCulturalEmblemBadge(
                                identity: deptIdentity,
                                size: 34,
                                highlight: dept.isAvailable,
                              ),
                              title: Text(dept.name),
                              subtitle: Text(
                                deptIdentity.tagKey.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                              trailing: dept.isAvailable
                                  ? VjBadge(
                                      label: 'municipality.pilot_badge'.tr(),
                                    )
                                  : Text(
                                      'DANE ${dept.code}',
                                      style: textTheme.bodySmall,
                                    ),
                              onTap: () {
                                ref
                                    .read(departmentQueryProvider.notifier)
                                    .setQuery('');
                                _openDepartment(context, ref, dept);
                              },
                            );
                          },
                        ),
                ),
              ),
            ),

          // 4. Tarjeta inferior reactiva + nota honesta de fuente cartográfica
          Positioned(
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapSelectionBottomCard(
                    selectedDepartment: selectedDepartment,
                    onGoToCesar: () =>
                        _openDepartment(context, ref, Departments.cesar),
                    onTapSelected: (dept) =>
                        _openDepartment(context, ref, dept),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'map.sample_note'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBody({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<ColombiaMapGeometry> geometryAsync,
    required List<DepartmentMapFeature> features,
    required Department? selectedDepartment,
  }) {
    if (geometryAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'map.load_error'.tr(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () => ref.invalidate(colombiaMapGeometryProvider),
                icon: const Icon(Icons.refresh),
                label: Text('common.retry'.tr()),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final geometry = geometryAsync.value;
    if (geometry == null) {
      return const SizedBox.expand();
    }

    final bounds = geometry.bounds;
    final cesarAnchor = geometry.canvasAnchorForCode(Departments.cesar.code);
    final isCesarSelected =
        selectedDepartment?.code == Departments.cesar.code;

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          136,
          AppSpacing.md,
          144,
        ),
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: bounds.width,
              height: bounds.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleCanvasTap(
                  context,
                  ref,
                  details.localPosition,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(bounds.width, bounds.height),
                      painter: _ColombiaMapPainter(
                        features: features,
                        bounds: bounds,
                        selectedCode: selectedDepartment?.code,
                        cesarAnchor: cesarAnchor,
                      ),
                    ),
                    if (cesarAnchor != null)
                      Positioned(
                        left: cesarAnchor.x + 14,
                        top: cesarAnchor.y - 26,
                        child: _DepartmentBubble(
                          department: Departments.cesar,
                          isSelected: isCesarSelected,
                          onTap: () =>
                              _openDepartment(context, ref, Departments.cesar),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSelectionBottomCard extends StatelessWidget {
  const _MapSelectionBottomCard({
    required this.selectedDepartment,
    required this.onGoToCesar,
    required this.onTapSelected,
  });

  final Department? selectedDepartment;
  final VoidCallback onGoToCesar;
  final ValueChanged<Department> onTapSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dept = selectedDepartment;

    if (dept == null) {
      return VjCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onGoToCesar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'map.select_prompt_title'.tr(),
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'map.select_prompt_subtitle'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'map.go_to_cesar'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (dept.isAvailable) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTapSelected(dept),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(dept.name, style: textTheme.titleMedium),
                                Text(
                                  '· ${dept.code}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                VjBadge(label: 'municipality.pilot_badge'.tr()),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'map.cesar_pilot_summary'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      'map.explore_department'.tr(),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return VjCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => onTapSelected(dept),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(dept.name, style: textTheme.titleMedium),
              Text(
                '· ${dept.code}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'common.coming_soon'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'map.unavailable'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onGoToCesar,
              icon: const Icon(Icons.place_outlined, size: 16),
              label: Text('map.go_to_cesar'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintor editorial limpio de Colombia:
/// 1. Sombra suave neutra para elevar el mapa sobre `AppColors.background`.
/// 2. Departamentos en blanco puro (`AppColors.surface`) con divisiones nítidas.
/// 3. Pista discreta en `AppColors.primarySoft` + punto azul sobre Cesar (piloto).
/// 4. Al tocar un departamento, cambia su color: azul primario (`AppColors.primary`)
///    para el piloto o pizarra neutro (`AppColors.textSecondary`) para próximos.
class _ColombiaMapPainter extends CustomPainter {
  const _ColombiaMapPainter({
    required this.features,
    required this.bounds,
    required this.selectedCode,
    this.cesarAnchor,
  });

  final List<DepartmentMapFeature> features;
  final MapBounds bounds;
  final String? selectedCode;
  final MapPoint? cesarAnchor;

  @override
  void paint(Canvas canvas, Size size) {
    final pathsByCode = <String, Path>{};
    for (final feature in features) {
      pathsByCode[feature.department.code] = _buildShapePath(feature.shape);
    }

    // 1. Sombra suave neutra bajo el país completo
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.textPrimary.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.save();
    canvas.translate(0, 5);
    for (final path in pathsByCode.values) {
      canvas.drawPath(path, shadowPaint);
    }
    canvas.restore();

    // 2. Perímetro exterior sutil de Colombia
    final outerPerimeterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.textMuted.withValues(alpha: 0.55)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;
    for (final path in pathsByCode.values) {
      canvas.drawPath(path, outerPerimeterPaint);
    }

    // 3. Relleno blanco limpio y fronteras departamentales nítidas
    final baseFillPaint = Paint()..style = PaintingStyle.fill;
    final internalStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.textMuted.withValues(alpha: 0.38)
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.3;

    for (final feature in features) {
      final dept = feature.department;
      final path = pathsByCode[dept.code]!;
      final isSelected = selectedCode == dept.code;

      if (isSelected) {
        // Se dibuja en la capa superior (paso 4) para que su borde quede limpio.
        baseFillPaint.color = AppColors.surface;
      } else if (dept.isAvailable) {
        // Pista suave del piloto activo cuando aún no está seleccionado.
        baseFillPaint.color = AppColors.primarySoft;
      } else {
        baseFillPaint.color = AppColors.surface;
      }
      canvas.drawPath(path, baseFillPaint);
      canvas.drawPath(path, internalStrokePaint);

      if (!isSelected && dept.isAvailable) {
        final pilotHintStroke = Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.primary.withValues(alpha: 0.72)
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.0;
        canvas.drawPath(path, pilotHintStroke);
      }
    }

    // 4. Departamento seleccionado con cambio de color claro y jerárquico
    if (selectedCode != null) {
      for (final feature in features) {
        final dept = feature.department;
        if (dept.code != selectedCode) continue;

        final path = pathsByCode[dept.code]!;
        final selectedFillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = dept.isAvailable
              ? AppColors.primary
              : AppColors.textSecondary;

        final selectedBorderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = dept.isAvailable
              ? AppColors.textPrimary.withValues(alpha: 0.35)
              : AppColors.textPrimary
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.6;

        canvas.drawPath(path, selectedFillPaint);
        canvas.drawPath(path, selectedBorderPaint);
      }
    }

    // 5. Punto indicador limpio en Cesar cuando no está seleccionado
    if (cesarAnchor != null && selectedCode != Departments.cesar.code) {
      final anchor = Offset(cesarAnchor!.x, cesarAnchor!.y);
      canvas.drawCircle(
        anchor,
        9.5,
        Paint()..color = AppColors.primary.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        anchor,
        5.5,
        Paint()..color = AppColors.surface,
      );
      canvas.drawCircle(
        anchor,
        3.8,
        Paint()..color = AppColors.primary,
      );
    }

    // 6. Recuadro guía alrededor del archipiélago de San Andrés y Providencia
    final insetRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-8, -8, 42, 62),
      const Radius.circular(AppRadius.sm),
    );
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = selectedCode == Departments.sanAndres.code
          ? AppColors.primary
          : AppColors.textMuted.withValues(alpha: 0.45)
      ..strokeWidth = 1.6;
    canvas.drawRRect(insetRect, insetPaint);
  }

  Path _buildShapePath(DepartmentShape shape) {
    final path = Path();
    for (final ring in shape.rings) {
      if (ring.length < 3) continue;
      path.moveTo(
        ring.first.x - bounds.minX,
        ring.first.y - bounds.minY,
      );
      for (var i = 1; i < ring.length; i++) {
        path.lineTo(
          ring[i].x - bounds.minX,
          ring[i].y - bounds.minY,
        );
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ColombiaMapPainter oldDelegate) {
    return oldDelegate.selectedCode != selectedCode ||
        oldDelegate.features != features;
  }
}

class _MapQuickChip extends StatelessWidget {
  const _MapQuickChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentBubble extends StatelessWidget {
  const _DepartmentBubble({
    required this.department,
    required this.isSelected,
    required this.onTap,
  });

  final Department department;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isSelected ? AppColors.textPrimary : AppColors.surface;
    final foregroundColor =
        isSelected ? AppColors.surface : AppColors.textPrimary;
    final borderColor = isSelected ? AppColors.textPrimary : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.14),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    department.name,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    color: isSelected ? AppColors.surface : AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
