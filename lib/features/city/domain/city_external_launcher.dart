/// Contrato para abrir URLs verificadas (`https://`) de fuentes culturales.
abstract interface class CityExternalLauncher {
  /// Intenta abrir [uri] en un navegador externo; retorna `false` si falla.
  Future<bool> launchExternalUri(Uri uri);
}
