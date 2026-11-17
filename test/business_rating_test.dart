import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';

void main() {
  group('isValidBusinessStarRating', () {
    test('accepts integer stars from 1 to 5 and rejects null or out-of-range values', () {
      for (final valid in [1, 2, 3, 4, 5]) {
        expect(isValidBusinessStarRating(valid), isTrue);
      }
      for (final invalid in [null, -1, 0, 6, 10]) {
        expect(isValidBusinessStarRating(invalid), isFalse);
      }
    });
  });

  group('evaluateBusinessRatingEligibility', () {
    test('requires real authenticated session and blocks owner self-rating', () {
      expect(
        evaluateBusinessRatingEligibility(
          currentUserId: null,
          usesDemoData: false,
          businessOwnerId: 'owner-1',
        ),
        BusinessRatingEligibility.requiresAuth,
      );

      expect(
        evaluateBusinessRatingEligibility(
          currentUserId: 'demo-user',
          usesDemoData: true,
          businessOwnerId: 'owner-1',
        ),
        BusinessRatingEligibility.requiresAuth,
      );

      expect(
        evaluateBusinessRatingEligibility(
          currentUserId: 'owner-1',
          usesDemoData: false,
          businessOwnerId: 'owner-1',
        ),
        BusinessRatingEligibility.ownerForbidden,
      );

      expect(
        evaluateBusinessRatingEligibility(
          currentUserId: 'owner-1',
          usesDemoData: false,
          businessOwnerId: null,
          isOwnerFlag: true,
        ),
        BusinessRatingEligibility.ownerForbidden,
      );

      expect(
        evaluateBusinessRatingEligibility(
          currentUserId: 'voter-2',
          usesDemoData: false,
          businessOwnerId: 'owner-1',
        ),
        BusinessRatingEligibility.allowed,
      );
    });
  });
}
