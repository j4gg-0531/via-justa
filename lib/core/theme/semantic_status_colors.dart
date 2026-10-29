import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis_result.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Paleta accesible (fondo, primer plano, borde e ícono obligatorio) para un estado semántico.
class StatusVisualStyle {
  const StatusVisualStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
}

/// Extensión de tema para colores semánticos del semáforo de precios y contexto de eventos.
/// Los tonos verde, ámbar y rojo se reservan exclusivamente para veredictos de precio.
class SemanticStatusColors extends ThemeExtension<SemanticStatusColors> {
  const SemanticStatusColors({
    required this.green,
    required this.yellow,
    required this.red,
    required this.insufficient,
    required this.eventContext,
  });

  /// Configuración estándar para tema claro con contraste WCAG AA.
  factory SemanticStatusColors.light() {
    return const SemanticStatusColors(
      green: StatusVisualStyle(
        foreground: AppColors.semaphoreGreen,
        background: AppColors.semaphoreGreenSoft,
        border: AppColors.semaphoreGreen,
        icon: Icons.check_circle_outline,
      ),
      yellow: StatusVisualStyle(
        foreground: AppColors.semaphoreAmber,
        background: AppColors.semaphoreAmberSoft,
        border: AppColors.semaphoreAmber,
        icon: Icons.warning_amber_rounded,
      ),
      red: StatusVisualStyle(
        foreground: AppColors.semaphoreRed,
        background: AppColors.semaphoreRedSoft,
        border: AppColors.semaphoreRed,
        icon: Icons.error_outline,
      ),
      insufficient: StatusVisualStyle(
        foreground: AppColors.textSecondary,
        background: AppColors.background,
        border: AppColors.border,
        icon: Icons.hourglass_empty_rounded,
      ),
      // El contexto de evento usa azul institucional independiente, nunca colores del semáforo.
      eventContext: StatusVisualStyle(
        foreground: AppColors.primary,
        background: AppColors.primarySoft,
        border: AppColors.primary,
        icon: Icons.festival_outlined,
      ),
    );
  }

  final StatusVisualStyle green;
  final StatusVisualStyle yellow;
  final StatusVisualStyle red;
  final StatusVisualStyle insufficient;
  final StatusVisualStyle eventContext;

  /// Mapa tipado que resuelve el estilo visual exclusivamente a partir del enum cerrado `PriceVerdictLevel`.
  StatusVisualStyle styleForContractLevel(ContractAnalysisLevel level) {
    switch (level) {
      case ContractAnalysisLevel.green:
        return green;
      case ContractAnalysisLevel.yellow:
        return yellow;
      case ContractAnalysisLevel.red:
        return red;
    }
  }

  StatusVisualStyle styleForVerdict(PriceVerdictLevel level) {
    switch (level) {
      case PriceVerdictLevel.green:
        return green;
      case PriceVerdictLevel.yellow:
        return yellow;
      case PriceVerdictLevel.red:
        return red;
      case PriceVerdictLevel.insufficient:
        return insufficient;
    }
  }

  @override
  SemanticStatusColors copyWith({
    StatusVisualStyle? green,
    StatusVisualStyle? yellow,
    StatusVisualStyle? red,
    StatusVisualStyle? insufficient,
    StatusVisualStyle? eventContext,
  }) {
    return SemanticStatusColors(
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      red: red ?? this.red,
      insufficient: insufficient ?? this.insufficient,
      eventContext: eventContext ?? this.eventContext,
    );
  }

  @override
  SemanticStatusColors lerp(
    covariant ThemeExtension<SemanticStatusColors>? other,
    double t,
  ) {
    if (other is! SemanticStatusColors) return this;
    return t < 0.5 ? this : other;
  }
}
