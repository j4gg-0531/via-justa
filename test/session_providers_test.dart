import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/demo/demo_data.dart';
import 'package:via_justa/core/session/session_providers.dart';

void main() {
  group('session providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('displayNameProvider falls back to the demo name', () {
      expect(container.read(displayNameProvider), DemoData.userName);
    });

    test('displayNameProvider returns the registered name', () {
      container.read(userNameProvider.notifier).setName('Juan');

      expect(container.read(displayNameProvider), 'Juan');
    });
  });
}
