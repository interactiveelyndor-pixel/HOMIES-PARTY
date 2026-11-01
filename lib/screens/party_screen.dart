import 'dart:async';

import 'package:flutter/material.dart';

import '../network/network.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'online_game_router.dart';

/// Party Mode: a score bar above whichever game the server picked for this
/// round. The server decides the games and the score; this only shows them and
/// swaps the game screen when a new round starts.
class PartyScreen extends StatefulWidget {
  final Room room;
  final String myUserId;

  /// Injectable for tests. Default: the live socket.
  final Stream<Room>? roomUpdates;
  final Stream<Room>? roomStarts;

  const PartyScreen({
    super.key,
    required this.room,
    required this.myUserId,
    this.roomUpdates,
    this.roomStarts,
  });

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  /// Latest room (scores). [_gameRoom] only changes when a new round starts, so
  /// a score update does not rebuild the running game.
  late Room _room = widget.room;
  late Room _gameRoom = widget.room;
  final _subs = <StreamSubscription<Room>>[];

  @override
  void initState() {
    super.initState();
    final socket = SocketService();
    _subs.add(
      (widget.roomUpdates ?? socket.onRoomUpdated).listen((r) {
        if (!mounted || r.code != _room.code) return;
        setState(() => _room = r);
      }),
    );
    _subs.add(
      (widget.roomStarts ?? socket.onRoomStarted).listen((r) {
        if (!mounted || r.code != _room.code) return;
        setState(() => _room = _gameRoom = r);
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  int get _round => (_gameRoom.party?['round'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final game = onlineRoundScreen(_gameRoom, widget.myUserId);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: Column(
          children: [
            SafeArea(bottom: false, child: PartyBar(room: _room)),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: KeyedSubtree(
                  key: ValueKey('${_gameRoom.gameType}-$_round'),
                  child:
                      game ??
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'This version of the app cannot open this round. Please update.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round counter and scores, highest first. Shows the winner once the party ends.
class PartyBar extends StatelessWidget {
  final Room room;
  const PartyBar({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final party = room.party ?? const <String, dynamic>{};
    final rounds = (party['rounds'] as num?)?.toInt() ?? 0;
    final round = (party['round'] as num?)?.toInt() ?? 0;
    final finished = party['finished'] == true;
    final scores = <String, int>{
      for (final e in ((party['scores'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    };
    // Everyone in the room shows, even with no points yet.
    for (final p in room.players) {
      scores.putIfAbsent(p.userId, () => 0);
    }
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.isEmpty ? 0 : ranked.first.value;
    final winners = ranked.where((e) => e.value == top).toList();
    String name(String id) => room.getPlayer(id)?.nickname ?? 'Player';

    return Container(
      key: const Key('party_bar'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: AppPalette.backgroundElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            finished
                ? (winners.length == 1
                      ? '🏆 ${name(winners.first.key)} wins the party!'
                      : '🏆 It is a tie: ${winners.map((w) => name(w.key)).join(' & ')}')
                : '🎉 Party · Round $round of $rounds',
            key: const Key('party_title'),
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in ranked)
                Chip(
                  key: Key('party_score_${e.key}'),
                  visualDensity: VisualDensity.compact,
                  label: Text('${name(e.key)}  ${e.value}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
