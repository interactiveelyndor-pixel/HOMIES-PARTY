import 'package:flutter/material.dart';

import '../connect4/connect4_board.dart';
import '../connect4/connect4_logic.dart';
import '../network/network.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'online_reactions.dart';

/// Builds a drawable [ConnectFourGame] from the server's state.
/// Player 1 (pink) is the first entry in the server's player list.
ConnectFourGame connectFourFromServer(Map<String, dynamic> s) {
  final players = (s['players'] as List).cast<Map>();
  final winnerId = s['winnerId'] as String?;
  final winnerIdx = winnerId == null
      ? -1
      : players.indexWhere((p) => p['userId'] == winnerId);
  final last = s['lastMove'] as Map?;
  return ConnectFourGame.snapshot(
    board: [
      for (final row in (s['board'] as List))
        [for (final v in (row as List)) v as int],
    ],
    current: (s['turn'] as int) + 1,
    winner: winnerIdx + 1,
    winningCells: [
      for (final c in ((s['winningCells'] as List?) ?? const []).cast<Map>())
        (c['row'] as int, c['col'] as int),
    ],
    lastMove: last == null ? null : (last['row'] as int, last['col'] as int),
  );
}

/// Online Connect Four. The server validates every move; this screen only
/// sends a column and draws the board the server sends back.
class OnlineConnectFourScreen extends StatefulWidget {
  final Room room;
  final String myUserId;

  /// Injectable for tests; defaults to the real connection.
  final GameSocket? socket;
  const OnlineConnectFourScreen({
    super.key,
    required this.room,
    required this.myUserId,
    this.socket,
  });

  @override
  State<OnlineConnectFourScreen> createState() =>
      _OnlineConnectFourScreenState();
}

class _OnlineConnectFourScreenState extends State<OnlineConnectFourScreen> {
  late final OnlineGameSession _session = OnlineGameSession(
    room: widget.room,
    myUserId: widget.myUserId,
    socket: widget.socket ?? SocketService(),
  );

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  String _status(OnlineGameSession s) {
    if (s.winnerId != null) {
      return s.winnerId == s.myUserId
          ? 'You win!'
          : '${s.nameOf(s.winnerId)} wins!';
    }
    if (s.isDraw) return "It's a draw";
    return s.myTurn ? 'Your turn' : "${s.nameOf(s.currentUserId)}'s turn";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) {
                final s = _session;
                final game = connectFourFromServer(s.state);
                final mine = s.indexOf(s.myUserId); // 0 = pink, 1 = yellow
                final shown = s.isOver
                    ? (s.winnerId == null ? game.current : game.winner)
                    : game.current;
                return Column(
                  children: [
                    Row(
                      children: [
                        const AppBackButton(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Room ${s.room.code}',
                            style: AppTextStyles.heading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ConnectFourStatusPill(
                      key: const Key('c4_status'),
                      text: _status(s),
                      color: shown == 1 ? c4Player1 : c4Player2,
                      live: !s.isOver,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mine == 0 ? 'You are pink' : 'You are yellow',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio:
                              ConnectFourGame.cols / ConnectFourGame.rows,
                          child: ConnectFourBoard(
                            game: game,
                            moves: s.version,
                            onColumn: (c) => s.act({'column': c}),
                          ),
                        ),
                      ),
                    ),
                    OnlineReactions(session: s),
                    const SizedBox(height: 8),
                    if (s.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          s.error!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppPalette.danger,
                          ),
                        ),
                      ),
                    if (s.isOver && s.rematchLabel != null)
                      AppButton(
                        key: const Key('c4_rematch'),
                        text: s.rematchLabel!,
                        width: double.infinity,
                        onPressed: s.rematch,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
