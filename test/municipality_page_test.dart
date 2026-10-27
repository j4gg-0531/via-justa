import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_repository.dart';
import 'package:via_justa/features/municipality/presentation/pages/municipality_page.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

const _municipalities = <Municipality>[
  Municipality(
    code: '20001',
    name: 'Valledupar',
    departmentCode: '20',
    isPilot: true,
  ),
  Municipality(
    code: '20011',
    name: 'Aguachica',
    departmentCode: '20',
    isPilot: false,
  ),
];

class _FakeMunicipalityRepository implements MunicipalityRepository {
  const _FakeMunicipalityRepository();

  @override
  Future<List<Municipality>> getByDepartment(String departmentCode) async =>
      _municipalities;

  @override
  Future<Municipality?> getByCode(String code) async {
    for (final municipality in _municipalities) {
      if (municipality.code == code) {
        return municipality;
      }
    }
    return null;
  }
}

Widget _buildPage(String code) {
  return ProviderScope(
    overrides: [
      municipalityRepositoryProvider.overrideWithValue(
        const _FakeMunicipalityRepository(),
      ),
    ],
    child: MaterialApp(home: MunicipalityPage(code: code)),
  );
}

void main() {
  testWidgets('pilot municipality shows the enter button', (tester) async {
    await tester.pumpWidget(_buildPage('20001'));
    await tester.pumpAndSettle();

    expect(find.text('municipality.pilot_available'), findsOneWidget);
    expect(find.text('municipality.enter'), findsOneWidget);
  });

  testWidgets('not pilot municipality registers interest', (tester) async {
    await tester.pumpWidget(_buildPage('20011'));
    await tester.pumpAndSettle();

    expect(find.text('municipality.notify_me'), findsOneWidget);
    expect(find.text('municipality.notified'), findsNothing);

    await tester.tap(find.text('municipality.notify_me'));
    await tester.pump();

    expect(find.text('municipality.notified'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('unknown code shows a controlled message', (tester) async {
    await tester.pumpWidget(_buildPage('99999'));
    await tester.pumpAndSettle();

    expect(find.text('municipality.not_found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
