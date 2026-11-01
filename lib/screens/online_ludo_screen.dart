import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../models/token.dart';
import '../network/network.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../widgets/dice_widget.dart';
import '../widgets/ludo_board_widget.dart';
import 'online_reactions.dart';

String _again(String who) => who == 'You' ? 'Roll again!' : 'They roll again.';

/// One line about what the last action did, in plain words.
String ludoEventText(String event, int? roll, String who) {
  switch (event) {
    case 'capture':
      return '$who captured a token. ${_again(who)}';
    case 'home':
      return '$who got a token home. ${_again(who)}';
    case 'six':
      return '$who rolled a 6. ${_again(who)}';
    case 'noMove':
      return roll == null ? 'No move possible.' : '$who rolled $roll. No move possible.';
    case 'forfeit':
      return '$who rolled three 6s in a row and lose${who == 'You' ? '' : 's'} the turn.';
    default:
      return roll == null ? '' : '$who rolled $roll.';
  }
}

/// Builds the existing [GameState] so the offline board widget can draw the
/// server's game. [myId] limits the "movable" glow to the viewer's own turn.
GameState ludoStateFromServer(Room room, Map<String, dynamic> s, String myId) {
  final raw = (s['players'] as List).cast<Map>();
  final winnerId = s['winnerId'] as String?;
  final turn = s['turn'] as int;
  final inMovePhase = s['phase'] == 'move';

  final players = <Player>[
    for (final p in raw)
      Player(
        color: PlayerColor.values[p['color'] as int],
        name: room.getPlayer(p['userId'] as String)?.nickname ?? 'Player',
        hasWon: p['userId'] == winnerId,
        tokens: [
          for (var i = 0; i < 4; i++)
            Token(
              id: i,
              color: PlayerColor.values[p['color'] as int],
              stepCount: (p['tokens'] as List)[i] as int,
              baseSlotIndex: i,
            ),
        ],
      ),
  ];
  final winner = winnerId == null ? null : players.firstWhere((p) => p.hasWon);
  final myTurn = winnerId == null && raw[turn]['userId'] == myId;

  return GameState(
    players: players,
    currentPlayerIndex: turn,
    diceValue: (inMovePhase ? s['dice'] : s['lastRoll']) as int?,
    phase: winner != null
        ? TurnPhase.gameWon
        : (inMovePhase ? TurnPhase.waitingForTokenSelection : TurnPhase.waitingForRoll),
    movableTokenIds: myTurn && inMovePhase
        ? {for (final id in (s['movable'] as List)) id as int}
        : const {},
    winner: winner,
    message: '',
  );
}

/// Online Ludo for 2 to 4 players. The server rolls the dice and checks every
/// move; this screen draws its state and sends "roll" or "move this token".
class OnlineLudoScreen extends StatefulWidget {
  final Room room;
  final String myUserId;

  /// Injectable for tests; defaults to the real connection.
  final GameSocket? socket;
  const OnlineLudoScreen(
      {super.key, required this.room, required this.myUserId, this.socket});

  @override
  State<OnlineLudoScreen> createState() => _OnlineLudoScreenState();
}

class _OnlineLudoScreenState extends State<OnlineLudoScreen> {
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

  String _status(OnlineGameSession s, GameState g) {
    if (s.winnerId != null) {
      return s.winnerId == s.myUserId ? 'You win!' : '${s.nameOf(s.winnerId)} wins!';
    }
    if (s.myTurn) {
      return s.state['phase'] == 'move' ? 'Pick a token to move' : 'Your turn: roll!';
    }
    return "${s.nameOf(s.currentUserId)}'s turn";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) {
                final s = _session;
                final g = ludoStateFromServer(s.room, s.state, s.myUserId);
                final mine = s.indexOf(s.myUserId);
                final myColor = mine < 0 ? null : g.players[mine].color;
                final rolling = s.busy && s.state['phase'] != 'move';
                final canRoll = s.myTurn && s.state['phase'] == 'roll' && !s.busy;
                // The note belongs to whoever just played, not to the current turn.
                final actor = s.players[(s.state['lastActor'] as int?) ?? 0]['userId'];
                final note = s.state['lastRoll'] == null
                    ? ''
                    : ludoEventText(
                        s.state['lastEvent'] as String? ?? 'none',
                        s.state['lastRoll'] as int?,
                        actor == s.myUserId ? 'You' : s.nameOf(actor as String?),
                      );
                return Column(
                  children: [
                    Row(children: [
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
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      _status(s, g),
                      key: const Key('online_ludo_status'),
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      myColor == null ? '' : 'You are ${myColor.displayName.toLowerCase()}',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LudoBoardWidget(
                        state: g,
                        onTokenTap: (t) {
                          if (s.myTurn &&
                              s.state['phase'] == 'move' &&
                              t.color == myColor &&
                              g.movableTokenIds.contains(t.id)) {
                            s.act({'token': t.id});
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 20,
                      child: Text(note,
                          key: const Key('online_ludo_note'),
                          style: AppTextStyles.caption),
                    ),
                    if (s.error != null)
                      Text(s.error!,
                          style: AppTextStyles.caption.copyWith(color: AppPalette.danger)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DiceWidget(
                          key: const Key('online_ludo_dice'),
                          value: g.diceValue,
                          isRolling: rolling,
                          canRoll: canRoll,
                          playerColor: g.currentPlayer.color,
                          size: 56,
                          onRoll: canRoll ? s.act : () {},
                        ),
                      ],
                    ),
                    OnlineReactions(session: s),
                    if (s.isOver && s.rematchLabel != null)
                      AppButton(
                        key: const Key('online_ludo_rematch'),
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
