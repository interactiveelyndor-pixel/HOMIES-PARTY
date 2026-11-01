import 'package:flutter/material.dart';

import '../connect4/connect4_board.dart';
import '../models/player_color.dart';
import '../network/network.dart';
import '../snl/snl_board_widget.dart';
import '../snl/snl_game_state.dart';
import '../snl/snl_player.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'online_reactions.dart';

const _onlineColors = [
  PlayerColor.red,
  PlayerColor.green,
  PlayerColor.yellow,
  PlayerColor.blue,
];

/// Converts the server's game state into the existing [SnlGameState] so the
/// existing board widget can render it. Names come from [room] players.
SnlGameState snlStateFromServer(Room room, Map<String, dynamic> server) {
  final raw = (server['players'] as List).cast<Map>();
  final winnerId = server['winnerId'] as String?;
  final players = <SnlPlayer>[
    for (var i = 0; i < raw.length; i++)
      SnlPlayer(
        color: _onlineColors[i % _onlineColors.length],
        name: room.getPlayer(raw[i]['userId'] as String)?.nickname ?? 'Player',
        position: raw[i]['position'] as int,
        hasWon: raw[i]['userId'] == winnerId,
      ),
  ];
  final turn = server['turn'] as int;
  final winner = winnerId == null ? null : players.firstWhere((p) => p.hasWon);
  return SnlGameState(
    players: players,
    currentPlayerIndex: turn,
    diceValue: server['lastRoll'] as int?,
    phase: winner != null ? SnlTurnPhase.gameWon : SnlTurnPhase.waitingForRoll,
    winner: winner,
    message: winner != null
        ? '${winner.name} wins!'
        : "${players[turn].name}'s turn",
  );
}

/// Online Snakes & Ladders. The server rolls the dice and owns all state;
/// this screen only asks for a roll and draws what the server sends.
/// State is shown as received (no step-by-step token animation yet).
class OnlineSnlScreen extends StatefulWidget {
  final Room room;
  final String myUserId;

  /// Injectable for tests; defaults to the real connection.
  final GameSocket? socket;
  const OnlineSnlScreen({
    super.key,
    required this.room,
    required this.myUserId,
    this.socket,
  });

  @override
  State<OnlineSnlScreen> createState() => _OnlineSnlScreenState();
}

class _OnlineSnlScreenState extends State<OnlineSnlScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) {
                final s = _session;
                final state = snlStateFromServer(s.room, s.state);
                final over = state.isGameOver;
                return Column(
                  children: [
                    Row(
                      children: [
                        const AppBackButton(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Room ${s.room.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConnectFourStatusPill(
                      key: const Key('online_snl_status'),
                      text: over
                          ? state.message
                          : (s.myTurn ? 'Your turn - roll!' : state.message),
                      color: AppPalette.seatColors[s.state['turn'] is int
                          ? (s.state['turn'] as int) % AppPalette.seatColors.length
                          : 0],
                      live: !over,
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: SnlBoardWidget(state: state)),
                    const SizedBox(height: 12),
                    if (state.diceValue != null)
                      Text(
                        'Last roll: ${state.diceValue}',
                        style: AppTextStyles.bodyBold,
                      ),
                    if (s.error != null)
                      Text(
                        s.error!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppPalette.danger,
                        ),
                      ),
                    OnlineReactions(session: s),
                    const SizedBox(height: 4),
                    AppButton(
                      key: const Key('online_snl_roll'),
                      text: over ? (s.rematchLabel ?? 'Party over') : 'Roll dice',
                      isLoading: s.busy,
                      onPressed: over
                          ? (s.rematchLabel == null ? null : s.rematch)
                          : (s.myTurn ? s.act : null),
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
