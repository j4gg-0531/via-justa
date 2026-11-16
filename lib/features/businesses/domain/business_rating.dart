/// Estado de elegibilidad de un usuario para valorar un comercio con estrellas.
enum BusinessRatingEligibility {
  /// Usuario autenticado distinto al dueño: puede votar (1..5) y modificar su voto.
  allowed,

  /// Sin sesión real de Supabase: requiere iniciar sesión para valorar.
  requiresAuth,

  /// El usuario autenticado es el dueño del comercio: no puede autovalorarse.
  ownerForbidden,
}

/// Resultado devuelto al registrar o actualizar la valoración de un negocio.
class BusinessRatingSummary {
  const BusinessRatingSummary({
    required this.businessId,
    required this.myRating,
    required this.ratingAverage,
    required this.ratingCount,
  });

  final String businessId;
  final int myRating;
  final double? ratingAverage;
  final int ratingCount;
}

/// Valida que la puntuación seleccionada sea un entero entre 1 y 5 estrellas.
bool isValidBusinessStarRating(int? stars) {
  return stars != null && stars >= 1 && stars <= 5;
}

/// Determina si la cuenta actual puede valorar el comercio o el motivo por el que no puede.
BusinessRatingEligibility evaluateBusinessRatingEligibility({
  required String? currentUserId,
  required bool usesDemoData,
  required String? businessOwnerId,
  bool isOwnerFlag = false,
}) {
  final cleanUser = currentUserId?.trim() ?? '';
  if (usesDemoData || cleanUser.isEmpty) {
    return BusinessRatingEligibility.requiresAuth;
  }
  final cleanOwner = businessOwnerId?.trim() ?? '';
  if (isOwnerFlag || (cleanOwner.isNotEmpty && cleanOwner == cleanUser)) {
    return BusinessRatingEligibility.ownerForbidden;
  }
  return BusinessRatingEligibility.allowed;
}
