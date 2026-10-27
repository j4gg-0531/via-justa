import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_search_field.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/presentation/state/map_providers.dart';

/// Pantalla 3 · Mapa de departamentos con buscador.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  late final List<_MapDepartment> _departments;

  @override
  void initState() {
    super.initState();
    _departments = _buildDepartments();
  }

  // FORMAS PROVISIONALES, no es geografía real; el mapa real es de la semana 2.
  List<_MapDepartment> _buildDepartments() {
    return [
      _MapDepartment(
        department: Departments.norteDeSantander,
        path: Path()..addOval(const Rect.fromLTWH(125, 110, 120, 150)),
        color: const Color(0xFFFCE4EC), // Rosa claro provisional
      ),
      _MapDepartment(
        department: Departments.magdalena,
        path: Path()..addOval(const Rect.fromLTWH(110, 85, 80, 80)),
        color: const Color(0xFFE8F5E9), // Verde claro provisional
      ),
      _MapDepartment(
        department: Departments.laGuajira,
        path: Path()..addOval(const Rect.fromLTWH(50, 105, 70, 90)),
        color: const Color(0xFFE3F2FD), // Azul claro provisional
      ),
      _MapDepartment(
        department: Departments.cesar,
        path: Path()..addOval(const Rect.fromLTWH(115, 30, 70, 62)),
        color: const Color(0xFFFFF9C4), // Amarillo claro provisional
      ),
    ];
  }

  void _onDepartmentTap(Department department) {
    FocusScope.of(context).unfocus();
    if (department.isAvailable) {
      context.push(AppRoutes.departmentPath(department.code));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('map.unavailable'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(departmentQueryProvider);
    final suggestions = ref.watch(filteredDepartmentsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa con zoom y pan
          Semantics(
            label: 'map.semantics'.tr(),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      children: [
                        // Fondo del lienzo
                        Container(color: AppColors.border),
                        // Formas de departamentos
                        CustomPaint(
                          size: const Size(300, 300),
                          painter: _MapPainter(_departments),
                        ),
                        // Detección de toque + burbujas
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) {
                            // Evaluar en orden inverso (el último pintado = encima)
                            for (final dept in _departments.reversed) {
                              if (dept.path.contains(details.localPosition)) {
                                _onDepartmentTap(dept.department);
                                break;
                              }
                            }
                          },
                          child: Stack(
                            children: [
                              // Burbuja de Cesar
                              Positioned(
                                left: 130,
                                top: 10,
                                child: _DepartmentBubble(
                                  department: Departments.cesar,
                                  onTap: () =>
                                      _onDepartmentTap(Departments.cesar),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Buscador flotante arriba
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: VjSearchField(
                  hint: 'map.search_hint'.tr(),
                  onChanged:
                      ref.read(departmentQueryProvider.notifier).setQuery,
                ),
              ),
            ),
          ),

          // Sugerencias del buscador
          if (query.trim().isNotEmpty)
            Positioned(
              top: 100,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: VjCard(
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
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: suggestions.map((dept) {
                          return ListTile(
                            title: Text(dept.name),
                            onTap: () {
                              _onDepartmentTap(dept);
                              ref
                                  .read(departmentQueryProvider.notifier)
                                  .setQuery('');
                            },
                          );
                        }).toList(),
                      ),
              ),
            ),

          // Rótulo honesto abajo a la izquierda
          Positioned(
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            child: Text(
              'map.sample_note'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapDepartment {
  _MapDepartment({
    required this.department,
    required this.path,
    required this.color,
  });

  final Department department;
  final Path path;
  final Color color;
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.departments);

  final List<_MapDepartment> departments;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 1.5;

    for (final dept in departments) {
      paint.color = dept.color;
      canvas.drawPath(dept.path, paint);
      canvas.drawPath(dept.path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                department.name,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
