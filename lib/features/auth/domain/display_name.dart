/// Primer nombre de un nombre completo, para el saludo. Vacío si no hay texto.
String firstName(String fullName) {
  return fullName.trim().split(RegExp(r'\s+')).first;
}
