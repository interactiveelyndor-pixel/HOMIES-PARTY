import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'connect4_board.dart';
import 'connect4_logic.dart';

/// Connect Four on one phone, or against the computer (computer plays yellow).
class ConnectFourGameScreen extends StatefulWidget {
  final bool vsComputer;

  /// Injectable for tests; a zero delay makes the computer answer instantly.
  final Duration computerDelay;
  final ConnectFourAi? ai;

  const ConnectFourGameScreen({
    super.key,
    this.vsComputer = false,
    this.computerDelay = const Duration(milliseconds: 700),
    this.ai,
  });

  @override
  State<ConnectFourGameScreen> createState() => _ConnectFourGameScreenState();
}

class _ConnectFourGameScreenState extends State<ConnectFourGameScreen> {
  late ConnectFourGame _game;
  late final ConnectFourAi _ai = widget.ai ?? ConnectFourAi();
  Timer? _cpuTimer;
  int _moves = 0; // keys the drop animation so only the newest disc falls

  @override
  void initState() {
    super.initState();
    _game = ConnectFourGame();
  }

  @override
  void dispose() {
    _cpuTimer?.cancel();
    super.dispose();
  }

  bool get _cpuTurn => widget.vsComputer && _game.current == 2 && !_game.isOver;

  String _name(int player) => widget.vsComputer
      ? (player == 1 ? 'You' : 'Computer')
      : (player == 1 ? 'Pink' : 'Yellow');

  String get _status {
    if (_game.winner != 0) {
      final n = _name(_game.winner);
      return n == 'You' ? 'You win!' : '$n wins!';
    }
    if (_game.isDraw) return "It's a draw";
    if (_cpuTurn) return 'Computer is thinking...';
    final n = _name(_game.current);
    return n == 'You' ? 'Your turn' : "$n's turn";
  }

  void _drop(int col) {
    if (_cpuTurn) return; // input is locked while the computer plays
    if (_game.drop(col) == -1) return;
    setState(() => _moves++);
    _maybePlayComputer();
  }

  void _maybePlayComputer() {
    if (!_cpuTurn) return;
    _cpuTimer?.cancel();
    _cpuTimer = Timer(widget.computerDelay, () {
      if (!mounted || !_cpuTurn) return;
      _game.drop(_ai.pickColumn(_game));
      setState(() => _moves++);
    });
  }

  void _restart() {
    _cpuTimer?.cancel();
    setState(() {
      _game = ConnectFourGame();
      _moves = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final over = _game.isOver;
    final statusColor = _game.winner == 0
        ? (_game.current == 1 ? c4Player1 : c4Player2)
        : (_game.winner == 1 ? c4Player1 : c4Player2);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Connect Four', style: AppTextStyles.title),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConnectFourStatusPill(
                  key: const Key('c4_status'),
                  text: _status,
                  color: statusColor,
                  live: !over,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: ConnectFourGame.cols / ConnectFourGame.rows,
                      child: ConnectFourBoard(
                        game: _game,
                        moves: _moves,
                        onColumn: _drop,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (over)
                  AppButton(
                    key: const Key('c4_play_again'),
                    text: 'Play again',
                    width: double.infinity,
                    onPressed: _restart,
                  )
                else
                  AppButton(
                    key: const Key('c4_restart'),
                    text: 'Restart',
                    variant: AppButtonVariant.secondary,
                    width: double.infinity,
                    onPressed: _restart,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
