import 'package:flutter/material.dart';

import '../network/network.dart';
import '../ui/app_palette.dart';
import '../ui/state_message.dart';
import '../ui/app_text_styles.dart';
import 'account_screen.dart';

/// Friends, friend requests, recent players and blocked players.
/// All data comes from the backend; when it is unreachable the screen says so
/// and offers a retry (nothing is simulated).
class SocialScreen extends StatefulWidget {
  /// Injectable for tests.
  final ApiClient? api;
  const SocialScreen({super.key, this.api});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  bool _loading = true;
  String? _error;
  List<SocialPlayer> _friends = [];
  List<SocialPlayer> _recent = [];
  List<SocialPlayer> _blocked = [];
  FriendRequests _requests = const FriendRequests();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _describe(Object e) => e is ApiException
      ? e.message
      : 'Could not reach the game server. Check your connection and the '
            'server address, then try again.';

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      await _api.authenticateGuest();
      final results = await Future.wait([
        _api.getFriends(),
        _api.getFriendRequests(),
        _api.getRecentPlayers(),
        _api.getBlocked(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<SocialPlayer>;
        _requests = results[1] as FriendRequests;
        _recent = results[2] as List<SocialPlayer>;
        _blocked = results[3] as List<SocialPlayer>;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _describe(e);
        _loading = false;
      });
    }
  }

  /// Runs a mutation, reports the outcome, then refreshes the lists.
  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _toast(done);
    } catch (e) {
      if (mounted) _toast(_describe(e));
    }
    await _load(quiet: true);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addFriend(SocialPlayer p) async {
    String? status;
    await _act(
      () async => status = await _api.sendFriendRequest(p.userId),
      'Request sent',
    );
    if (status == 'friends' && mounted) _toast('You are now friends');
  }

  Future<void> _block(SocialPlayer p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${p.nickname}?'),
        content: const Text(
          'They will not be able to join your rooms or send you friend '
          'requests, and any friendship will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_block'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _act(() => _api.blockUser(p.userId), '${p.nickname} blocked');
    }
  }

  Future<void> _report(SocialPlayer p) async {
    final result = await showDialog<({String reason, String details})>(
      context: context,
      builder: (_) => _ReportDialog(nickname: p.nickname),
    );
    if (result != null) {
      await _act(
        () => _api.reportUser(p.userId, result.reason, details: result.details),
        'Report sent. Thank you.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
      child: SafeArea(
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('Friends', style: AppTextStyles.title)),
                    IconButton(
                      key: const Key('open_account'),
                      tooltip: 'Account',
                      icon: const Icon(Icons.manage_accounts),
                      onPressed: () async {
                        final deleted = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => AccountScreen(api: widget.api),
                          ),
                        );
                        if (deleted == true) _load();
                      },
                    ),
                  ],
                ),
              ),
              TabBar(
                labelPadding: EdgeInsets.zero,
                labelColor: AppPalette.cream,
                unselectedLabelColor: AppPalette.textMuted,
                indicatorColor: AppPalette.confetti,
                indicatorWeight: 3,
                dividerColor: AppPalette.glassBorder,
                tabs: [
                  const Tab(text: 'Friends'),
                  Tab(
                    text: _requests.incoming.isEmpty
                        ? 'Requests'
                        : 'Requests (${_requests.incoming.length})',
                  ),
                  const Tab(text: 'Recent'),
                  const Tab(text: 'Blocked'),
                ],
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return StateMessage(
        key: const Key('social_error'),
        icon: Icons.cloud_off_rounded,
        title: 'Can\'t load your friends',
        body: _error!,
        actionLabel: 'Try again',
        actionKey: const Key('social_retry'),
        onAction: _load,
      );
    }
    return TabBarView(
      children: [
        _list(
          _friends,
          Icons.people_outline_rounded,
          'No friends yet. Add players you meet in the Recent tab.',
          (p) => _menu(p, remove: true),
        ),
        _requestsTab(),
        _list(
          _recent,
          Icons.history_rounded,
          'Play an online game to see the players you met here.',
          (p) => switch (p.relation) {
            'friend' => const Chip(label: Text('Friend')),
            'pending_out' => const Text('Request sent'),
            _ => _menu(p, add: true),
          },
        ),
        _list(
          _blocked,
          Icons.shield_outlined,
          'You have not blocked anyone.',
          (p) => TextButton(
            onPressed: () => _act(
              () => _api.unblockUser(p.userId),
              '${p.nickname} unblocked',
            ),
            child: const Text('Unblock'),
          ),
        ),
      ],
    );
  }

  Widget _requestsTab() {
    final empty = _requests.incoming.isEmpty && _requests.outgoing.isEmpty;
    if (empty) {
      return _scrollable(
        const EmptyHint(
          icon: Icons.mail_outline_rounded,
          text: 'No pending friend requests.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final p in _requests.incoming)
            _tile(
              p,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('accept_${p.userId}'),
                    tooltip: 'Accept',
                    icon: const Icon(
                      Icons.check_circle,
                      color: AppPalette.success,
                    ),
                    onPressed: () => _act(
                      () => _api.acceptFriendRequest(p.requestId!),
                      'You are now friends with ${p.nickname}',
                    ),
                  ),
                  IconButton(
                    key: Key('decline_${p.userId}'),
                    tooltip: 'Decline',
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () => _act(
                      () => _api.removeFriendRequest(p.requestId!),
                      'Request declined',
                    ),
                  ),
                ],
              ),
            ),
          for (final p in _requests.outgoing)
            _tile(
              p,
              TextButton(
                onPressed: () => _act(
                  () => _api.removeFriendRequest(p.requestId!),
                  'Request cancelled',
                ),
                child: const Text('Cancel'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scrollable(Widget child) => RefreshIndicator(
    onRefresh: () => _load(quiet: true),
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [Center(child: child)],
    ),
  );

  Widget _list(
    List<SocialPlayer> players,
    IconData icon,
    String empty,
    Widget Function(SocialPlayer) trailing,
  ) {
    if (players.isEmpty) {
      return _scrollable(EmptyHint(icon: icon, text: empty));
    }
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [for (final p in players) _tile(p, trailing(p))],
      ),
    );
  }

  Widget _tile(SocialPlayer p, Widget trailing) => Card(
    key: Key('player_${p.userId}'),
    color: AppPalette.glassSurface,
    child: ListTile(
      leading: CircleAvatar(
        child: Text(p.nickname.isEmpty ? '?' : p.nickname[0].toUpperCase()),
      ),
      title: Text(p.nickname, style: AppTextStyles.bodyBold),
      trailing: trailing,
    ),
  );

  Widget _menu(SocialPlayer p, {bool add = false, bool remove = false}) =>
      PopupMenuButton<String>(
        key: Key('menu_${p.userId}'),
        onSelected: (v) {
          switch (v) {
            case 'add':
              _addFriend(p);
            case 'remove':
              _act(
                () => _api.removeFriend(p.userId),
                '${p.nickname} removed from friends',
              );
            case 'report':
              _report(p);
            case 'block':
              _block(p);
          }
        },
        itemBuilder: (_) => [
          if (add) const PopupMenuItem(value: 'add', child: Text('Add friend')),
          if (remove)
            const PopupMenuItem(value: 'remove', child: Text('Remove friend')),
          const PopupMenuItem(value: 'report', child: Text('Report')),
          const PopupMenuItem(value: 'block', child: Text('Block')),
        ],
      );
}

/// Owns its own text controller so it is disposed with the dialog's route.
class _ReportDialog extends StatefulWidget {
  final String nickname;
  const _ReportDialog({required this.nickname});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = reportReasons.keys.first;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report ${widget.nickname}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: [
                  for (final e in reportReasons.entries)
                    RadioListTile<String>(
                      value: e.key,
                      title: Text(e.value),
                      dense: true,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Details (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm_report'),
          onPressed: () =>
              Navigator.pop(context, (reason: _reason, details: _details.text)),
          child: const Text('Send report'),
        ),
      ],
    );
  }
}
