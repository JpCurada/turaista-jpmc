/// On-device storage for the verified [FarmProfile].
///
/// The profile never leaves the phone: implementations write local files only
/// (see lib/services/file_profile_store.dart). Real profiles never go into git.
library;

import 'profile.dart';

abstract interface class ProfileStore {
  /// The saved profile, or null when the host has not finished onboarding.
  ///
  /// Throws [FormatException] when a saved profile exists but cannot be read.
  Future<FarmProfile?> load();

  /// Saves a read-back-confirmed profile, replacing any earlier one.
  Future<void> save(FarmProfile profile);
}

/// Keeps the profile in memory. For tests and model-free demos.
class InMemoryProfileStore implements ProfileStore {
  InMemoryProfileStore([this._profile]);

  FarmProfile? _profile;

  @override
  Future<FarmProfile?> load() async => _profile;

  @override
  Future<void> save(FarmProfile profile) async => _profile = profile;
}
