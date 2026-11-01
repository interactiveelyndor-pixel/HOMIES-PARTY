import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_dialog.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'pen_fight_board_widget.dart';
import 'pen_fight_config.dart';
import 'pen_fight_controller.dart';
import 'pen_fight_game_over_dialog.dart';
import 'pen_fight_models.dart';
import 'pen_fight_player_card.dart';
import 'pen_fight_theme.dart';

import 'dart:math' as math;

/// Full interactive game screen for Pen Fight.
/// Supports "Play with Friend" (2 players, same phone) and "vs Computer".
class PenFightGameScreen extends StatefulWidget {
  final bool vsComputer;
  final PenFightController? controller;
  final PenType p1PenType;
  final PenType p2PenType;
  final math.Random? random;

  const PenFightGameScreen({
    super.key,
    this.vsComputer = false,
    this.controller,
    this.p1PenType = PenType.balanced,
    this.p2PenType = PenType.balanced,
    this.random,
  });

  @override
  State<PenFightGameScreen> createState() => _PenFightGameScreenState();
}

class _PenFightGameScreenState extends State<PenFightGameScreen>
    with SingleTickerProviderStateMixin {
  late final PenFightController _controller;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  Timer? _cpuAimTimer;
  Timer? _cpuShootTimer;
  Timer? _roundResetTimer;
  Timer? _tableIntroTimer;
  bool _cpuTurnScheduled = false;
  bool _dialogOpen = false;
  bool _showTableIntro = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        PenFightController(
          vsComputer: widget.vsComputer,
          p1Type: widget.p1PenType,
          p2Type: widget.p2PenType,
          random: widget.random,
        );

    _triggerTableIntro();

    _ticker = createTicker(_onTick);
    if (_controller.phase == PenFightPhase.moving ||
        _controller.phase == PenFightPhase.falling) {
      _ticker.start();
    } else {
      _maybeTriggerCpuTurn();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    _ticker.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _cpuAimTimer?.cancel();
    _cpuAimTimer = null;
    _cpuShootTimer?.cancel();
    _cpuShootTimer = null;
    _roundResetTimer?.cancel();
    _roundResetTimer = null;
    _tableIntroTimer?.cancel();
    _tableIntroTimer = null;
    _cpuTurnScheduled = false;
  }

  void _triggerTableIntro() {
    _tableIntroTimer?.cancel();
    _showTableIntro = true;
    _tableIntroTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() {
          _showTableIntro = false;
        });
      }
    });
  }

  void _startSimulation() {
    _lastElapsed = Duration.zero;
    if (!_ticker.isActive) {
      _ticker.start();
    }
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final dt = (_lastElapsed == Duration.zero)
        ? 1.0 / 60.0
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    final safeDt = dt.clamp(0.001, 0.05);

    if (_controller.phase == PenFightPhase.moving ||
        _controller.phase == PenFightPhase.falling) {
      _controller.step(safeDt);
      setState(() {});

      if (_controller.phase == PenFightPhase.gameOver) {
        if (_ticker.isActive) _ticker.stop();
        _handleMatchEnd();
      } else if (_controller.phase == PenFightPhase.roundOver) {
        if (_ticker.isActive) _ticker.stop();
        _handleRoundOver();
      } else if (_controller.phase == PenFightPhase.aiming) {
        if (_ticker.isActive) _ticker.stop();
        _maybeTriggerCpuTurn();
      }
    } else {
      if (_ticker.isActive) {
        _ticker.stop();
      }
    }
  }

  void _maybeTriggerCpuTurn() {
    if (!_controller.isCpuTurn ||
        _controller.phase != PenFightPhase.aiming ||
        _cpuTurnScheduled) {
      return;
    }
    _scheduleCpuShot();
  }

  void _scheduleCpuShot() {
    _cpuTurnScheduled = true;

    // Wait botDelay (800ms) before calculating and showing aim
    _cpuAimTimer = Timer(const Duration(milliseconds: PenFightConfig.botDelay), () {
      if (!mounted || _controller.phase != PenFightPhase.aiming) return;

      final shot = _controller.computeCpuShot();
      _controller.setAim(shot);
      _controller.statusMessage = 'CPU is aiming...';
      setState(() {});

      // Show aim trajectory for botAimDisplayMs (400ms) before shooting
      _cpuShootTimer =
          Timer(const Duration(milliseconds: PenFightConfig.botAimDisplayMs), () {
        if (!mounted || _controller.phase != PenFightPhase.aiming) return;

        _controller.applyFlick(PenFightPlayerId.player2, shot.flickVelocity);
        _cpuTurnScheduled = false;
        _startSimulation();
      });
    });
  }

  void _handleRoundOver() {
    if (_roundResetTimer != null) return;

    _roundResetTimer =
        Timer(const Duration(milliseconds: PenFightConfig.roundResetDelayMs), () {
      if (!mounted) return;
      _roundResetTimer = null;
      if (_controller.phase == PenFightPhase.roundOver) {
        _controller.nextRound();
        _triggerTableIntro();
        setState(() {});
        _maybeTriggerCpuTurn();
      }
    });
  }

  void _handleMatchEnd() {
    if (_dialogOpen) return;
    _dialogOpen = true;

    final winner = _controller.matchWinner ?? PenFightPlayerId.player1;
    final winnerName = winner == PenFightPlayerId.player1
        ? _controller.player1Name
        : _controller.player2Name;
    final winnerColor = winner == PenFightPlayerId.player1
        ? PenFightTheme.p1PenHighlight
        : PenFightTheme.p2PenHighlight;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PenFightGameOverDialog(
        winnerName: winnerName,
        winnerColor: winnerColor,
        onPlayAgain: () {
          Navigator.of(ctx).pop();
          _dialogOpen = false;
          _cancelTimers();
          _controller.restartMatch();
          _triggerTableIntro();
          setState(() {});
          _maybeTriggerCpuTurn();
        },
        onHome: () {
          Navigator.of(ctx).pop();
          _dialogOpen = false;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _showRulesDialog() {
    AppDialog.show(
      context: context,
      title: 'How to Play Pen Fight',
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PenFightTheme.accent.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Text('🖊️', style: TextStyle(fontSize: 28)),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ruleItem('🎯', 'Tabletop Duel',
              'Each player commands one pen on a table with no walls.'),
          const SizedBox(height: 10),
          _ruleItem('👆', 'Aim & Flick',
              'Drag backward from your pen to aim and set flick power. Release to launch.'),
          const SizedBox(height: 10),
          _ruleItem('💥', 'Collision & Physics',
              'Pens collide with realistic momentum transfer and slide with friction.'),
          const SizedBox(height: 10),
          _ruleItem('🕳️', 'Off-Table Rules',
              'A pen is OFF when its center crosses the edge. Knock the opponent off to win the round!'),
          const SizedBox(height: 10),
          _ruleItem('⚠️', 'Fouls & Both Fall',
              'If your own pen falls off, you lose. If both pens fall off, the shooter loses!'),
          const SizedBox(height: 10),
          _ruleItem('🏆', 'Best of 3',
              'First to win 2 rounds wins the match. Pens reset between rounds.'),
        ],
      ),
      actions: [
        AppButton(
          key: const Key('pen_fight_rules_got_it'),
          text: 'Got it!',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _ruleItem(String icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTextStyles.caption.copyWith(
                  color: AppPalette.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showResetConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Match?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to restart the match? Current round scores will be reset.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            key: const Key('pen_fight_confirm_reset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancelTimers();
              _controller.restartMatch();
              _triggerTableIntro();
              setState(() {});
              _maybeTriggerCpuTurn();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 680;
              final padH = isCompact ? 10.0 : 16.0;

              return Column(
                children: [
                  // 1. Top Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH, vertical: 6),
                    child: Row(
                      children: [
                        const AppBackButton(
                          key: Key('pen_fight_back_button'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Pen Fight',
                                style: AppTextStyles.heading.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Round ${_controller.currentRound} · ${_controller.currentTableType.displayName}',
                                style: AppTextStyles.caption.copyWith(
                                  color: PenFightTheme.accentLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('pen_fight_rules_button'),
                          icon: const Icon(Icons.help_outline_rounded, size: 22),
                          color: AppPalette.textSecondary,
                          onPressed: _showRulesDialog,
                          tooltip: 'How to Play',
                        ),
                        IconButton(
                          key: const Key('pen_fight_reset_button'),
                          icon: const Icon(Icons.refresh_rounded, size: 22),
                          color: AppPalette.textSecondary,
                          onPressed: _showResetConfirmDialog,
                          tooltip: 'Restart Match',
                        ),
                      ],
                    ),
                  ),

                  // 2. Player Score Cards
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: PenFightPlayerCard(
                            key: const Key('pen_fight_player1_card'),
                            id: PenFightPlayerId.player1,
                            name: _controller.player1Name,
                            penType: _controller.pen1.type,
                            isCpu: false,
                            isCurrentTurn:
                                _controller.currentTurn == PenFightPlayerId.player1,
                            score: _controller.player1Score,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PenFightPlayerCard(
                            key: const Key('pen_fight_player2_card'),
                            id: PenFightPlayerId.player2,
                            name: _controller.player2Name,
                            penType: _controller.pen2.type,
                            isCpu: widget.vsComputer,
                            isCurrentTurn:
                                _controller.currentTurn == PenFightPlayerId.player2,
                            score: _controller.player2Score,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Status Badge Pill
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      key: const Key('pen_fight_status_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.glassSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppPalette.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _controller.statusMessage,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  // 3.5 Table Announcement Banner (shown briefly at start of each round)
                  if (_showTableIntro)
                    Container(
                      key: const Key('pen_fight_table_intro_banner'),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PenFightTheme.accent.withValues(alpha: 0.35),
                            PenFightTheme.accentLight.withValues(alpha: 0.20),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PenFightTheme.accentLight.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.currentTableType == PenFightTableType.classic
                                ? '🪵'
                                : (_controller.currentTableType == PenFightTableType.hole
                                    ? '🕳️'
                                    : '🛡️'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_controller.currentTableType.displayName} · ${_controller.currentTableType.subtitle}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 4. Center Interactive Tabletop
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: padH,
                        vertical: isCompact ? 4.0 : 8.0,
                      ),
                      child: PenFightBoardWidget(
                        controller: _controller,
                        onShotFlicked: _startSimulation,
                      ),
                    ),
                  ),

                  // 5. Turn Action Prompt / Round Over Overlay
                  if (_controller.phase == PenFightPhase.roundOver)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: PenFightTheme.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: PenFightTheme.accentLight.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔔', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'Round Complete! Next round starting...',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _controller.isCpuTurn
                            ? 'CPU is planning its shot...'
                            : 'Drag backward from your pen & release to flick',
                        style: AppTextStyles.caption.copyWith(
                          color: AppPalette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
