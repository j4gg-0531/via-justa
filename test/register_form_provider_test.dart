import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';
import 'package:via_justa/features/auth/presentation/state/register_form_provider.dart';

void main() {
  group('registerFormProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      // Mantiene vivo el provider autoDispose durante cada prueba.
      container.listen(registerFormProvider, (previous, next) {});
    });

    test('submit with empty fields exposes the four errors', () {
      final result = container.read(registerFormProvider.notifier).submit();

      expect(result, isFalse);
      final state = container.read(registerFormProvider);
      expect(state.nameError, NameError.empty);
      expect(state.emailError, EmailError.empty);
      expect(state.passwordError, PasswordError.empty);
      expect(state.termsError, isTrue);
      expect(container.read(userNameProvider), isNull);
    });

    test('valid data without accepted terms fails with terms error', () {
      final notifier = container.read(registerFormProvider.notifier);

      notifier.setName('Juan García');
      notifier.setEmail('juan@correo.com');
      notifier.setPassword('12345678');

      expect(notifier.submit(), isFalse);
      final state = container.read(registerFormProvider);
      expect(state.nameError, isNull);
      expect(state.emailError, isNull);
      expect(state.passwordError, isNull);
      expect(state.termsError, isTrue);
      expect(container.read(userNameProvider), isNull);
    });

    test('valid form saves the first name and submits', () {
      final notifier = container.read(registerFormProvider.notifier);

      notifier.setName('Juan García');
      notifier.setEmail('juan@correo.com');
      notifier.setPassword('12345678');
      notifier.setTermsAccepted(true);

      expect(notifier.submit(), isTrue);
      expect(container.read(userNameProvider), 'Juan');
    });

    test('an invalid submit does not change the saved name', () {
      container.read(userNameProvider.notifier).setName('Pedro');
      final notifier = container.read(registerFormProvider.notifier);

      notifier.setName('Juan García');
      notifier.setEmail('correo-invalido');
      notifier.setPassword('123');
      notifier.setTermsAccepted(false);

      expect(notifier.submit(), isFalse);
      expect(container.read(userNameProvider), 'Pedro');
    });

    test('toggleObscurePassword alternates the value', () {
      final notifier = container.read(registerFormProvider.notifier);

      expect(container.read(registerFormProvider).obscurePassword, isTrue);

      notifier.toggleObscurePassword();
      expect(container.read(registerFormProvider).obscurePassword, isFalse);

      notifier.toggleObscurePassword();
      expect(container.read(registerFormProvider).obscurePassword, isTrue);
    });
  });
}
