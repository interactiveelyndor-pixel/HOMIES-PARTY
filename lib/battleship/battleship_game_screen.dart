import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'battleship_board_widget.dart';
import 'battleship_colors.dart';
import 'battleship_config.dart';
import 'battleship_controller.dart';
import 'battleship_game_over_dialog.dart';
import 'battleship_models.dart';
import 'battleship_pass_phone_overlay.dart';
import 'battleship_player_card.dart';

/// Main Battleship Game Screen.
/// Supports both "Multiplayer (Friends)" and "vs Computer" modes.
class BattleshipGameScreen extends StatefulWidget {
  final BattleshipGameMode gameMode;
  final BattleshipController? controller;

  const BattleshipGameScreen({
    super.key,
    this.gameMode = BattleshipGameMode.vsComputer,
    this.controller,
  });

  @override
  State<BattleshipGameScreen> createState() => _BattleshipGameScreenState();
}

class _BattleshipGameScreenState extends State<BattleshipGameScreen> {
  late final BattleshipController _controller;
  bool _ownsController = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = BattleshipController(gameMode: widget.gameMode);
      _ownsController = true;
    }
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});

    if (_controller.phase == BattleshipPhase.gameOver && !_dialogOpen) {
      _dialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWinnerDialog();
      });
    }
  }

  void _showWinnerDialog() {
    final winner = _controller.winner ?? BattleshipPlayerId.player1;
    final isPlayer1 = winner == BattleshipPlayerId.player1;
    final winnerName = isPlayer1
        ? 'Player 1'
        : (_controller.gameMode == BattleshipGameMode.vsComputer
            ? 'Computer (CPU)'
            : 'Player 2');
    final winnerColor = isPlayer1
        ? BattleshipColors.player1Color
        : (_controller.gameMode == BattleshipGameMode.vsComputer
            ? BattleshipColors.cpuColor
            : BattleshipColors.player2Color);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BattleshipGameOverDialog(
        winnerName: winnerName,
        winnerColor: winnerColor,
        onRetry: () {
          Navigator.of(context).pop();
          _dialogOpen = false;
          _controller.restart();
        },
        onHome: () {
          Navigator.of(context).pop();
          _dialogOpen = false;
          Navigator.of(context).pop(); // Back to mode or home
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BattleshipColors.backgroundBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              BattleshipColors.backgroundTop,
              BattleshipColors.backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: _controller.phase == BattleshipPhase.placement
                            ? _buildPlacementView(constraints)
                            : _buildBattleView(constraints),
                      ),
                    ],
                  );
                },
              ),

              // Full-screen privacy shield for pass-the-phone
              if (_controller.phase == BattleshipPhase.passDevice)
                Positioned.fill(
                  child: BattleshipPassPhoneOverlay(
                    targetPlayer: _controller.activePlayer,
                    onReady: _controller.onPassDeviceReady,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final modeTitle = _controller.gameMode == BattleshipGameMode.vsComputer
        ? 'vs Computer'
        : 'Multiplayer';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('battleship_game_back_button'),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Battleship · $modeTitle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            key: const Key('battleship_restart_button'),
            icon: const Icon(
              Icons.refresh_rounded,
              color: BattleshipColors.textSecondary,
              size: 22,
            ),
            onPressed: _controller.restart,
          ),
        ],
      ),
    );
  }

  // --- PLACEMENT VIEW ---
  Widget _buildPlacementView(BoxConstraints constraints) {
    final placingPlayer = _controller.placingPlayer;
    final isP1 = placingPlayer == BattleshipPlayerId.player1;
    final playerName = isP1 ? 'Player 1' : 'Player 2';
    final playerColor =
        isP1 ? BattleshipColors.player1Color : BattleshipColors.player2Color;
    final board = isP1 ? _controller.player1Board : _controller.player2Board;

    // Board size dynamically calculated to fit view comfortably
    final maxAvailableHeight = constraints.maxHeight - 210;
    final boardSize = math
        .min(constraints.maxWidth - 28, maxAvailableHeight)
        .clamp(200.0, 340.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$playerName: Place Fleet',
                  style: TextStyle(
                    color: playerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BattleshipColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BattleshipColors.surfaceCardBorder),
                ),
                child: Text(
                  '${board.placedShipCount} / ${BattleshipConfig.totalShips} Placed',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ship Selector Chips
          Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: [
              for (final ship in ShipType.values)
                _buildShipChip(ship, board.ships.containsKey(ship)),
            ],
          ),
          const SizedBox(height: 8),

          // Control Buttons: Rotate, Random, Reset
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('battleship_rotate_button'),
                  icon: Icon(
                    _controller.placementOrientation ==
                            ShipOrientation.horizontal
                        ? Icons.swap_horiz_rounded
                        : Icons.swap_vert_rounded,
                    size: 15,
                    color: BattleshipColors.accentCyan,
                  ),
                  label: Text(
                    _controller.placementOrientation ==
                            ShipOrientation.horizontal
                        ? 'Rotate (H)'
                        : 'Rotate (V)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: BattleshipColors.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                      color:
                          BattleshipColors.accentCyan.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _controller.rotateOrientation,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('battleship_random_button'),
                  icon: const Icon(
                    Icons.shuffle_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    'Random',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _controller.placeRandomFleet,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('battleship_reset_button'),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _controller.resetPlacement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Board for placement
          Center(
            child: BattleshipBoardWidget(
              boardSize: boardSize,
              isTargetGrid: false,
              ownBoard: board,
              onCellTap: (coord) => _controller.placeSelectedShip(coord),
            ),
          ),
          const SizedBox(height: 12),

          // Start / Ready Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              key: const Key('battleship_start_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: board.isFleetComplete
                    ? BattleshipColors.accentGreen
                    : Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: board.isFleetComplete ? 4 : 0,
              ),
              onPressed: board.isFleetComplete
                  ? _controller.confirmPlacement
                  : null,
              child: Text(
                board.isFleetComplete
                    ? (_controller.gameMode == BattleshipGameMode.multiplayer &&
                            placingPlayer == BattleshipPlayerId.player1
                        ? 'Next: Player 2 Placement'
                        : 'Start Battle!')
                    : 'Place All ${BattleshipConfig.totalShips} Ships to Start',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShipChip(ShipType type, bool isPlaced) {
    final isSelected = _controller.selectedShip == type;

    return GestureDetector(
      onTap: () => _controller.selectShip(type),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? BattleshipColors.accentCyan.withValues(alpha: 0.25)
              : BattleshipColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? BattleshipColors.accentCyan
                : (isPlaced ? BattleshipColors.accentGreen : Colors.white24),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaced)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 11,
                  color: BattleshipColors.accentGreen,
                ),
              ),
            Text(
              '${type.displayName} (${type.length})',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isPlaced ? Colors.white70 : BattleshipColors.textMuted),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BATTLE VIEW ---
  Widget _buildBattleView(BoxConstraints constraints) {
    final isP1 = _controller.activePlayer == BattleshipPlayerId.player1;
    final isVsCpu = _controller.gameMode == BattleshipGameMode.vsComputer;

    // Heights calculation: One large primary board + compact mini fleet board
    final availableHeight = constraints.maxHeight - 110;
    final targetSize =
        (availableHeight * 0.50).clamp(210.0, 260.0).toDouble();
    final ownSize =
        (availableHeight * 0.28).clamp(120.0, 150.0).toDouble();

    // Determine which board receives missile animation
    final isCpuFiring =
        _controller.animatingShooter == BattleshipPlayerId.player2;
    final missileOnTarget = !isCpuFiring ? _controller.animatingMissileTarget : null;
    final missileOnOwn = isCpuFiring ? _controller.animatingMissileTarget : null;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player Cards Row
          Row(
            children: [
              Expanded(
                child: BattleshipPlayerCard(
                  title: 'Player 1',
                  isActive: isP1,
                  board: _controller.player1Board,
                  accentColor: BattleshipColors.player1Color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BattleshipPlayerCard(
                  title: isVsCpu ? 'Computer' : 'Player 2',
                  isCpu: isVsCpu,
                  isActive: !isP1,
                  board: _controller.player2Board,
                  accentColor: isVsCpu
                      ? BattleshipColors.cpuColor
                      : BattleshipColors.player2Color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Shot Feedback Banner
          _buildShotFeedbackBanner(),
          const SizedBox(height: 6),

          // Target Board (Large Primary Action Grid)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TARGET RADAR',
                style: TextStyle(
                  color: BattleshipColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              if (_controller.isCpuThinking)
                Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: BattleshipColors.cpuColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CPU Thinking...',
                      style: TextStyle(
                        color: BattleshipColors.cpuColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (_controller.isMissileInFlight)
                Text(
                  '🚀 In Flight...',
                  style: TextStyle(
                    color: BattleshipColors.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          Center(
            child: BattleshipBoardWidget(
              boardSize: targetSize,
              isTargetGrid: true,
              targetShots: _controller.targetBoardShots,
              sunkEnemyShips: _controller.opponentSunkShips,
              animatingMissileTarget: missileOnTarget,
              interactive: !_controller.isCpuThinking &&
                  !_controller.isProcessingAction &&
                  !_controller.isMissileInFlight &&
                  (!isVsCpu || isP1),
              onCellTap: (coord) => _controller.fireShot(coord),
            ),
          ),
          const SizedBox(height: 8),

          // Multiplayer Turn Handover Button
          if (!isVsCpu &&
              _controller.lastShotResult != null &&
              _controller.phase == BattleshipPhase.battle &&
              !_controller.isMissileInFlight) ...[
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                key: const Key('battleship_pass_turn_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BattleshipColors.accentCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  'End Turn · Pass to ${isP1 ? "Player 2" : "Player 1"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _controller.advanceMultiplayerTurn,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Own Fleet Board (Smaller Mini-Board Below)
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: BattleshipColors.player1Color,
              ),
              const SizedBox(width: 4),
              Text(
                'MY FLEET (DEFENSE)',
                style: TextStyle(
                  color: BattleshipColors.player1Color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Center(
            child: BattleshipBoardWidget(
              boardSize: ownSize,
              isTargetGrid: false,
              ownBoard: _controller.currentOwnBoard,
              animatingMissileTarget: missileOnOwn,
              interactive: false,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildShotFeedbackBanner() {
    final result = _controller.lastShotResult;
    if (result == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: BattleshipColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Select an ocean coordinate on the Target Radar to fire.',
          style: TextStyle(
            color: BattleshipColors.textSecondary,
            fontSize: 11.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    Color bannerColor;
    IconData icon;
    String message;

    if (result.isSunk) {
      bannerColor = BattleshipColors.shipSunk;
      icon = Icons.warning_rounded;
      message = 'SUNK! Enemy ${result.sunkShipName ?? "Ship"} was destroyed!';
    } else if (result.isHit) {
      bannerColor = BattleshipColors.hitColor;
      icon = Icons.local_fire_department_rounded;
      message = 'DIRECT HIT at (${result.coordinate.row + 1}, ${String.fromCharCode(65 + result.coordinate.col)})!';
    } else {
      bannerColor = BattleshipColors.missColor;
      icon = Icons.water_drop_rounded;
      message = 'MISS! Shot splashed into open water.';
    }

    return Container(
      key: const Key('battleship_shot_feedback'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: bannerColor, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
