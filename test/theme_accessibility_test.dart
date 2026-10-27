import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/widgets/vj_button.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Theme & Color Accessibility (WCAG 2.1 AA)', () {
    test('textPrimary satisfies WCAG AAA contrast (>= 7.0:1) on surface', () {
      final ratio = _contrastRatio(AppColors.textPrimary, AppColors.surface);
      expect(ratio, greaterThanOrEqualTo(7.0));
    });

    test('textSecondary satisfies WCAG AA contrast (>= 4.5:1) on surface and background', () {
      final ratioSurface = _contrastRatio(AppColors.textSecondary, AppColors.surface);
      final ratioBg = _contrastRatio(AppColors.textSecondary, AppColors.background);
      expect(ratioSurface, greaterThanOrEqualTo(4.5));
      expect(ratioBg, greaterThanOrEqualTo(4.5));
    });

    test('textMuted satisfies WCAG AA contrast (>= 4.5:1) on surface and background', () {
      final ratioSurface = _contrastRatio(AppColors.textMuted, AppColors.surface);
      final ratioBg = _contrastRatio(AppColors.textMuted, AppColors.background);
      expect(ratioSurface, greaterThanOrEqualTo(4.5));
      expect(ratioBg, greaterThanOrEqualTo(4.5));
    });

    test('primary color satisfies WCAG AA large text contrast (>= 3.0:1) on white', () {
      final ratio = _contrastRatio(AppColors.primary, AppColors.surface);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });
  });

  group('Widget Accessibility - Touch Targets (>= 48 dp)', () {
    testWidgets('VjButton has minimum touch target height of at least 48 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VjButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(FilledButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
