import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFEFF6FF);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  // Ajustado a Slate 500 (#64748B) para cumplir WCAG 2.1 AA (contraste >= 4.5:1 sobre fondo claro)
  static const textMuted = Color(0xFF64748B);

  // Colores reservados exclusivamente para el semáforo de precios (contraste WCAG AA >= 4.5:1 con blanco)
  static const semaphoreGreen = Color(0xFF15803D);
  static const semaphoreGreenSoft = Color(0xFFDCFCE7);
  static const semaphoreAmber = Color(0xFFB45309);
  static const semaphoreAmberSoft = Color(0xFFFEF3C7);
  static const semaphoreRed = Color(0xFFB91C1C);
  static const semaphoreRedSoft = Color(0xFFFEE2E2);
}
