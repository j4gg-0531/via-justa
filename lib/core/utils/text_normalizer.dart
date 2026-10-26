/// Normaliza una cadena para búsquedas: minúsculas, sin tildes/diéresis, sin espacios extra.
String normalizeForSearch(String input) {
  const replacements = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'Á': 'a',
    'É': 'e',
    'Í': 'i',
    'Ó': 'o',
    'Ú': 'u',
    'Ü': 'u',
    'Ñ': 'n',
  };

  final buffer = StringBuffer();
  for (final char in input.trim().toLowerCase().runes) {
    final c = String.fromCharCode(char);
    buffer.write(replacements[c] ?? c);
  }
  return buffer.toString();
}