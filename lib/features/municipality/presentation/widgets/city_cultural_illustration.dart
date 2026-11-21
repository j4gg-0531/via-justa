import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/features/municipality/domain/city_visual_identity.dart';

/// Banner ilustrado 16:9 con identidad cultural y chips simbólicos para la
/// pantalla de detalle de municipio (`M14` Piloto y `M15` No Piloto).
class CityCulturalIllustrationBanner extends StatelessWidget {
  const CityCulturalIllustrationBanner({
    super.key,
    required this.identity,
    required this.cityName,
    this.departmentName,
    this.isPilot = false,
  });

  final CityVisualIdentity identity;
  final String cityName;
  final String? departmentName;
  final bool isPilot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accentColor = Color(identity.accentHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: CustomPaint(
                    painter: CulturalLandscapePainter(
                      identity: identity,
                      showCenterpiece: true,
                    ),
                  ),
                ),
                // Sutil etiqueta inferior con el subtítulo cultural del territorio
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0A1D30),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _iconForMotif(identity.motif),
                          size: 16,
                          color: accentColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            identity.subtitleKey.tr(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < identity.featureChipKeys.length; i++)
              _CulturalFeaturePill(
                label: identity.featureChipKeys[i].tr(),
                accentColor: accentColor,
              ),
          ],
        ),
      ],
    );
  }
}

class _CulturalFeaturePill extends StatelessWidget {
  const _CulturalFeaturePill({
    required this.label,
    required this.accentColor,
  });

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emblema compacto ilustrado para tarjetas de departamento (`M03`) y filas de
/// municipio (`M13`), con flores de cañaguate y símbolo regional.
class DepartmentCulturalEmblemBadge extends StatelessWidget {
  const DepartmentCulturalEmblemBadge({
    super.key,
    required this.identity,
    this.size = 44,
    this.highlight = false,
  });

  final CityVisualIdentity identity;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(identity.accentHex);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                painter: CulturalLandscapePainter(
                  identity: identity,
                  showCenterpiece: false,
                ),
              ),
            ),
            Center(
              child: Icon(
                _iconForMotif(identity.motif),
                size: size * 0.48,
                color: highlight ? accentColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medallón central ilustrado para la cabecera del selector de municipios (`M13`),
/// que dibuja el Acordeón Vallenato y las flores de Cañaguate cuando se explora el Cesar.
class CulturalHeaderMedallion extends StatelessWidget {
  const CulturalHeaderMedallion({
    super.key,
    required this.identity,
  });

  final CityVisualIdentity identity;

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(identity.accentHex);

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Color(identity.skyStartHex).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accentColor,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: CustomPaint(
          painter: _MedallionEmblemPainter(identity: identity),
        ),
      ),
    );
  }
}

IconData _iconForMotif(CulturalMotifKind motif) {
  switch (motif) {
    case CulturalMotifKind.valleduparCanaguateAccordion:
      return Icons.music_note_rounded;
    case CulturalMotifKind.cesarSerraniaCoffee:
    case CulturalMotifKind.coffeeFlowersValley:
      return Icons.local_florist_rounded;
    case CulturalMotifKind.cesarZapatosaLagoon:
    case CulturalMotifKind.carnavalMagdalenaRiver:
    case CulturalMotifKind.amazonSelvaRivers:
      return Icons.water_rounded;
    case CulturalMotifKind.cesarSavannaCotton:
    case CulturalMotifKind.llanosOrinocoSunrise:
      return Icons.wb_sunny_rounded;
    case CulturalMotifKind.caribbeanWalledSea:
      return Icons.account_balance_rounded;
    case CulturalMotifKind.sierraSnowyCoast:
    case CulturalMotifKind.andeanCapitalPeaks:
      return Icons.terrain_rounded;
    case CulturalMotifKind.wayuuDesertDunes:
    case CulturalMotifKind.sevenColorsArchipelago:
    case CulturalMotifKind.pacificPalmsBreeze:
      return Icons.beach_access_rounded;
  }
}

/// Pintor vectorial que dibuja el paisaje cultural sutil:
/// - Cielo degradado y resplandor solar.
/// - Silueta de la Sierra Nevada de Santa Marta y Serranía del Perijá.
/// - Ondas del Río Guatapurí / Mar Caribe / Ciénaga de Zapatosa.
/// - Árbol y flores amarillas de Cañaguate (`Handroanthus chrysanthus`).
/// - Acordeón Vallenato estilizado y notas musicales cuando `showCenterpiece` es true.
class CulturalLandscapePainter extends CustomPainter {
  const CulturalLandscapePainter({
    required this.identity,
    this.showCenterpiece = true,
  });

  final CityVisualIdentity identity;
  final bool showCenterpiece;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final skyStart = Color(identity.skyStartHex);
    final skyEnd = Color(identity.skyEndHex);
    final accent = Color(identity.accentHex);
    final secondary = Color(identity.secondaryHex);

    // 1. Cielo degradado
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[skyStart, skyEnd],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // 2. Resplandor solar cálido (sol cesarense / caribeño)
    final sunCenter = Offset(size.width * 0.78, size.height * 0.26);
    final sunGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accent.withValues(alpha: 0.42),
          accent.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: sunCenter, radius: size.shortestSide * 0.45),
      );
    canvas.drawCircle(sunCenter, size.shortestSide * 0.45, sunGlowPaint);

    final sunCorePaint = Paint()..color = accent.withValues(alpha: 0.85);
    canvas.drawCircle(sunCenter, size.shortestSide * 0.10, sunCorePaint);

    // 3. Cordillera / Sierra Nevada de Santa Marta y Serranía del Perijá
    final farMountainPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..lineTo(size.width * 0.18, size.height * 0.46)
      ..lineTo(size.width * 0.36, size.height * 0.60)
      ..lineTo(size.width * 0.56, size.height * 0.38)
      ..lineTo(size.width * 0.76, size.height * 0.58)
      ..lineTo(size.width, size.height * 0.44)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final farMountainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawPath(farMountainPath, farMountainPaint);

    final nearMountainPath = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.56,
        size.width * 0.48,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.54,
        size.width,
        size.height * 0.70,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final nearMountainPaint = Paint()
      ..color = secondary.withValues(alpha: 0.30);
    canvas.drawPath(nearMountainPath, nearMountainPaint);

    // 4. Ondas del Río Guatapurí / cuerpo de agua en la base
    final riverPath = Path()
      ..moveTo(0, size.height * 0.84)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.76,
        size.width * 0.62,
        size.height * 0.92,
        size.width,
        size.height * 0.80,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final riverPaint = Paint()
      ..color = secondary.withValues(alpha: 0.55);
    canvas.drawPath(riverPath, riverPaint);

    // Líneas sutiles de corriente de agua
    final waveStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.28);
    final waveLine = Path()
      ..moveTo(size.width * 0.08, size.height * 0.89)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.84,
        size.width * 0.58,
        size.height * 0.90,
      );
    canvas.drawPath(waveLine, waveStroke);

    // 5. Ramas y flores amarillas de Cañaguate en las esquinas superiores
    _paintCanaguateBranchAndBlossoms(
      canvas: canvas,
      size: size,
      blossomColor: accent,
    );

    // 6. Emblema central (Acordeón vallenato en Valledupar/Cesar o motivo regional)
    if (showCenterpiece) {
      if (identity.motif == CulturalMotifKind.valleduparCanaguateAccordion) {
        _paintVallenatoAccordion(
          canvas: canvas,
          center: Offset(size.width * 0.50, size.height * 0.52),
          scale: size.shortestSide / 180.0,
          accent: accent,
        );
      } else {
        _paintRegionalEmblemSilhouette(
          canvas: canvas,
          center: Offset(size.width * 0.50, size.height * 0.50),
          scale: size.shortestSide / 180.0,
          accent: accent,
          motif: identity.motif,
        );
      }
    }
  }

  void _paintCanaguateBranchAndBlossoms({
    required Canvas canvas,
    required Size size,
    required Color blossomColor,
  }) {
    final branchPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.shortestSide * 0.022).clamp(1.2, 3.2)
      ..color = const Color(0xFF4E342E).withValues(alpha: 0.75);

    // Rama izquierda de Cañaguate
    final leftBranch = Path()
      ..moveTo(0, size.height * 0.38)
      ..quadraticBezierTo(
        size.width * 0.14,
        size.height * 0.26,
        size.width * 0.28,
        size.height * 0.16,
      );
    canvas.drawPath(leftBranch, branchPaint);

    final twig = Path()
      ..moveTo(size.width * 0.13, size.height * 0.27)
      ..quadraticBezierTo(
        size.width * 0.19,
        size.height * 0.34,
        size.width * 0.25,
        size.height * 0.31,
      );
    canvas.drawPath(twig, branchPaint);

    // Racimos de flores amarillas del Cañaguate (5 pétalos cada flor)
    final r = (size.shortestSide * 0.055).clamp(3.0, 11.0);
    _drawCanaguateFlower(
      canvas,
      Offset(size.width * 0.10, size.height * 0.22),
      r * 1.15,
      blossomColor,
    );
    _drawCanaguateFlower(
      canvas,
      Offset(size.width * 0.20, size.height * 0.16),
      r * 0.95,
      blossomColor,
    );
    _drawCanaguateFlower(
      canvas,
      Offset(size.width * 0.27, size.height * 0.18),
      r * 1.05,
      blossomColor,
    );
    _drawCanaguateFlower(
      canvas,
      Offset(size.width * 0.23, size.height * 0.30),
      r * 0.85,
      blossomColor,
    );

    if (showCenterpiece) {
      // Racimo sutil superior derecho
      _drawCanaguateFlower(
        canvas,
        Offset(size.width * 0.88, size.height * 0.18),
        r * 0.90,
        blossomColor,
      );
      _drawCanaguateFlower(
        canvas,
        Offset(size.width * 0.93, size.height * 0.28),
        r * 0.75,
        blossomColor,
      );
    }
  }

  static void _drawCanaguateFlower(
    Canvas canvas,
    Offset center,
    double radius,
    Color petalColor,
  ) {
    final petalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = petalColor.withValues(alpha: 0.92);

    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
      final petalOffset = Offset(
        center.dx + math.cos(angle) * (radius * 0.62),
        center.dy + math.sin(angle) * (radius * 0.62),
      );
      canvas.drawCircle(petalOffset, radius * 0.52, petalPaint);
    }

    // Centro cálido ámbar de la flor de cañaguate
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE65100);
    canvas.drawCircle(center, radius * 0.26, corePaint);
  }

  static void _paintVallenatoAccordion({
    required Canvas canvas,
    required Offset center,
    required double scale,
    required Color accent,
  }) {
    final s = scale.clamp(0.55, 1.45);
    // Halo circular sutil detrás del acordeón
    final haloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, 36 * s, haloPaint);

    // Cajas laterales del acordeón (rojo coral / dorado tradicional vallenato)
    final boxPaint = Paint()
      ..color = const Color(0xFFD84315)
      ..style = PaintingStyle.fill;
    final boxBorderPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s;

    final leftBox = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - 20 * s, center.dy),
        width: 14 * s,
        height: 36 * s,
      ),
      Radius.circular(3.5 * s),
    );
    final rightBox = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + 20 * s, center.dy),
        width: 14 * s,
        height: 36 * s,
      ),
      Radius.circular(3.5 * s),
    );
    canvas.drawRRect(leftBox, boxPaint);
    canvas.drawRRect(leftBox, boxBorderPaint);
    canvas.drawRRect(rightBox, boxPaint);
    canvas.drawRRect(rightBox, boxBorderPaint);

    // Fuelle central plisado (4 pliegues blancos/crema con borde oscuro)
    final bellowsPaint = Paint()
      ..color = const Color(0xFFFFF8E1)
      ..style = PaintingStyle.fill;
    final foldStroke = Paint()
      ..color = const Color(0xFF263238).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * s;

    for (var i = -1; i <= 1; i++) {
      final foldRect = Rect.fromCenter(
        center: Offset(center.dx + (i * 8.0 * s), center.dy),
        width: 6.8 * s,
        height: 30 * s,
      );
      canvas.drawRect(foldRect, bellowsPaint);
      canvas.drawRect(foldRect, foldStroke);
    }

    // Hilera de botones nacarados (3 hileras simbólicas del acordeón vallenato)
    final buttonPaint = Paint()..color = Colors.white;
    for (var row = -1; row <= 1; row++) {
      final by = center.dy + (row * 8.0 * s);
      canvas.drawCircle(Offset(center.dx - 20 * s, by), 2.1 * s, buttonPaint);
      canvas.drawCircle(Offset(center.dx + 20 * s, by), 2.1 * s, buttonPaint);
    }
  }

  static void _paintRegionalEmblemSilhouette({
    required Canvas canvas,
    required Offset center,
    required double scale,
    required Color accent,
    required CulturalMotifKind motif,
  }) {
    final s = scale.clamp(0.55, 1.45);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..color = accent.withValues(alpha: 0.65);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.14);

    canvas.drawCircle(center, 28 * s, fillPaint);
    canvas.drawCircle(center, 28 * s, ringPaint);

    // Dibuja una flor de cañaguate / sol estilizado en el centro
    _drawCanaguateFlower(canvas, center, 14 * s, accent);
  }

  @override
  bool shouldRepaint(covariant CulturalLandscapePainter oldDelegate) {
    return oldDelegate.identity.motif != identity.motif ||
        oldDelegate.showCenterpiece != showCenterpiece;
  }
}

class _MedallionEmblemPainter extends CustomPainter {
  const _MedallionEmblemPainter({required this.identity});

  final CityVisualIdentity identity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final accent = Color(identity.accentHex);

    // Flor de cañaguate en la esquina superior izquierda del medallón
    CulturalLandscapePainter._drawCanaguateFlower(
      canvas,
      Offset(size.width * 0.22, size.height * 0.22),
      8.5,
      accent,
    );
    CulturalLandscapePainter._drawCanaguateFlower(
      canvas,
      Offset(size.width * 0.80, size.height * 0.24),
      7.0,
      accent,
    );

    if (identity.motif == CulturalMotifKind.valleduparCanaguateAccordion) {
      CulturalLandscapePainter._paintVallenatoAccordion(
        canvas: canvas,
        center: Offset(center.dx, center.dy + 4),
        scale: 0.82,
        accent: accent,
      );
    } else {
      CulturalLandscapePainter._paintRegionalEmblemSilhouette(
        canvas: canvas,
        center: center,
        scale: 0.85,
        accent: accent,
        motif: identity.motif,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MedallionEmblemPainter oldDelegate) {
    return oldDelegate.identity.motif != identity.motif;
  }
}
