import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logotipo oficial multicolor de Google "G" dibujado en vector nativo.
class VjGoogleMark extends StatelessWidget {
  const VjGoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const RepaintBoundary(
        child: CustomPaint(
          painter: _GoogleGPainter(),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.19;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Rojo superior
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.78, math.pi * 0.56, false, paint);

    // Amarillo izquierdo
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.76, math.pi * 0.48, false, paint);

    // Verde inferior
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.18, math.pi * 0.60, false, paint);

    // Azul derecho y barra horizontal
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.02, math.pi * 0.24, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final cy = size.height / 2;
    canvas.drawLine(
      Offset(size.width * 0.51, cy),
      Offset(size.width - stroke * 0.18, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
