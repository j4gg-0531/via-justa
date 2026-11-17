import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/app/app.dart';
import 'package:via_justa/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'AppScrollBehavior omite StretchingOverscrollIndicator y GlowingOverscrollIndicator manteniendo el scroll normal',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(
                height: 1600,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('Contenido desplazable'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);

      // Verifica que el scroll vertical normal siga funcionando.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    },
  );
}
