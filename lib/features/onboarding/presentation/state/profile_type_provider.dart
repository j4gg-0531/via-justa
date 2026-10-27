import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

class ProfileTypeNotifier extends Notifier<ProfileType?> {
  @override
  ProfileType? build() => null;

  void select(ProfileType type) {
    state = type;
  }

  void clear() {
    state = null;
  }
}

final profileTypeProvider = NotifierProvider<ProfileTypeNotifier, ProfileType?>(
  ProfileTypeNotifier.new,
);
