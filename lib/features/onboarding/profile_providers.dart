import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';

/// The reader's name, kept only on this phone (no account, nothing online).
@immutable
class UserProfile {
  const UserProfile({this.name = '', this.onboarded = false});

  final String name;

  /// True once the welcome screen has been completed.
  final bool onboarded;
}

class UserProfileNotifier extends Notifier<UserProfile> {
  static const _kName = 'profile.name';
  static const _kOnboarded = 'profile.onboarded';

  @override
  UserProfile build() {
    final p = ref.watch(sharedPreferencesProvider);
    return UserProfile(name: p.getString(_kName) ?? '', onboarded: p.getBool(_kOnboarded) ?? false);
  }

  Future<void> completeOnboarding(String name) async {
    final clean = name.trim();
    state = UserProfile(name: clean, onboarded: true);
    final p = ref.read(sharedPreferencesProvider);
    await p.setString(_kName, clean);
    await p.setBool(_kOnboarded, true);
  }

  Future<void> setName(String name) async {
    final clean = name.trim();
    state = UserProfile(name: clean, onboarded: state.onboarded);
    await ref.read(sharedPreferencesProvider).setString(_kName, clean);
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);
