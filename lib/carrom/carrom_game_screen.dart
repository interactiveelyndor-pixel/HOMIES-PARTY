import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'carrom_board_widget.dart';
import 'carrom_colors.dart';
import 'carrom_computer_player.dart';
import 'carrom_config.dart';
import 'carrom_controller.dart';
import 'carrom_models.dart';
import 'carrom_player_card.dart';
import '../widgets/winner_banner.dart';

/// Mobile-first responsive game screen for Classic Carrom.
/// Automatically runs the physics ticker and sizes the board to fit
/// compact (360x640), standard (390x844), and tall (412x923) screens.
class CarromGameScreen extends StatefulWidget {
  final CarromController? controller;

  /// When true, Player 2 (Black) is controlled by the computer.
  /// Player 1 (White) is always the human.
  final bool vsComputer;

  const CarromGameScreen({
    super.key,
    this.controller,
    this.vsComputer = false,
  });

  @override
  State<CarromGameScreen> createState() => _CarromGameScreenState();
}

class _CarromGameScreenState extends State<CarromGameScreen>
    with SingleTickerProviderStateMixin {
  late final CarromController _controller;
  late final Ticker _ticker;
  Duration _lastTickTime = Duration.zero;

  CarromComputerPlayer? _cpu;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        CarromController(
          player2Name: widget.vsComputer ? 'CPU' : 'Player 2',
        );

    if (widget.vsComputer) {
      _cpu = CarromComputerPlayer(controller: _controller);
    }

    _controller.addListener(_onControllerUpdate);

    _ticker = createTicker(_onTick);
    if (_controller.state.phase == CarromTurnPhase.simulating) {
      _ticker.start();
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      if (_controller.state.phase == CarromTurnPhase.simulating) {
        if (!_ticker.isActive) {
          _lastTickTime = Duration.zero;
          _ticker.start();
        }
      } else {
        if (_ticker.isActive) {
          _ticker.stop();
        }
        // After simulation ends, trigger CPU turn if applicable.
        _maybeTriggerCpuTurn();
      }
      setState(() {});
    }
  }

  void _maybeTriggerCpuTurn() {
    if (_cpu == null) return;
    final state = _controller.state;
    if (state.phase == CarromTurnPhase.gameOver) return;
    if (state.currentTurn == CarromPlayerId.player2) {
      _cpu!.scheduleTurn();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    // Clamp dt to prevent physics explosion after app pause/resume
    final clampedDt = math.min(dt, 0.05);

    if (_controller.state.phase == CarromTurnPhase.simulating) {
      _controller.tick(clampedDt);
    }
  }

  @override
  void dispose() {
    _cpu?.dispose();
    _ticker.dispose();
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _showRulesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Carrom Rules',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RuleBullet(
                title: 'Players & Scoring',
                desc: 'Either player can pocket any coin. White = 20 pts, Black = 10 pts, Queen = 50 pts.',
              ),
              _RuleBullet(
                title: 'Shooting',
                desc: 'Slide the striker along your baseline, drag backward to aim and set power, then release.',
              ),
              _RuleBullet(
                title: 'Extra Shot',
                desc: 'Pocketing any coin legally gives you another shot.',
              ),
              _RuleBullet(
                title: 'Foul (Striker Pocketed)',
                desc: 'Pocketing the striker is a foul: 1 previously pocketed coin is returned to center as a penalty and your turn ends.',
              ),
              _RuleBullet(
                title: 'The Queen (Red Coin)',
                desc: 'Pocketing the Queen requires covering it by pocketing any coin (White or Black) on the same shot or the very next shot. Otherwise, the Queen returns to the center.',
              ),
              _RuleBullet(
                title: 'Winning by Points',
                desc: 'When the board is cleared, the player with the highest total score wins!',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(color: CarromColors.activeGlow)),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Restart Match?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will reset all coins and score progress.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Cancel in-flight CPU actions before resetting.
              _cpu?.dispose();
              _controller.resetGame(
                player2Name: widget.vsComputer ? 'CPU' : 'Player 2',
              );
              // Re-attach a fresh computer player.
              if (widget.vsComputer) {
                _cpu = CarromComputerPlayer(controller: _controller);
              }
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final isSimulating = state.phase == CarromTurnPhase.simulating;
    final isGameOver = state.phase == CarromTurnPhase.gameOver;
    // True when it is the CPU's turn and input should be blocked.
    final isCpuTurn = widget.vsComputer &&
        state.currentTurn == CarromPlayerId.player2 &&
        !isGameOver;

    return Scaffold(
      backgroundColor: CarromColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;

            // Header ~48, Top Card ~52, Bottom Card ~52, Status ~36, Slider ~44, Spacings ~38
            const fixedOverhead = 270.0;
            final maxBoardFromHeight = availableHeight - fixedOverhead;
            final usableWidth = availableWidth - 24.0;
            final boardSize = math
                .min(usableWidth, math.max(220.0, maxBoardFromHeight))
                .clamp(220.0, usableWidth);

            return Stack(
              children: [
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  // 1. Top Bar
                  Row(
                    children: [
                      IconButton(
                        key: const Key('carrom_back_button'),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Classic Carrom',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        key: const Key('carrom_rules_button'),
                        icon: const Icon(Icons.help_outline_rounded,
                            color: Colors.white70, size: 22),
                        onPressed: _showRulesDialog,
                      ),
                      IconButton(
                        key: const Key('carrom_reset_button'),
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white70, size: 22),
                        onPressed: _showResetDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 2. Player 2 Card (Top - Black) + optional CPU badge.
                  CarromPlayerCard(
                    key: const Key('carrom_player2_card'),
                    player: state.player2,
                    isCurrentTurn: !isGameOver && state.currentTurn == CarromPlayerId.player2,
                    queenStatus: state.queenStatus,
                    queenPocketedBy: state.queenPocketedBy,
                  ),
                  // "Computer's Turn" indicator.
                  if (isCpuTurn && !isSimulating)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.computer_rounded,
                              color: CarromColors.activeGlow, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            "Computer's Turn…",
                            style: const TextStyle(
                              color: CarromColors.activeGlow,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),

                  // 3. Status Notification Bar
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isGameOver
                          ? (state.winner != null
                              ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                              : const Color(0xFF64748B).withValues(alpha: 0.25))
                          : const Color(0xFF334155).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isGameOver
                            ? (state.winner != null
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8))
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      state.statusMessage,
                      style: TextStyle(
                        color: isGameOver
                            ? (state.winner != null
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFE2E8F0))
                            : CarromColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 4. Carrom Board
                  Expanded(
                    child: Center(
                      child: CarromBoardWidget(
                        key: const Key('carrom_board_widget'),
                        controller: _controller,
                        boardSize: boardSize,
                        blockInput: isCpuTurn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 5. Striker Placement Slider Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Text(
                          'Slide:',
                          style: TextStyle(
                            color: CarromColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: CarromColors.activeGlow,
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.15),
                              thumbColor: Colors.white,
                              overlayColor:
                                  CarromColors.activeGlow.withValues(alpha: 0.2),
                              trackHeight: 3.5,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7.0),
                            ),
                            child: Slider(
                              key: const Key('carrom_striker_slider'),
                              value: state.strikerX.clamp(
                                CarromConfig.baselineMinX,
                                CarromConfig.baselineMaxX,
                              ),
                              min: CarromConfig.baselineMinX,
                              max: CarromConfig.baselineMaxX,
                              onChanged: (isSimulating || isGameOver || isCpuTurn)
                                  ? null
                                  : (val) => _controller.setStrikerPosition(val),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 6. Player 1 Card (Bottom - White)
                  CarromPlayerCard(
                    key: const Key('carrom_player1_card'),
                    player: state.player1,
                    isCurrentTurn: !isGameOver && state.currentTurn == CarromPlayerId.player1,
                    queenStatus: state.queenStatus,
                    queenPocketedBy: state.queenPocketedBy,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
              ), // end Padding
              // WinnerBanner overlay — shown only when game is over with a winner.
              // IgnorePointer so restart/back buttons stay tappable.
              if (isGameOver && state.winner != null)
                WinnerBanner(
                  winnerName: state.winner == CarromPlayerId.player1
                      ? state.player1.name
                      : state.player2.name,
                  winnerColor: state.winner == CarromPlayerId.player1
                      ? CarromColors.whiteCoinBase
                      : CarromColors.blackCoinBase,
                ),
              // Draw overlay — shown when game is over with equal scores.
              if (isGameOver && state.winner == null)
                IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DRAW!',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: const Color(0xFF94A3B8).withValues(alpha: 0.9),
                                blurRadius: 28,
                              ),
                              Shadow(
                                color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                                blurRadius: 60,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFF94A3B8),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF64748B).withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Text(
                            "It's a Draw!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE2E8F0),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
          },
        ),
      ),
    );
  }
}

class _RuleBullet extends StatelessWidget {
  final String title;
  final String desc;

  const _RuleBullet({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: CarromColors.activeGlow,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
