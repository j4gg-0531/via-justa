import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/features/home/domain/settler_installation_guide.dart';

void main() {
  group('settlerChecklistProgress', () {
    test('calcula la proporción exacta e ignora identificadores desconocidos', () {
      expect(settlerChecklistProgress(const <String>{}), 0.0);
      expect(
        settlerChecklistProgress(const <String>{'unknown_step'}),
        0.0,
      );
      expect(
        settlerChecklistProgress(const <String>{
          'lease_law_820',
          'civic_rights',
        }),
        closeTo(0.5, 0.001),
      );
      expect(
        settlerChecklistProgress(const <String>{
          'lease_law_820',
          'civic_rights',
          'reference_fares',
          'local_directory',
        }),
        closeTo(1.0, 0.001),
      );
    });
  });

  group('VjConfirmDialog', () {
    testWidgets(
      'muestra cabecera centrada y botones 50/50 del mismo ancho y >= 48dp en 360dp',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showVjConfirmDialog(
                        context: context,
                        icon: Icons.logout_rounded,
                        tone: VjModalTone.destructive,
                        title: '¿Cerrar sesión?',
                        body: 'Tendrás que volver a ingresar tus datos.',
                        cancelLabel: 'Cerrar',
                        confirmLabel: 'Cerrar sesión',
                      );
                    },
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(find.byType(VjConfirmDialog), findsOneWidget);

        final cancelFinder = find.widgetWithText(VjButton, 'Cerrar');
        final confirmFinder = find.widgetWithText(VjButton, 'Cerrar sesión');
        expect(cancelFinder, findsOneWidget);
        expect(confirmFinder, findsOneWidget);

        final cancelRect = tester.getRect(cancelFinder);
        final confirmRect = tester.getRect(confirmFinder);

        // Misma fila (botones 50/50 lado a lado), mismo ancho y alto >= 48dp.
        expect(cancelRect.top, closeTo(confirmRect.top, 1.0));
        expect(cancelRect.width, closeTo(confirmRect.width, 2.0));
        expect(cancelRect.height, greaterThanOrEqualTo(48.0));
        expect(confirmRect.height, greaterThanOrEqualTo(48.0));
        expect(cancelRect.right, lessThan(confirmRect.left));

        await tester.tap(confirmFinder);
        await tester.pumpAndSettle();

        expect(result, isTrue);
        expect(find.byType(VjConfirmDialog), findsNothing);
      },
    );

    testWidgets(
      'se apila verticalmente sin overflow en 360dp con escala de texto 2.0x',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool? result;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        result = await showVjConfirmDialog(
                          context: context,
                          icon: Icons.my_location_rounded,
                          title: 'Permiso de ubicación',
                          body:
                              'Permite detectar tu zona automáticamente o elige un punto en el mapa.',
                          cancelLabel: 'No permitir (usar mapa)',
                          confirmLabel: 'Permitir ubicación',
                        );
                      },
                      child: const Text('Abrir'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        final confirmRect = tester.getRect(
          find.widgetWithText(VjButton, 'Permitir ubicación'),
        );
        final cancelRect = tester.getRect(
          find.widgetWithText(VjButton, 'No permitir (usar mapa)'),
        );

        // En escala grande los botones se apilan verticalmente sin recorte.
        expect(confirmRect.bottom, lessThan(cancelRect.top));
        expect(confirmRect.height, greaterThanOrEqualTo(48.0));
        expect(cancelRect.height, greaterThanOrEqualTo(48.0));
        expect(tester.takeException(), isNull);

        final cancelBtn = find.widgetWithText(
          VjButton,
          'No permitir (usar mapa)',
        );
        await tester.ensureVisible(cancelBtn);
        await tester.pumpAndSettle();
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
        expect(result, isFalse);
      },
    );
  });

  group('VjModalSheet', () {
    testWidgets(
      'renderiza sin overflow en 360dp a 2.0x y con teclado visible',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              viewInsets: EdgeInsets.only(bottom: 240),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showVjModalSheet<void>(
                          context: context,
                          builder: (sheetContext) => VjModalSheet(
                            icon: Icons.article_outlined,
                            title: 'Términos de Servicio',
                            subtitle: 'Lectura clara y estructurada',
                            headerBadge: const VjBadge(label: 'Versión v1.0'),
                            footer: VjModalActionRow(
                              cancelLabel: 'Cerrar',
                              onCancel: () => Navigator.of(sheetContext).pop(),
                              confirmLabel: 'Guardar',
                              onConfirm: () => Navigator.of(sheetContext).pop(),
                            ),
                            child: Column(
                              children: List<Widget>.generate(
                                6,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Cláusula $index con información detallada para verificar desplazamiento.',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Abrir hoja'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir hoja'));
        await tester.pumpAndSettle();

        expect(find.byType(VjModalSheet), findsOneWidget);
        expect(find.text('Términos de Servicio'), findsOneWidget);
        expect(find.text('Versión v1.0'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final closeBtn = find.widgetWithText(VjButton, 'Cerrar');
        await tester.ensureVisible(closeBtn);
        await tester.pumpAndSettle();
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
        expect(find.byType(VjModalSheet), findsNothing);
      },
    );
  });
}
