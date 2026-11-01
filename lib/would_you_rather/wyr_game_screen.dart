import 'package:flutter/material.dart';

import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'wyr_logic.dart';

const _optionColors = [
  [Color(0xFFFF5C8A), Color(0xFFFF8FB0)], // A
  [Color(0xFF3DB8FF), Color(0xFF8BD5FF)], // B
];

/// Pass-and-play Would You Rather. The question stays hidden until the next
/// player says it is them, so votes stay secret.
class WyrGameScreen extends StatefulWidget {
  final int playerCount;

  /// Injectable for tests.
  final WyrGame? game;
  const WyrGameScreen({super.key, required this.playerCount, this.game});

  @override
  State<WyrGameScreen> createState() => _WyrGameScreenState();
}

class _WyrGameScreenState extends State<WyrGameScreen> {
  late WyrGame _game = widget.game ?? WyrGame.random(widget.playerCount);
  bool _ready = false; // current voter has taken the phone

  void _vote(int choice) {
    setState(() {
      _game.vote(choice);
      _ready = false;
    });
  }

  void _next() => setState(_game.next);

  void _playAgain() => setState(() {
    _game = WyrGame.random(widget.playerCount);
    _ready = false;
  });

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_game.phase) {
      case WyrPhase.voting:
        body = _ready ? _question() : _pass();
      case WyrPhase.reveal:
        body = _reveal();
      case WyrPhase.finished:
        body = _scores();
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _game.phase == WyrPhase.finished
                            ? 'Final scores'
                            : 'Question ${_game.round + 1} of ${_game.totalRounds}',
                        style: AppTextStyles.heading,
                        key: const Key('wyr_title'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- voting -------------------------------------------------------------

  Widget _pass() {
    final name = _game.players[_game.voter];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🫴', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('Pass the phone to', style: AppTextStyles.subheading),
          const SizedBox(height: 4),
          Text(
            name,
            key: const Key('wyr_voter'),
            style: AppTextStyles.title.copyWith(fontSize: 40),
          ),
          const SizedBox(height: 6),
          Text('Everyone else, look away.', style: AppTextStyles.caption),
          const SizedBox(height: 26),
          AppButton(
            key: const Key('wyr_ready'),
            text: "I'm $name",
            width: 240,
            onPressed: () => setState(() => _ready = true),
          ),
        ],
      ),
    );
  }

  Widget _question() {
    final p = _game.prompt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_game.players[_game.voter]}, would you rather...',
          style: AppTextStyles.title.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 18),
        Expanded(child: _option(0, p.a, const Key('wyr_option_a'))),
        const SizedBox(height: 12),
        Center(child: Text('or', style: AppTextStyles.heading)),
        const SizedBox(height: 12),
        Expanded(child: _option(1, p.b, const Key('wyr_option_b'))),
      ],
    );
  }

  Widget _option(int index, String text, Key key) => Semantics(
    button: true,
    label: 'Option ${index == 0 ? 'A' : 'B'}: $text',
    excludeSemantics: true,
    child: AppCard(
      key: key,
      onTap: () => _vote(index),
      gradientColors: _optionColors[index],
      padding: const EdgeInsets.all(20),
      child: SizedBox.expand(
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              color: AppPalette.ink,
              fontSize: 25,
            ),
          ),
        ),
      ),
    ),
  );

  // --- reveal -------------------------------------------------------------

  Widget _reveal() {
    final p = _game.prompt;
    final (a, b) = _game.counts;
    final m = _game.majority;
    final last = _game.round + 1 >= _game.totalRounds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scrolls on small screens / large text; the button stays pinned.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m == -1 ? 'A tie! Nobody scores.' : 'The room says...',
                  key: const Key('wyr_result'),
                  style: AppTextStyles.title.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 16),
                _resultRow(0, p.a, a, m == 0),
                const SizedBox(height: 14),
                _resultRow(1, p.b, b, m == 1),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        AppButton(
          key: const Key('wyr_next'),
          text: last ? 'See final scores' : 'Next question',
          width: double.infinity,
          onPressed: _next,
        ),
      ],
    );
  }

  Widget _resultRow(int index, String text, int count, bool winner) {
    final who = [
      for (var i = 0; i < _game.players.length; i++)
        if (_game.votes[i] == index) _game.players[i],
    ];
    return AppCard(
      gradientColors: winner
          ? _optionColors[index]
          : const [AppPalette.panel, AppPalette.panel],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.heading.copyWith(
                    color: winner ? AppPalette.ink : AppPalette.cream,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count',
                key: Key('wyr_count_$index'),
                style: AppTextStyles.title.copyWith(
                  color: winner ? AppPalette.ink : AppPalette.cream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            who.isEmpty ? 'Nobody' : who.join(', '),
            style: AppTextStyles.bodyBold.copyWith(
              color: winner ? AppPalette.ink : AppPalette.textSecondary,
            ),
          ),
          if (winner) ...[
            const SizedBox(height: 6),
            Text(
              'Most picked: +1 point',
              style: AppTextStyles.caption.copyWith(color: AppPalette.ink),
            ),
          ],
        ],
      ),
    );
  }

  // --- final scores -------------------------------------------------------

  Widget _scores() {
    final order = List.generate(_game.players.length, (i) => i)
      ..sort((x, y) => _game.scores[y].compareTo(_game.scores[x]));
    final winners = _game.winners;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          winners.length == 1
              ? '${winners.first} wins!'
              : "It's a tie: ${winners.join(' and ')}",
          key: const Key('wyr_winner'),
          style: AppTextStyles.title.copyWith(
            color: AppPalette.confetti,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final i in order)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _game.players[i],
                            style: AppTextStyles.heading,
                          ),
                        ),
                        Text(
                          '${_game.scores[i]}',
                          style: AppTextStyles.title.copyWith(
                            color: AppPalette.confetti,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppButton(
          key: const Key('wyr_play_again'),
          text: 'Play again',
          width: double.infinity,
          onPressed: _playAgain,
        ),
      ],
    );
  }
}
