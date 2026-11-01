import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../ui/app_palette.dart';

/// A preset avatar. The [id] is what is stored and sent to the server.
class AvatarPreset {
  final String id;
  final String emoji;
  final String label;
  final Color color;
  const AvatarPreset(this.id, this.emoji, this.label, this.color);
}

const avatarPresets = [
  AvatarPreset('fox', '🦊', 'Fox', AppPalette.carrom),
  AvatarPreset('panda', '🐼', 'Panda', AppPalette.sky),
  AvatarPreset('frog', '🐸', 'Frog', AppPalette.mint),
  AvatarPreset('octopus', '🐙', 'Octopus', AppPalette.candy),
  AvatarPreset('lion', '🦁', 'Lion', AppPalette.confetti),
  AvatarPreset('unicorn', '🦄', 'Unicorn', AppPalette.candy),
  AvatarPreset('robot', '🤖', 'Robot', AppPalette.sky),
  AvatarPreset('rocket', '🚀', 'Rocket', AppPalette.mint),
];

/// The preset for a stored id, or null (older accounts have no avatar).
AvatarPreset? avatarPresetOf(String? id) {
  for (final a in avatarPresets) {
    if (a.id == id) return a;
  }
  return null;
}

/// What the player chose on first launch.
class LocalProfile {
  final bool onboarded;
  final String? nickname;
  final String? avatar;

  /// True once the server has the same nickname and avatar.
  final bool synced;
  const LocalProfile({
    this.onboarded = false,
    this.nickname,
    this.avatar,
    this.synced = false,
  });
}

/// Keeps [LocalProfile] on the device. The app works offline, so the choice is
/// saved here first and sent to the server the next time it is reachable.
class LocalProfileStore {
  final SharedPreferences _prefs;
  LocalProfileStore(this._prefs);

  /// Set by the app at start-up; null in tests that do not care.
  static LocalProfileStore? current;

  static Future<LocalProfileStore> open() async =>
      LocalProfileStore(await SharedPreferences.getInstance());

  static const _kDone = 'onboarded';
  static const _kName = 'nickname';
  static const _kAvatar = 'avatar';
  static const _kSynced = 'profile_synced';

  LocalProfile get profile => LocalProfile(
    onboarded: _prefs.getBool(_kDone) ?? false,
    nickname: _prefs.getString(_kName),
    avatar: _prefs.getString(_kAvatar),
    synced: _prefs.getBool(_kSynced) ?? false,
  );

  Future<void> saveProfile({required String nickname, required String avatar}) async {
    await _prefs.setString(_kName, nickname);
    await _prefs.setString(_kAvatar, avatar);
    await _prefs.setBool(_kSynced, false);
    await _prefs.setBool(_kDone, true);
  }

  /// Onboarding finished without a profile (skipped); nothing to send.
  Future<void> markOnboarded() => _prefs.setBool(_kDone, true);

  Future<void> markSynced() => _prefs.setBool(_kSynced, true);

  /// Forget everything (account deleted): the next launch starts onboarding again.
  Future<void> clear() async {
    for (final k in [_kDone, _kName, _kAvatar, _kSynced]) {
      await _prefs.remove(k);
    }
  }
}

/// Sends the locally chosen name and avatar to the server once. Safe to call
/// often: it does nothing when there is nothing to send, and a failure just
/// means it tries again next time. Returns true when it sent something.
Future<bool> syncLocalProfile(ApiClient api) async {
  final store = LocalProfileStore.current;
  final p = store?.profile;
  if (store == null || p == null || p.synced || p.nickname == null) return false;
  try {
    await api.updateProfile(nickname: p.nickname, avatar: p.avatar);
    await store.markSynced();
    return true;
  } catch (_) {
    // Offline or the server said no; keep the local copy and retry later.
    return false;
  }
}
