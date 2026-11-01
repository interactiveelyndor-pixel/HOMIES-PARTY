import 'package:flutter/material.dart';

import '../logic/ludo_computer_player.dart';
import '../logic/ludo_controller.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../theme/ludo_colors.dart';
import '../theme/ludo_theme.dart';
import '../widgets/dice_widget.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/game_status_banner.dart';
import '../widgets/ludo_board_widget.dart';
import '../widgets/player_card_widget.dart';
import '../widgets/player_selection_dialog.dart';
import '../widgets/rules_dialog.dart';

class LudoGameScreen extends StatefulWidget {
  final int initialPlayerCount;
  final LudoController? controller;

  /// When true Player 2 (Yellow) is controlled by the computer.
  /// Only relevant for 2-player games; ignored otherwise.
  final bool vsComputer;

  const LudoGameScreen({
    super.key,
    this.initialPlayerCount = 4,
    this.controller,
    this.vsComputer = false,
  });

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen> {
  late LudoController _controller;
  int _playerCount = 4;
  bool _vsComputer = false;
  bool _hasShownWinnerDialog = false;

  /// The CPU player helper — non-null only when [_vsComputer] is true.
  LudoComputerPlayer? _cpu;

  @override
  void initState() {
    super.initState();
    _playerCount = widget.initialPlayerCount;
    _vsComputer = widget.vsComputer && _playerCount == 2;
    _controller =
        widget.controller ?? LudoController(playerCount: _playerCount);
    _controller.addListener(_onGameStateChanged);
    _initCpu();
    // Kick the CPU if it starts first (shouldn't happen normally but safe).
    _cpu?.onStateChanged();
  }

  // ---------------------------------------------------------------------------
  // CPU lifecycle
  // ---------------------------------------------------------------------------

  void _initCpu() {
    _cpu?.cancel();
    _cpu = null;
    if (_vsComputer && _playerCount == 2) {
      _cpu = LudoComputerPlayer(
        controller: _controller,
        cpuColor: PlayerColor.yellow,
      );
    }
  }

  void _cancelCpu() {
    _cpu?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Helpers: is the current turn computer-controlled?
  // ---------------------------------------------------------------------------

  bool get _isComputerTurn =>
      _vsComputer &&
      _controller.state.currentPlayer.color == PlayerColor.yellow &&
      !_controller.state.isGameOver;

  // ---------------------------------------------------------------------------
  // Controller listener
  // ---------------------------------------------------------------------------

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});

    final state = _controller.state;

    // ── Winner dialog ────────────────────────────────────────────────────────
    if (state.phase == TurnPhase.gameWon &&
        !_hasShownWinnerDialog &&
        state.winner != null) {
      _hasShownWinnerDialog = true;
      _cancelCpu();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWinnerDialog(state.winner!);
      });
    }

    // ── Auto-select single legal token (human turns only) ────────────────────
    if (state.phase == TurnPhase.waitingForTokenSelection &&
        state.movableTokenIds.length == 1 &&
        !_isComputerTurn) {
      final singleTokenId = state.movableTokenIds.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.state.phase == TurnPhase.waitingForTokenSelection &&
            _controller.state.movableTokenIds.contains(singleTokenId) &&
            !_controller.isProcessingAction &&
            !_isComputerTurn) {
          _controller.selectToken(singleTokenId);
        }
      });
    }

    // ── CPU turn ─────────────────────────────────────────────────────────────
    _cpu?.onStateChanged();
  }

  // ---------------------------------------------------------------------------
  // Game lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _cancelCpu();
    _controller.removeListener(_onGameStateChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _showWinnerDialog(Player winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GameOverDialog(
          winner: winner,
          onPlayAgain: () {
            Navigator.of(context).pop();
            _restartGame();
          },
          onChangeMode: () {
            Navigator.of(context).pop();
            _showPlayerSelectionDialog();
          },
        );
      },
    );
  }

  void _restartGame() {
    _hasShownWinnerDialog = false;
    _cancelCpu();
    _controller.initGame(playerCount: _playerCount);
    _cpu?.reset();
    // Kick the CPU if it has the first turn after restart.
    _cpu?.onStateChanged();
  }

  void _showPlayerSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return PlayerSelectionDialog(
          currentCount: _playerCount,
          currentVsComputer: _vsComputer,
          onSelectMode: (count, {bool vsComputer = false}) {
            final newVsComputer = vsComputer && count == 2;
            setState(() {
              _playerCount = count;
              _vsComputer = newVsComputer;
              _hasShownWinnerDialog = false;
            });
            _cancelCpu();
            _controller.initGame(playerCount: count);
            _initCpu();
            _cpu?.onStateChanged();
          },
        );
      },
    );
  }

  void _showRulesDialog() {
    showDialog(context: context, builder: (context) => const RulesDialog());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final currentPlayer = state.currentPlayer;
    final activeColor = LudoTheme.getPrimary(currentPlayer.color);
    final isRolling = state.phase == TurnPhase.rollingDice;
    final canRoll = state.canRollDice && !_isComputerTurn;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LudoColors.backgroundTop, LudoColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),

              // Game Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Top Player Cards Row
                      _buildTopPlayerRow(state),

                      // Responsive 15x15 Ludo Board
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: LudoBoardWidget(
                              state: state,
                              // Block taps on board during computer turn.
                              onTokenTap: _isComputerTurn
                                  ? (_) {}
                                  : _controller.onTokenTap,
                            ),
                          ),
                        ),
                      ),

                      // Bottom Player Cards Row
                      _buildBottomPlayerRow(state),

                      // Turn Status Banner
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: GameStatusBanner(state: state),
                      ),

                      // Bottom Controls Console
                      _buildControlsConsole(
                        state: state,
                        currentPlayer: currentPlayer,
                        activeColor: activeColor,
                        canRoll: canRoll,
                        isRolling: isRolling,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final label = _vsComputer ? '2P+CPU' : '${_playerCount}P';
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              key: const Key('ludo_back_button'),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: LudoColors.textSecondary,
                size: 18,
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: LudoColors.bluePrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    color: LudoColors.bluePrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Ludo Classic',
                    style: TextStyle(
                      color: LudoColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Players mode button
              TextButton.icon(
                key: const Key('player_mode_button'),
                onPressed: _showPlayerSelectionDialog,
                icon: const Icon(Icons.group_rounded, size: 14),
                label: Text(label),
                style: TextButton.styleFrom(
                  foregroundColor: LudoColors.textSecondary,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Rules button
              IconButton(
                key: const Key('rules_button'),
                icon: const Icon(Icons.help_outline_rounded),
                color: LudoColors.textSecondary,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Rules',
                onPressed: _showRulesDialog,
              ),
              const SizedBox(width: 4),
              // Restart button
              IconButton(
                key: const Key('restart_button'),
                icon: const Icon(Icons.refresh_rounded),
                color: LudoColors.textSecondary,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Restart Game',
                onPressed: _restartGame,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPlayerRow(GameState state) {
    final redPlayer = state.players.cast<Player?>().firstWhere(
      (p) => p?.color == PlayerColor.red,
      orElse: () => null,
    );

    final greenPlayer = state.players.cast<Player?>().firstWhere(
      (p) => p?.color == PlayerColor.green,
      orElse: () => null,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (redPlayer != null)
          PlayerCardWidget(
            player: redPlayer,
            isCurrentTurn: state.currentPlayer.color == PlayerColor.red,
            isCpu: false, // Red is always human
          )
        else
          const SizedBox.shrink(),
        if (greenPlayer != null)
          PlayerCardWidget(
            player: greenPlayer,
            isCurrentTurn: state.currentPlayer.color == PlayerColor.green,
            isCpu: false,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildBottomPlayerRow(GameState state) {
    final bluePlayer = state.players.cast<Player?>().firstWhere(
      (p) => p?.color == PlayerColor.blue,
      orElse: () => null,
    );

    final yellowPlayer = state.players.cast<Player?>().firstWhere(
      (p) => p?.color == PlayerColor.yellow,
      orElse: () => null,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (bluePlayer != null)
          PlayerCardWidget(
            player: bluePlayer,
            isCurrentTurn: state.currentPlayer.color == PlayerColor.blue,
            isCpu: false,
          )
        else
          const SizedBox.shrink(),
        if (yellowPlayer != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PlayerCardWidget(
                player: yellowPlayer,
                isCurrentTurn: state.currentPlayer.color == PlayerColor.yellow,
                // Yellow is CPU only in 2-player vs-computer mode.
                isCpu: _vsComputer && _playerCount == 2,
              ),
              if (_isComputerTurn)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.computer_rounded,
                        color: LudoColors.yellowPrimary,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        "Computer's Turn",
                        style: TextStyle(
                          color: LudoColors.yellowPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildControlsConsole({
    required GameState state,
    required Player currentPlayer,
    required Color activeColor,
    required bool canRoll,
    required bool isRolling,
  }) {
    // ── vs Computer mode: centered shared dice ───────────────────────────────
    if (_vsComputer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Current Player Info
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        currentPlayer.name[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                          currentPlayer.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isComputerTurn
                              ? "Computer's Turn"
                              : state.phase ==
                                    TurnPhase.waitingForTokenSelection
                              ? 'Select token'
                              : canRoll
                              ? 'Tap to roll'
                              : isRolling
                              ? 'Rolling...'
                              : 'Moving...',
                          style: TextStyle(
                            color:
                                state.phase ==
                                        TurnPhase.waitingForTokenSelection &&
                                    !_isComputerTurn
                                ? LudoColors.starGold
                                : LudoColors.textSecondary,
                            fontSize: 11,
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

            // Center: Shared Dice (Centered Horizontally)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DiceWidget(
                  key: const Key('dice_widget'),
                  value: state.diceValue,
                  isRolling: isRolling,
                  canRoll: canRoll,
                  playerColor: currentPlayer.color,
                  size: 46,
                  onRoll: _isComputerTurn
                      ? () {}
                      : () => _controller.rollDice(),
                ),
              ),
            ),

            // Right: Roll / Move Action Button
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  key: const Key('roll_button'),
                  onPressed: canRoll ? () => _controller.rollDice() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: canRoll ? 4 : 0,
                  ),
                  child: Text(
                    isRolling
                        ? '...'
                        : state.phase == TurnPhase.waitingForTokenSelection
                        ? 'MOVE'
                        : 'ROLL',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Multiplayer mode: unchanged original layout ──────────────────────────
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current Player Info
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      currentPlayer.name[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                        currentPlayer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _isComputerTurn
                            ? "Computer's Turn"
                            : state.phase == TurnPhase.waitingForTokenSelection
                            ? 'Select token'
                            : canRoll
                            ? 'Tap to roll'
                            : isRolling
                            ? 'Rolling...'
                            : 'Moving...',
                        style: TextStyle(
                          color:
                              state.phase ==
                                      TurnPhase.waitingForTokenSelection &&
                                  !_isComputerTurn
                              ? LudoColors.starGold
                              : LudoColors.textSecondary,
                          fontSize: 11.5,
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
          // Dice and Roll Button — disabled on computer turn
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DiceWidget(
                key: const Key('dice_widget'),
                value: state.diceValue,
                isRolling: isRolling,
                canRoll: canRoll,
                playerColor: currentPlayer.color,
                size: 46,
                onRoll: _isComputerTurn ? () {} : () => _controller.rollDice(),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                key: const Key('roll_button'),
                onPressed: canRoll ? () => _controller.rollDice() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: canRoll ? 4 : 0,
                ),
                child: Text(
                  isRolling
                      ? '...'
                      : state.phase == TurnPhase.waitingForTokenSelection
                      ? 'MOVE'
                      : 'ROLL',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
