/// Documentos legales cuyo consentimiento queda registrado en `public.consents`
/// (Ley 1581 de 2012 — Habeas Data).
enum ConsentDocType {
  termsAndConditions('terms_and_conditions'),
  privacyPolicy('privacy_policy');

  const ConsentDocType(this.wireValue);

  /// Valor exacto permitido por el CHECK de la migración 0002.
  final String wireValue;
}

/// Versión vigente de los documentos legales aceptados al crear la cuenta.
///
/// Debe mantenerse sincronizada con `docs/seguridad-privacidad.md`: si cambia el
/// texto legal, sube la versión y los nuevos registros quedarán diferenciados.
const String consentDocumentVersion = 'v1.0';
