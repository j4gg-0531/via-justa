import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

/// Bloque de carga animado (esqueleto) respetando `disableAnimationsOf`.
class VjSkeletonBox extends StatefulWidget {
  const VjSkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppRadius.lg,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<VjSkeletonBox> createState() => _VjSkeletonBoxState();
}

class _VjSkeletonBoxState extends State<VjSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final alpha = 0.45 + (_controller.value * 0.45);
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
          );
        },
      ),
    );
  }
}
