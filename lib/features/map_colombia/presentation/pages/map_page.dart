import 'dart:math' as math;

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

/// Pantalla 3 (M03 · VJ-09) · Mapa real de los 33 territorios de Colombia
/// (32 departamentos + Bogotá, D.C.) con identidad cultural ilustrada, buscador y selección táctil.
class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  void _handleDepartmentSelection(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometryAsync = ref.watch(colombiaMapGeometryProvider);
    final features = ref.watch(colombiaMapFeaturesProvider);
    final selectedDepartment = ref.watch(selectedDepartmentProvider);
    final selectedIdentity = CityVisualIdentityCatalog.forDepartment(
      selectedDepartment.code,
    );
    final hasQuery = ref.watch(hasDepartmentQueryProvider);
    final suggestions = ref.watch(filteredDepartmentsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Lienzo cartográfico vectorial de Colombia con zoom, desplazamiento y adornos sutiles de cañaguate
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

          // 2. Buscador flotante superior con botón de retorno (mínimo 48x48 dp)
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
                    // Recuadro accesible para San Andrés y Providencia (código 88),
                    // cuyas islas son muy pequeñas a escala nacional.
                    _SanAndresInsetChip(
                      isSelected:
                          selectedDepartment.code == Departments.sanAndres.code,
                      onTap: () => _handleDepartmentSelection(
                        context,
                        ref,
                        Departments.sanAndres,
                      ),
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
                                _handleDepartmentSelection(context, ref, dept);
                              },
                            );
                          },
                        ),
                ),
              ),
            ),

          // 4. Tarjeta inferior del departamento seleccionado con emblema ilustrado + crédito de fuente
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
                  VjCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    onTap: () => _handleDepartmentSelection(
                      context,
                      ref,
                      selectedDepartment,
                    ),
                    child: Row(
                      children: [
                        DepartmentCulturalEmblemBadge(
                          identity: selectedIdentity,
                          size: 44,
                          highlight: selectedDepartment.isAvailable,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    selectedDepartment.name,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '· ${selectedDepartment.code}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (selectedDepartment.isAvailable)
                                    VjBadge(
                                      label: 'municipality.pilot_badge'.tr(),
                                    ),
                                ],
                              ),
                              Text(
                                selectedIdentity.tagKey.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                selectedDepartment.isAvailable
                                    ? 'municipality.pilot_available'.tr()
                                    : 'map.unavailable'.tr(),
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
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
    required Department selectedDepartment,
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

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          136,
          AppSpacing.md,
          136,
        ),
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: bounds.width,
              height: bounds.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final hit = ref
                      .read(selectedDepartmentProvider.notifier)
                      .selectAtCanvasOffset(
                        details.localPosition.dx,
                        details.localPosition.dy,
                      );
                  if (hit != null) {
                    _handleDepartmentSelection(context, ref, hit);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(bounds.width, bounds.height),
                      painter: _ColombiaMapPainter(
                        features: features,
                        bounds: bounds,
                        selectedCode: selectedDepartment.code,
                        cesarAnchor: cesarAnchor,
                      ),
                    ),
                    if (cesarAnchor != null)
                      Positioned(
                        left: cesarAnchor.x - 52,
                        top: cesarAnchor.y - 26,
                        child: _DepartmentBubble(
                          department: Departments.cesar,
                          onTap: () => _handleDepartmentSelection(
                            context,
                            ref,
                            Departments.cesar,
                          ),
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

class _ColombiaMapPainter extends CustomPainter {
  const _ColombiaMapPainter({
    required this.features,
    required this.bounds,
    required this.selectedCode,
    this.cesarAnchor,
  });

  final List<DepartmentMapFeature> features;
  final MapBounds bounds;
  final String selectedCode;
  final MapPoint? cesarAnchor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.surface
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.0;

    final selectedBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.primary
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0;

    // 1. Pintar primero los departamentos no seleccionados ni piloto
    for (final feature in features) {
      final dept = feature.department;
      final isSelected = dept.code == selectedCode;
      if (isSelected || dept.isAvailable) continue;

      final path = _buildShapePath(feature.shape);
      fillPaint.color = AppColors.border;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }

    // 2. Pintar encima el departamento piloto (Cesar) y el seleccionado
    // para que su borde azul no quede tapado por vecinos adyacentes.
    for (final feature in features) {
      final dept = feature.department;
      final isSelected = dept.code == selectedCode;
      if (!isSelected && !dept.isAvailable) continue;

      final path = _buildShapePath(feature.shape);
      if (dept.isAvailable) {
        fillPaint.color = isSelected
            ? AppColors.primary.withValues(alpha: 0.34)
            : AppColors.primarySoft;
      } else {
        fillPaint.color = AppColors.primary.withValues(alpha: 0.22);
      }
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, selectedBorderPaint);
    }

    // 3. Adorno ilustrado sutil de flores amarillas de Cañaguate alrededor del piloto (Cesar)
    if (cesarAnchor != null) {
      _paintSubtleCanaguateGarnish(
        canvas,
        Offset(cesarAnchor!.x, cesarAnchor!.y),
      );
    }

    // 4. Recuadro guía alrededor del archipiélago de San Andrés y Providencia (esquina sup. izq.)
    final insetRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-8, -8, 42, 62),
      const Radius.circular(AppRadius.sm),
    );
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = selectedCode == Departments.sanAndres.code
          ? AppColors.primary
          : AppColors.textSecondary.withValues(alpha: 0.5)
      ..strokeWidth = 1.6;
    canvas.drawRRect(insetRect, insetPaint);
  }

  void _paintSubtleCanaguateGarnish(Canvas canvas, Offset anchor) {
    const goldColor = Color(0xFFFFCA28);
    _drawMiniBlossom(canvas, Offset(anchor.dx + 22, anchor.dy - 28), 6.0, goldColor);
    _drawMiniBlossom(canvas, Offset(anchor.dx - 24, anchor.dy + 20), 5.2, goldColor);
    _drawMiniBlossom(canvas, Offset(anchor.dx + 18, anchor.dy + 24), 4.6, goldColor);
  }

  void _drawMiniBlossom(
    Canvas canvas,
    Offset center,
    double radius,
    Color petalColor,
  ) {
    final petalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = petalColor;
    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
      final offset = Offset(
        center.dx + math.cos(angle) * (radius * 0.6),
        center.dy + math.sin(angle) * (radius * 0.6),
      );
      canvas.drawCircle(offset, radius * 0.52, petalPaint);
    }
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE65100);
    canvas.drawCircle(center, radius * 0.28, corePaint);
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

class _SanAndresInsetChip extends StatelessWidget {
  const _SanAndresInsetChip({
    required this.isSelected,
    required this.onTap,
  });

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
                  Icons.public,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'map.san_andres_inset'.tr(),
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
    required this.onTap,
  });

  final Department department;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCA28).withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 13,
                      color: Color(0xFFD84315),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    department.name,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
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
