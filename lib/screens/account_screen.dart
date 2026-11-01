import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/network.dart';
import '../profile/local_profile.dart';
import '../ui/app_palette.dart';
import '../ui/state_message.dart';
import 'consent_sheet.dart';
import '../ui/app_text_styles.dart';

/// Edit the display name and permanently delete the online account.
/// Only the display name is stored; there is no email, phone or real name.
class AccountScreen extends StatefulWidget {
  /// Injectable for tests.
  final ApiClient? api;
  final VoidCallback? onSignedOut;

  /// App bar title; the Profile tab calls this screen 'Profile'.
  final String title;
  const AccountScreen({
    super.key,
    this.api,
    this.onSignedOut,
    this.title = 'Account',
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final _name = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Progress? _progress;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _describe(Object e) => e is ApiException
      ? e.message
      : 'Could not reach the game server. Try again later.';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.authenticateGuest();
      await syncLocalProfile(_api); // the name and avatar chosen at first launch
      final profile = await _api.getProfile();
      _name.text = profile.nickname;
      _avatar = profile.avatar;
      try {
        _progress = await _api.getProgress();
      } catch (_) {} // XP is a nice-to-have; never block the screen
    } catch (e) {
      _error = _describe(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Puts everything we hold about the player on the clipboard as JSON.
  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await _api.exportMyData();
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
      );
      _toast('Copied. Paste it anywhere to keep a copy.');
    } catch (e) {
      _toast(_describe(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    final value = _name.text.trim();
    if (value.length < 2 || value.length > 20) {
      _toast('Display name must be 2 to 20 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.updateProfile(nickname: value, avatar: _avatar);
      if (mounted) _toast('Display name saved');
    } catch (e) {
      if (mounted) _toast(_describe(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your profile, friends, friend requests '
          'and blocked list. Rooms you host pass to another player. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_account'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.deleteAccount();
      await LocalProfileStore.current?.clear();
      (widget.onSignedOut ?? AuthService().signOut)();
      if (!mounted) return;
      _toast('Account deleted');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _toast(_describe(e));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.title,
        titleSpacing: 20,
      ),
      backgroundColor: AppPalette.backgroundTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? StateMessage(
                  key: const Key('account_error'),
                  icon: Icons.cloud_off_rounded,
                  title: 'Can\'t load your profile',
                  body: _error!,
                  actionLabel: 'Try again',
                  onAction: _load,
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _ProfileHeader(
                      name: _name.text.isEmpty ? 'You' : _name.text,
                      progress: _progress,
                      avatar: _avatar,
                    ),
                    const Text('Avatar', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in avatarPresets)
                          Semantics(
                            button: true,
                            selected: _avatar == a.id,
                            label: a.label,
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: Key('profile_avatar_${a.id}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _avatar = a.id),
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: a.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _avatar == a.id
                                        ? AppPalette.cream
                                        : AppPalette.ink,
                                    width: _avatar == a.id ? 3.5 : 2.5,
                                  ),
                                ),
                                child: Text(
                                  a.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Display name', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('account_name'),
                      controller: _name,
                      maxLength: 20,
                    ),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const Key('account_save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.confetti,
                          foregroundColor: AppPalette.ink,
                          textStyle: AppTextStyles.button,
                        ),
                        onPressed: _busy ? null : _save,
                        child: const Text('Save profile'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Only your display name is stored. There is no '
                      'email, phone number or real name.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 24),
                    const Text('Community rules', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 6),
                    for (final r in communityRules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $r', style: AppTextStyles.caption),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('account_export'),
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Copy my data'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('account_delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.danger,
                      ),
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete my account'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Who you are: a sticker avatar with your initial, your name and level, and
/// how far you are to the next level.
class _ProfileHeader extends StatelessWidget {
  final String name;
  final Progress? progress;
  final String? avatar;
  const _ProfileHeader({
    required this.name,
    required this.progress,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarPresetOf(avatar)?.color ?? AppPalette.candy,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppPalette.ink, width: 3),
                  boxShadow: const [BoxShadow(color: AppPalette.ink, offset: Offset(0, 4))],
                ),
                child: ExcludeSemantics(
                  child: avatarPresetOf(avatar) != null
                      ? Text(
                          avatarPresetOf(avatar)!.emoji,
                          style: const TextStyle(fontSize: 34),
                        )
                      : Text(
                          name.characters.first.toUpperCase(),
                          style: AppTextStyles.title.copyWith(fontSize: 32),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading.copyWith(fontSize: 22),
                    ),
                    if (p != null)
                      Text('Level ${p.level}', style: AppTextStyles.bodyBold.copyWith(color: AppPalette.confetti)),
                  ],
                ),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('account_progress'),
              height: 16,
              decoration: BoxDecoration(
                color: AppPalette.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.ink, width: 2.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: p.fraction.toDouble(),
                    heightFactor: 1,
                    child: const ColoredBox(color: AppPalette.mint),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${p.xp} of ${p.nextLevelXp} XP to level ${p.level + 1}  ·  ${p.wins} wins in ${p.played} online games',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
