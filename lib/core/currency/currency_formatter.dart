/// Modos de visualización de moneda en Vía Justa.
enum CurrencyDisplayMode {
  copOnly('cop'),
  copAndUsd('both'),
  usdOnly('usd');

  const CurrencyDisplayMode(this.storageValue);

  final String storageValue;

  static CurrencyDisplayMode? fromStorage(String? raw) {
    final clean = raw?.trim().toLowerCase();
    for (final mode in CurrencyDisplayMode.values) {
      if (mode.storageValue == clean) return mode;
    }
    return null;
  }
}

/// Tasa orientativa por defecto (COP por 1 USD) usada si el servidor no configura otra.
const int kDefaultCopPerUsd = 4100;

/// Resuelve el modo de moneda predeterminado según el idioma activo:
/// - Inglés (`en`) → `copAndUsd` (COP + equivalencia orientativa en USD).
/// - Español (`es`) u otro → `copOnly`.
CurrencyDisplayMode defaultCurrencyModeForLocale(String languageCode) {
  final normalized = languageCode.trim().toLowerCase();
  if (normalized.startsWith('en')) {
    return CurrencyDisplayMode.copAndUsd;
  }
  return CurrencyDisplayMode.copOnly;
}

/// Resuelve el modo activo respetando la preferencia explícita del usuario si existe.
CurrencyDisplayMode resolveEffectiveCurrencyMode({
  required CurrencyDisplayMode? userOverride,
  required String languageCode,
}) {
  return userOverride ?? defaultCurrencyModeForLocale(languageCode);
}

/// Parsea una tasa configurada desde JSON (`app_config`) con validación de rango seguro.
int parseValidCopPerUsdRate(Object? raw, {int fallback = kDefaultCopPerUsd}) {
  final parsed = switch (raw) {
    int v => v,
    num v => v.round(),
    String s => int.tryParse(s.trim()),
    _ => null,
  };
  if (parsed == null || parsed < 1000 || parsed > 20000) {
    return fallback;
  }
  return parsed;
}

/// Formatea un monto en pesos colombianos con separadores de miles por punto (ej. `$15.000`).
String formatCopCurrency(num amountCop, {bool includeCopSuffix = false}) {
  final rounded = amountCop.round();
  final isNegative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final prefix = isNegative ? '-\$' : '\$';
  final suffix = includeCopSuffix ? ' COP' : '';
  return '$prefix$buffer$suffix';
}

/// Formatea un monto aproximado en dólares estadounidenses (`US$3.7` o `US$132`).
String formatUsdApprox(num amountCop, {int copPerUsd = kDefaultCopPerUsd}) {
  final safeRate = copPerUsd > 0 ? copPerUsd : kDefaultCopPerUsd;
  final usd = amountCop / safeRate;
  final isNegative = usd < 0;
  final absUsd = usd.abs();
  final formatted = absUsd < 20
      ? absUsd.toStringAsFixed(1)
      : _formatIntWithCommas(absUsd.round());
  return '${isNegative ? '-' : ''}US\$$formatted';
}

String _formatIntWithCommas(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Par de cadenas (principal y secundaria opcional) para mostrar precios según el modo activo.
class FormattedMoney {
  const FormattedMoney({
    required this.primary,
    this.secondary,
  });

  final String primary;
  final String? secondary;

  /// Versión compacta en una sola línea (ej. `$15.000 · ≈ US$3.7`).
  String get inline => secondary == null ? primary : '$primary · $secondary';
}

/// Formatea un monto en COP según el modo de moneda elegido (`copOnly`, `copAndUsd`, `usdOnly`).
FormattedMoney formatMoney({
  required num amountCop,
  required CurrencyDisplayMode mode,
  int copPerUsd = kDefaultCopPerUsd,
  String suffix = '',
  bool includeCopCode = false,
}) {
  final cop = '${formatCopCurrency(amountCop, includeCopSuffix: includeCopCode)}$suffix';
  final usd = '${formatUsdApprox(amountCop, copPerUsd: copPerUsd)}$suffix';

  return switch (mode) {
    CurrencyDisplayMode.copOnly => FormattedMoney(primary: cop),
    CurrencyDisplayMode.copAndUsd => FormattedMoney(
      primary: cop,
      secondary: '≈ $usd',
    ),
    CurrencyDisplayMode.usdOnly => FormattedMoney(
      primary: usd,
      secondary: '≈ $cop',
    ),
  };
}
