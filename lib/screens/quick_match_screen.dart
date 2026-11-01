import 'dart:async';

import 'package:flutter/material.dart';

import '../network/network.dart';
import '../network/online_bootstrap.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'online_game_router.dart';

/// Looks for another player who picked the same game, then opens the game.
/// Leaving this screen cancels the search on the server.
class QuickMatchScreen extends StatefulWidget {
  final OnlineGame game;

  /// Injectable for tests.
  final Future<UserProfile> Function()? connect;
  final MatchSocket? matcher;

  const QuickMatchScreen({
    super.key,
    required this.game,
    this.connect,
    this.matcher,
  });

  @override
  State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

enum _Phase { connecting, searching, failed }

class _QuickMatchScreenState extends State<QuickMatchScreen> {
  _Phase _phase = _Phase.connecting;
  String? _error;
  MatchSearch? _search;
  Timer? _ticker;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Back button, swipe or app close: stop waiting in the server's queue.
    _search?.cancel();
    super.dispose();
  }

  String _describe(Object e) => e is ApiException
      ? e.message
      : 'Could not reach the game server. Check your connection and try again.';

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
      _seconds = 0;
    });
    try {
      final me = await (widget.connect ?? connectOnline)();
      if (!mounted) return;
      final search = (widget.matcher ?? SocketService()).findMatch(
        widget.game.id,
      );
      _search = search;
      setState(() => _phase = _Phase.searching);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });

      final room = await search.room;
      _ticker?.cancel();
      _search = null; // matched: nothing left to cancel
      if (!mounted) return;
      final screen = onlineGameScreen(room, me.id);
      if (screen == null) {
        throw const ApiException(
          statusCode: 409,
          error: 'UnknownGame',
          message:
              'This version of the app cannot open that game. Please update.',
        );
      }
      Navigator.of(context).pushReplacement(appPageRoute(screen));
    } on MatchCancelled {
      // The player left; nothing to show.
    } catch (e) {
      _ticker?.cancel();
      _search = null;
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = _describe(e);
      });
    }
  }

  String get _elapsed =>
      '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBackButton(),
                const SizedBox(height: 22),
                Text('Quick match', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(widget.game.title, style: AppTextStyles.subheading),
                Expanded(child: Center(child: _body())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_phase == _Phase.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong.',
            key: const Key('qm_status'),
            textAlign: TextAlign.center,
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: 8),
          Text(
            'You can search again, or start a private room and share the code with a friend.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 22),
          AppButton(
            key: const Key('qm_retry'),
            text: 'Search again',
            width: 240,
            onPressed: _start,
          ),
        ],
      );
    }
    final searching = _phase == _Phase.searching;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            strokeWidth: 8,
            color: AppPalette.confetti,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          searching ? 'Looking for a player...' : 'Connecting...',
          key: const Key('qm_status'),
          style: AppTextStyles.heading,
        ),
        const SizedBox(height: 6),
        if (searching)
          Text(
            _elapsed,
            key: const Key('qm_elapsed'),
            style: AppTextStyles.subheading,
          ),
        const SizedBox(height: 26),
        AppButton(
          key: const Key('qm_cancel'),
          text: 'Cancel',
          variant: AppButtonVariant.secondary,
          width: 200,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
