import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

void main() {
  group('municipalityInterestProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('register adds the municipality code', () {
      container.read(municipalityInterestProvider.notifier).register('20001');

      expect(container.read(municipalityInterestProvider), {'20001'});
    });

    test('registering the same code twice does not duplicate it', () {
      final notifier = container.read(municipalityInterestProvider.notifier);

      notifier.register('20001');
      notifier.register('20001');

      expect(container.read(municipalityInterestProvider), {'20001'});
    });

    test('different codes accumulate', () {
      final notifier = container.read(municipalityInterestProvider.notifier);

      notifier.register('20001');
      notifier.register('20011');

      expect(container.read(municipalityInterestProvider), {'20001', '20011'});
    });
  });
}
