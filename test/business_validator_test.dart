import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_validator.dart';

void main() {
  const valid = BusinessDraft(
    fields: {
      BusinessField.name: 'Cocina del patio',
      BusinessField.descriptionEs: 'Comida tradicional preparada cada día.',
      BusinessField.address: 'Calle 10 número 20',
      BusinessField.whatsapp: '+57 (300) 123-4567',
    },
    latitude: 10.47,
    longitude: -73.24,
    zoneId: 'centro',
    whatsappConsent: true,
    publicationConsent: true,
  );
  test('validación completa y normalización de contacto', () {
    for (var step = 0; step < 4; step++) {
      expect(validateBusinessStep(valid, step), isNull);
    }
    expect(
      normalizeBusinessPhone('+57 (300) 123-4567', whatsapp: true),
      '573001234567',
    );
    expect(
      validateBusinessStep(valid.copyWith(whatsappConsent: false), 1),
      'whatsappConsent',
    );
    expect(
      validateBusinessStep(valid.copyWith(publicationConsent: false), 3),
      'publicationConsent',
    );
    expect(
      validateBusinessStep(valid.copyWith(latitude: double.nan), 1),
      'location',
    );
  });
  test('rechaza identidades y contactos inválidos', () {
    for (final name in ['ab', '[DEMO] Cocina', '<b>Cocina</b>', '12345']) {
      expect(
        validateBusinessStep(
          valid.copyWith(fields: {...valid.fields, BusinessField.name: name}),
          0,
        ),
        'name',
      );
    }
    expect(
      validateBusinessStep(
        valid.copyWith(
          fields: {...valid.fields, BusinessField.descriptionEn: 'short'},
        ),
        0,
      ),
      'description',
    );
    expect(
      validateBusinessStep(
        valid.copyWith(fields: {...valid.fields, BusinessField.whatsapp: ''}),
        1,
      ),
      'contact',
    );
    expect(
      validateBusinessStep(
        valid.copyWith(fields: {...valid.fields, BusinessField.phone: 'abc'}),
        1,
      ),
      'phone',
    );
  });
  test('enlace único cumple el contrato HTTPS de la base de datos', () {
    for (final url in [
      '',
      'https://vinapp.co/local/menu?mesa=2',
      'https://mi-negocio.co',
    ]) {
      expect(isValidBusinessOrderUrl(url), isTrue, reason: url);
    }
    for (final url in [
      'http://vinapp.co',
      'https://user:pass@vinapp.co',
      'https://-bad.co',
      'https://a..co',
      'https://a.co:bad',
      'https://a.co/<script>',
    ]) {
      expect(isValidBusinessOrderUrl(url), isFalse, reason: url);
    }
  });
  test('horarios nocturnos válidos, precios y cantidad limitados', () {
    expect(
      validateBusinessStep(
        valid.copyWith(
          hours: {
            'mon': const BusinessDayHours(
              enabled: true,
              open: '18:00',
              close: '02:00',
            ),
          },
        ),
        2,
      ),
      isNull,
    );
    for (final close in ['25:00', '08:00', '24:01']) {
      expect(
        validateBusinessStep(
          valid.copyWith(
            hours: {'mon': BusinessDayHours(enabled: true, close: close)},
          ),
          2,
        ),
        'hours',
      );
    }
    for (final price in ['499', '20000001', '12.50', 'abc']) {
      expect(
        validateBusinessStep(
          valid.copyWith(
            dishes: [BusinessDishDraft(name: 'Almuerzo', price: price)],
          ),
          2,
        ),
        'dish',
      );
    }
    expect(
      validateBusinessStep(
        valid.copyWith(
          dishes: List.filled(
            6,
            const BusinessDishDraft(name: 'Almuerzo', price: '15000'),
          ),
        ),
        2,
      ),
      'dishes',
    );
  });
  test('firmas y tamaño de imágenes', () {
    expect(
      businessImageExtension([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]),
      'png',
    );
    expect(
      businessImageExtension([255, 216, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      'jpg',
    );
    expect(businessImageExtension('RIFF0000WEBP'.codeUnits), 'webp');
    expect(businessImageExtension('%PDF-123456789'.codeUnits), isNull);
    expect(businessImageExtension([255, 216, 255]), isNull);
    expect(businessImageExtension(List.filled(5 * 1024 * 1024 + 1, 0)), isNull);
  });
}
