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

/// Pantalla 3 (M03 · VJ-09) · Croquis ilustrado de los 33 territorios de Colombia
/// (32 departamentos + Bogotá, D.C.) con resaltado dinámico por zona seleccionada.
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
          // 1. Lienzo estilo Croquis de Colombia con zona seleccionada destacada
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
                    // Recuadro accesible para San Andrés y Providencia (código 88)
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
    final selectedAnchor =
        geometry.canvasAnchorForCode(selectedDepartment.code) ?? cesarAnchor;

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
                        selectedAnchor: selectedAnchor,
                      ),
                    ),
                    if (selectedAnchor != null)
                      Positioned(
                        left: selectedAnchor.x - 52,
                        top: selectedAnchor.y - 28,
                        child: _DepartmentBubble(
                          department: selectedDepartment,
                          onTap: () => _handleDepartmentSelection(
                            context,
                            ref,
                            selectedDepartment,
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

/// Pintor estilo Croquis Ilustrado de Colombia:
/// 1. Silueta celeste desplazada (`Offset(9, 8)`) exactamente como en el croquis de referencia.
/// 2. Contorno exterior continuo en tinta oscura (`#181F26`) que bordea el croquis de Colombia.
/// 3. Relleno interior celeste claro unificado con divisiones departamentales sutiles.
/// 4. Resaltado vivo de la zona/departamento seleccionado (`selectedCode`, p. ej. Cesar `20`)
///    con su borde en tinta y adornos culturales.
class _ColombiaMapPainter extends CustomPainter {
  const _ColombiaMapPainter({
    required this.features,
    required this.bounds,
    required this.selectedCode,
    this.cesarAnchor,
    this.selectedAnchor,
  });

  final List<DepartmentMapFeature> features;
  final MapBounds bounds;
  final String selectedCode;
  final MapPoint? cesarAnchor;
  final MapPoint? selectedAnchor;

  static const Color _croquisOffsetFillColor = Color(0xFFB3DCFA);
  static const Color _croquisBaseFillColor = Color(0xFFC9E6FC);
  static const Color _croquisPilotFillColor = Color(0xFFA9D6FA);
  static const Color _croquisOuterInkColor = Color(0xFF181F26);
  static const Color _croquisInternalLineColor = Color(0xFF8ABBE6);

  @override
  void paint(Canvas canvas, Size size) {
    final pathsByCode = <String, Path>{};
    for (final feature in features) {
      pathsByCode[feature.department.code] = _buildShapePath(feature.shape);
    }

    // 1. Capa de sombra/relleno celeste desplazada (efecto croquis offset)
    final offsetFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _croquisOffsetFillColor;
    canvas.save();
    canvas.translate(9.0, 8.0);
    for (final path in pathsByCode.values) {
      canvas.drawPath(path, offsetFillPaint);
    }
    canvas.restore();

    // 2. Contorno exterior en tinta oscura del croquis de Colombia:
    // Al trazar primero el borde grueso negro en todos los polígonos y luego
    // rellenar el interior encima, las fronteras internas quedan cubiertas y
    // solo sobresale el trazo negro continuo de la silueta exterior de Colombia.
    final outerInkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _croquisOuterInkColor
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.5;
    for (final path in pathsByCode.values) {
      canvas.drawPath(path, outerInkPaint);
    }

    // 3. Relleno interior celeste del croquis y líneas divisorias internas sutiles
    final baseFillPaint = Paint()..style = PaintingStyle.fill;
    final internalStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _croquisInternalLineColor.withValues(alpha: 0.65)
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.1;

    for (final feature in features) {
      final dept = feature.department;
      final path = pathsByCode[dept.code]!;
      baseFillPaint.color = dept.isAvailable
          ? _croquisPilotFillColor
          : _croquisBaseFillColor;
      canvas.drawPath(path, baseFillPaint);
      canvas.drawPath(path, internalStrokePaint);
    }

    // 4. Destacar encima la zona/departamento actualmente seleccionado (ej. Cesar)
    for (final feature in features) {
      final dept = feature.department;
      if (dept.code != selectedCode) continue;

      final path = pathsByCode[dept.code]!;
      final identity = CityVisualIdentityCatalog.forDepartment(dept.code);
      final accentColor = Color(identity.accentHex);

      // Relleno destacado de la zona seleccionada
      final selectedFillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = dept.isAvailable
            ? const Color(0xFF3B82F6).withValues(alpha: 0.82)
            : accentColor.withValues(alpha: 0.72);

      // Contorno tipo croquis para separar con nitidez la zona seleccionada
      final selectedBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = _croquisOuterInkColor
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2;

      canvas.drawPath(path, selectedFillPaint);
      canvas.drawPath(path, selectedBorderPaint);
    }

    // 5. Adorno ilustrado sutil de flores amarillas de Cañaguate alrededor del Cesar
    if (cesarAnchor != null) {
      _paintSubtleCanaguateGarnish(
        canvas,
        Offset(cesarAnchor!.x, cesarAnchor!.y),
      );
    }

    // 6. Recuadro guía alrededor del archipiélago de San Andrés y Providencia (esquina sup. izq.)
    final insetRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-8, -8, 42, 62),
      const Radius.circular(AppRadius.sm),
    );
    final insetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = selectedCode == Departments.sanAndres.code
          ? AppColors.primary
          : _croquisOuterInkColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.8;
    canvas.drawRRect(insetRect, insetPaint);
  }

  void _paintSubtleCanaguateGarnish(Canvas canvas, Offset anchor) {
    const goldColor = Color(0xFFFFCA28);
    _drawMiniBlossom(
      canvas,
      Offset(anchor.dx + 22, anchor.dy - 28),
      6.2,
      goldColor,
    );
    _drawMiniBlossom(
      canvas,
      Offset(anchor.dx - 24, anchor.dy + 20),
      5.4,
      goldColor,
    );
    _drawMiniBlossom(
      canvas,
      Offset(anchor.dx + 18, anchor.dy + 24),
      4.8,
      goldColor,
    );
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
                border: Border.all(color: const Color(0xFF181F26), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
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
                      color: const Color(0xFFFFCA28).withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      department.isAvailable
                          ? Icons.music_note_rounded
                          : Icons.place_rounded,
                      size: 13,
                      color: department.isAvailable
                          ? const Color(0xFFD84315)
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    department.name,
                    style: const TextStyle(
                      color: Color(0xFF181F26),
                      fontWeight: FontWeight.w800,
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
