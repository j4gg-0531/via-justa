import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';
import 'package:via_justa/features/auth/presentation/state/login_form_provider.dart';

void main() {
  group('loginFormProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      // Mantiene vivo el provider autoDispose durante cada prueba.
      container.listen(loginFormProvider, (previous, next) {});
    });

    test('initial state has no errors', () {
      final state = container.read(loginFormProvider);

      expect(state.emailError, isNull);
      expect(state.passwordError, isNull);
      expect(state.obscurePassword, isTrue);
      expect(state.submitted, isFalse);
    });

    test('submit with empty fields exposes both errors', () {
      final result = container.read(loginFormProvider.notifier).submit();

      expect(result, isFalse);
      final state = container.read(loginFormProvider);
      expect(state.emailError, EmailError.empty);
      expect(state.passwordError, PasswordError.empty);
    });

    test('valid values clear errors and submit returns true', () {
      final notifier = container.read(loginFormProvider.notifier);

      notifier.setEmail('a@b.co');
      notifier.setPassword('12345678');

      final state = container.read(loginFormProvider);
      expect(state.emailError, isNull);
      expect(state.passwordError, isNull);
      expect(notifier.submit(), isTrue);
    });

    test('toggleObscurePassword alternates the value', () {
      final notifier = container.read(loginFormProvider.notifier);

      expect(container.read(loginFormProvider).obscurePassword, isTrue);

      notifier.toggleObscurePassword();
      expect(container.read(loginFormProvider).obscurePassword, isFalse);

      notifier.toggleObscurePassword();
      expect(container.read(loginFormProvider).obscurePassword, isTrue);
    });

    test('errors stay hidden before the first submit', () {
      final notifier = container.read(loginFormProvider.notifier);

      notifier.setEmail('abc');
      notifier.setPassword('123');

      final state = container.read(loginFormProvider);
      expect(state.emailError, isNull);
      expect(state.passwordError, isNull);
      expect(state.isValid, isFalse);
    });
  });
}
