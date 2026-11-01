import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/network.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'online_reactions.dart';
import 'round_game_widgets.dart';

/// Online Word Rush: unscramble the letters before anyone else does. The server
/// holds the word and checks every guess; wrong guesses are never shown.
class OnlineWordRushScreen extends StatefulWidget {
  final Room room;
  final String myUserId;

  /// Injectable for tests; defaults to the real connection.
  final GameSocket? socket;
  const OnlineWordRushScreen({
    super.key,
    required this.room,
    required this.myUserId,
    this.socket,
  });

  @override
  State<OnlineWordRushScreen> createState() => _OnlineWordRushScreenState();
}

class _OnlineWordRushScreenState extends State<OnlineWordRushScreen> {
  late final OnlineGameSession _session = OnlineGameSession(
    room: widget.room,
    myUserId: widget.myUserId,
    socket: widget.socket ?? SocketService(),
  );
  final _guess = TextEditingController();
  final _focus = FocusNode();
  int _lastRound = 0;

  @override
  void dispose() {
    _session.dispose();
    _guess.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _guess.text.trim();
    if (text.length < 2) return;
    _guess.clear();
    await _session.act({'guess': text});
    if (mounted) _focus.requestFocus();
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
                final round = (s.state['round'] as num).toInt();
                if (round != _lastRound) {
                  _lastRound = round;
                  _guess.clear(); // a new word: start fresh
                }
                final scramble = '${s.state['scramble']}';
                final guessesLeft =
                    ((s.state['guessesLeft'] as Map?)?[s.myUserId] as num?)
                        ?.toInt() ??
                    0;
                final last = s.state['last'] as Map?;
                return Column(
                  children: [
                    RoundGameHeader(session: s),
                    const SizedBox(height: 16),
                    if (last != null)
                      Text(
                        last['winnerId'] == null
                            ? 'Nobody got "${last['word']}"'
                            : '${last['winnerId'] == s.myUserId ? 'You' : s.nameOf(last['winnerId'] as String)} got "${last['word']}"',
                        key: const Key('wr_last'),
                        style: AppTextStyles.caption,
                      ),
                    Expanded(
                      child: Center(
                        child: s.isOver
                            ? ResultBanner(
                                session: s,
                                textKey: const Key('wr_result'),
                              )
                            : Wrap(
                                key: const Key('wr_letters'),
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (var i = 0; i < scramble.length; i++)
                                    // Each tile sits at a slightly different angle, like loose letter tiles.
                                    Transform.rotate(
                                      angle: (i.isEven ? -1 : 1) * (0.03 + 0.012 * (i % 3)),
                                      child: Container(
                                        width: 46,
                                        height: 58,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppPalette.cream,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppPalette.ink,
                                            width: 3,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: AppPalette.ink,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          scramble[i].toUpperCase(),
                                          style: AppTextStyles.title.copyWith(
                                            color: AppPalette.ink,
                                            fontSize: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    if (!s.isOver) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('wr_guess'),
                              controller: _guess,
                              focusNode: _focus,
                              enabled: guessesLeft > 0,
                              maxLength: 12,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              enableSuggestions: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp('[a-zA-Z]'),
                                ),
                              ],
                              style: AppTextStyles.heading.copyWith(fontSize: 22),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: AppPalette.panel,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppPalette.ink, width: 2.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppPalette.ink, width: 2.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppPalette.confetti, width: 3),
                                ),
                                hintText: guessesLeft > 0
                                    ? 'Type the word'
                                    : 'No guesses left this round',
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              key: const Key('wr_send'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.confetti,
                                foregroundColor: AppPalette.ink,
                                textStyle: AppTextStyles.button,
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                              ),
                              onPressed: guessesLeft > 0 && !s.busy
                                  ? _send
                                  : null,
                              child: const Text('Go'),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$guessesLeft guesses left',
                        key: const Key('wr_guesses_left'),
                        style: AppTextStyles.caption,
                      ),
                    ],
                    OnlineReactions(session: s),
                    if (s.error != null)
                      Text(
                        s.error!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppPalette.danger,
                        ),
                      ),
                    if (s.isOver && s.rematchLabel != null)
                      AppButton(
                        key: const Key('wr_rematch'),
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
