import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'snl_board_widget.dart';
import 'snl_colors.dart';
import 'snl_controller.dart';
import 'snl_dice_widget.dart';
import 'snl_game_state.dart';
import 'snl_player.dart';
import 'snl_player_card.dart';
import '../widgets/winner_banner.dart';


/// Main screen for the Snakes & Ladders game.
class SnlGameScreen extends StatefulWidget {
  final int initialPlayerCount;
  final SnlController? controller;

  const SnlGameScreen({
    super.key,
    this.initialPlayerCount = 4,
    this.controller,
  });

  @override
  State<SnlGameScreen> createState() => _SnlGameScreenState();
}

class _SnlGameScreenState extends State<SnlGameScreen> {
  late SnlController _controller;
  int _playerCount = 4;
  bool _hasShownWinDialog = false;

  @override
  void initState() {
    super.initState();
    _playerCount = widget.initialPlayerCount;
    _controller =
        widget.controller ?? SnlController(playerCount: _playerCount);
    _controller.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});

    if (_controller.state.phase == SnlTurnPhase.gameWon &&
        !_hasShownWinDialog &&
        _controller.state.winner != null) {
      _hasShownWinDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWinDialog(_controller.state.winner!);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _showWinDialog(SnlPlayer winner) {
    final primaryColor = winner.primaryColor;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Stack(
        alignment: Alignment.center,
        children: [
          AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text('🏆', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${winner.name} Wins!',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '${winner.name} reached cell 100 and won the game!',
          style: const TextStyle(
              color: SnlColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showPlayerSelectDialog();
            },
            child: const Text('Change Players',
                style: TextStyle(color: SnlColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _restartGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
          // WinnerBanner overlay — IgnorePointer so buttons stay tappable
          WinnerBanner(
            winnerName: winner.name,
            winnerColor: primaryColor,
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    _hasShownWinDialog = false;
    _controller.initGame(playerCount: _playerCount);
  }

  void _showPlayerSelectDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        int selected = _playerCount;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Select Players',
                style: TextStyle(
                    color: SnlColors.textPrimary,
                    fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [2, 3, 4].map((count) {
                final isSelected = count == selected;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () => setDlgState(() => selected = count),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SnlColors.accent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? SnlColors.accent
                              : Colors.white.withValues(alpha: 0.15),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: SnlColors.accent, size: 18)
                          else
                            const Icon(Icons.radio_button_unchecked,
                                color: SnlColors.textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '$count Players',
                            style: TextStyle(
                              color: isSelected
                                  ? SnlColors.textPrimary
                                  : SnlColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: SnlColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SnlColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _playerCount = selected);
                  _hasShownWinDialog = false;
                  _controller.initGame(playerCount: selected);
                },
                child: const Text('Start'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final player = state.currentPlayer;
    final primary = player.primaryColor;
    final glow = player.glowColor;
    final canRoll = state.canRollDice;
    final isRolling = state.phase == SnlTurnPhase.rollingDice;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SnlColors.backgroundTop,
              SnlColors.backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final totalHeight = constraints.maxHeight;

              // Responsiveness detection
              final isCompactHeight = totalHeight < 720;
              final isNarrow = totalWidth < 380;
              final hPadding = isNarrow ? 8.0 : 12.0;
              final usableWidth = totalWidth - (hPadding * 2);

              // Height budget for non-board UI elements
              final topBarH = isCompactHeight ? 38.0 : 44.0;
              final is4P = state.players.length > 2;
              final cardsH = is4P
                  ? (isCompactHeight ? 64.0 : 72.0)
                  : (isCompactHeight ? 36.0 : 42.0);
              final bannerH = isCompactHeight ? 32.0 : 38.0;
              final controlsH = isCompactHeight ? 56.0 : 64.0;
              final spacing = isCompactHeight ? 14.0 : 24.0;

              final nonBoardTotal = topBarH + cardsH + bannerH + controlsH + spacing;
              final maxBoardFromHeight =
                  (totalHeight - nonBoardTotal).clamp(160.0, usableWidth);
              final boardSize = math.min(usableWidth, maxBoardFromHeight);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Column(
                  children: [
                    _buildTopBar(context, isCompact: isCompactHeight),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Player cards
                          _buildPlayerCards(state, isCompact: isCompactHeight),

                          // S&L Board
                          SizedBox(
                            width: boardSize,
                            height: boardSize,
                            child: SnlBoardWidget(state: state),
                          ),

                          // Status message banner
                          _buildStatusBanner(state, isCompact: isCompactHeight),

                          // Bottom controls console
                          _buildControls(
                            state: state,
                            player: player,
                            primary: primary,
                            glow: glow,
                            canRoll: canRoll,
                            isRolling: isRolling,
                            isCompact: isCompactHeight,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, {bool isCompact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 3 : 6),
      child: Row(
        children: [
          // Back arrow
          IconButton(
            key: const Key('snl_back_button'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: SnlColors.textSecondary, size: 18),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: SnlColors.snakeBody.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Text('🐍', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Snakes & Ladders',
              style: TextStyle(
                color: SnlColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            key: const Key('snl_player_mode_button'),
            onPressed: _showPlayerSelectDialog,
            icon: const Icon(Icons.group_rounded, size: 14),
            label: Text('${_playerCount}P'),
            style: TextButton.styleFrom(
              foregroundColor: SnlColors.textSecondary,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('snl_restart_button'),
            icon: const Icon(Icons.refresh_rounded,
                color: SnlColors.textSecondary),
            iconSize: 18,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'Restart',
            onPressed: _restartGame,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCards(SnlGameState state, {bool isCompact = false}) {
    if (state.players.length == 2) {
      return Row(
        children: [
          Expanded(
            child: SnlPlayerCard(
              player: state.players[0],
              playerIndex: 0,
              isCurrentTurn: state.currentPlayerIndex == 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SnlPlayerCard(
              player: state.players[1],
              playerIndex: 1,
              isCurrentTurn: state.currentPlayerIndex == 1,
            ),
          ),
        ],
      );
    }

    if (state.players.length == 3) {
      return Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 6.0 : 0.0),
              child: SnlPlayerCard(
                player: state.players[i],
                playerIndex: i,
                isCurrentTurn: state.currentPlayerIndex == i,
              ),
            ),
          );
        }),
      );
    }

    // 4 Players: 2x2 grid so cards never get squished or overflow
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SnlPlayerCard(
                player: state.players[0],
                playerIndex: 0,
                isCurrentTurn: state.currentPlayerIndex == 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SnlPlayerCard(
                player: state.players[1],
                playerIndex: 1,
                isCurrentTurn: state.currentPlayerIndex == 1,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Row(
          children: [
            Expanded(
              child: SnlPlayerCard(
                player: state.players[2],
                playerIndex: 2,
                isCurrentTurn: state.currentPlayerIndex == 2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SnlPlayerCard(
                player: state.players[3],
                playerIndex: 3,
                isCurrentTurn: state.currentPlayerIndex == 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBanner(SnlGameState state, {bool isCompact = false}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 2 : 4),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isCompact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _phaseIcon(state.phase),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              state.message,
              style: TextStyle(
                color: SnlColors.textPrimary,
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseIcon(SnlTurnPhase phase) {
    switch (phase) {
      case SnlTurnPhase.animatingSnake:
        return const Text('🐍', style: TextStyle(fontSize: 16));
      case SnlTurnPhase.animatingLadder:
        return const Text('🪜', style: TextStyle(fontSize: 16));
      case SnlTurnPhase.gameWon:
        return const Text('🏆', style: TextStyle(fontSize: 16));
      default:
        return const Icon(Icons.casino_rounded,
            color: SnlColors.accent, size: 16);
    }
  }

  Widget _buildControls({
    required SnlGameState state,
    required SnlPlayer player,
    required Color primary,
    required Color glow,
    required bool canRoll,
    required bool isRolling,
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player info
          Expanded(
            child: Row(
              children: [
                Container(
                  width: isCompact ? 30 : 34,
                  height: isCompact ? 30 : 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.6),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      player.name[0],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 13 : 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 13 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        canRoll
                            ? 'Tap to roll'
                            : isRolling
                                ? 'Rolling...'
                                : state.isAnimating
                                    ? 'Moving...'
                                    : '',
                        style: TextStyle(
                          color: SnlColors.textSecondary,
                          fontSize: isCompact ? 11 : 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Dice + Roll button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SnlDiceWidget(
                key: const Key('snl_dice_widget'),
                value: state.diceValue,
                isRolling: isRolling,
                canRoll: canRoll,
                accentColor: primary,
                size: isCompact ? 40 : 46,
                onRoll: () => _controller.rollDice(),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                key: const Key('snl_roll_button'),
                onPressed: canRoll ? () => _controller.rollDice() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white38,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 14,
                    vertical: isCompact ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: canRoll ? 4 : 0,
                ),
                child: Text(
                  isRolling ? '...' : 'ROLL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 12 : 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
