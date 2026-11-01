import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'battleship_colors.dart';
import 'battleship_config.dart';
import 'battleship_models.dart';
import 'battleship_board.dart';
import 'battleship_ship_painter.dart';

/// Renders an 8×8 Battleship board with CustomPainter ship silhouettes,
/// animated missile flight, and drawn hit/miss effects.
class BattleshipBoardWidget extends StatefulWidget {
  final double boardSize;
  final bool isTargetGrid;
  final BattleshipBoard? ownBoard;
  final Map<Coordinate, CellShotStatus>? targetShots;
  final List<PlacedShip>? sunkEnemyShips;
  final Coordinate? animatingMissileTarget;
  final void Function(Coordinate coord)? onCellTap;
  final Coordinate? selectedCoordinate;
  final bool interactive;

  const BattleshipBoardWidget({
    super.key,
    required this.boardSize,
    required this.isTargetGrid,
    this.ownBoard,
    this.targetShots,
    this.sunkEnemyShips,
    this.animatingMissileTarget,
    this.onCellTap,
    this.selectedCoordinate,
    this.interactive = true,
  });

  @override
  State<BattleshipBoardWidget> createState() => _BattleshipBoardWidgetState();
}

class _BattleshipBoardWidgetState extends State<BattleshipBoardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _missileAnimCtrl;
  late final Animation<double> _missileProgress;

  @override
  void initState() {
    super.initState();
    _missileAnimCtrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: BattleshipConfig.missileAnimationDurationMs,
      ),
    );
    _missileProgress = CurvedAnimation(
      parent: _missileAnimCtrl,
      curve: Curves.easeInQuad,
    );

    if (widget.animatingMissileTarget != null) {
      _missileAnimCtrl.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant BattleshipBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animatingMissileTarget != null &&
        widget.animatingMissileTarget != oldWidget.animatingMissileTarget) {
      _missileAnimCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _missileAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerSize = (widget.boardSize * 0.07).clamp(11.0, 18.0);
    final gridAreaSize = widget.boardSize - headerSize;
    final cellSize = gridAreaSize / BattleshipConfig.gridSize;

    const colHeaders = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    // Collect ships to reveal on this board
    final visibleShips = <PlacedShip>[];
    if (!widget.isTargetGrid) {
      // Own fleet: all own ships visible
      if (widget.ownBoard != null) {
        visibleShips.addAll(widget.ownBoard!.placedShips);
      }
    } else {
      // Target board: ONLY completely sunk enemy ships are revealed!
      if (widget.sunkEnemyShips != null) {
        visibleShips.addAll(widget.sunkEnemyShips!);
      }
    }

    return Container(
      width: widget.boardSize,
      height: widget.boardSize,
      decoration: BoxDecoration(
        color: BattleshipColors.gridBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isTargetGrid
              ? BattleshipColors.accentCyan.withValues(alpha: 0.4)
              : BattleshipColors.shipHullDark.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.isTargetGrid
                    ? BattleshipColors.accentCyan
                    : BattleshipColors.player1Color)
                .withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Column headers (A-H)
          SizedBox(
            height: headerSize,
            child: Row(
              children: [
                SizedBox(width: headerSize), // Corner spacer
                for (int c = 0; c < BattleshipConfig.gridSize; c++)
                  Expanded(
                    child: Center(
                      child: Text(
                        colHeaders[c],
                        style: TextStyle(
                          color: BattleshipColors.textSecondary,
                          fontSize: (headerSize * 0.65).clamp(8.0, 11.0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Row headers (1-8) + Grid Area with Ship Overlays
          Expanded(
            child: Row(
              children: [
                // Row labels
                SizedBox(
                  width: headerSize,
                  child: Column(
                    children: [
                      for (int r = 0; r < BattleshipConfig.gridSize; r++)
                        Expanded(
                          child: Center(
                            child: Text(
                              '${r + 1}',
                              style: TextStyle(
                                color: BattleshipColors.textSecondary,
                                fontSize: (headerSize * 0.6).clamp(7.5, 10.0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 8×8 Playable Grid Stack
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Base grid cells
                      Column(
                        children: [
                          for (int r = 0; r < BattleshipConfig.gridSize; r++)
                            Expanded(
                              child: Row(
                                children: [
                                  for (int c = 0;
                                      c < BattleshipConfig.gridSize;
                                      c++)
                                    Expanded(
                                      child: _buildCell(
                                        Coordinate(r, c),
                                        cellSize,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Ship silhouettes layer
                      for (final ship in visibleShips)
                        _buildShipOverlay(ship, cellSize),

                      // Missile Animation overlay
                      if (widget.animatingMissileTarget != null)
                        _buildMissileAnimation(cellSize),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Positions and renders a ship silhouette across its occupied cells.
  Widget _buildShipOverlay(PlacedShip ship, double cellSize) {
    final bow = ship.bow;
    final isHorizontal = ship.orientation == ShipOrientation.horizontal;
    final width = isHorizontal ? ship.type.length * cellSize : cellSize;
    final height = isHorizontal ? cellSize : ship.type.length * cellSize;
    final left = bow.col * cellSize;
    final top = bow.row * cellSize;

    final isSunk = widget.isTargetGrid
        ? true
        : (widget.ownBoard?.isShipSunk(ship.type) ?? false);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          child: CustomPaint(
            painter: BattleshipShipPainter(
              type: ship.type,
              orientation: ship.orientation,
              isSunk: isSunk,
            ),
          ),
        ),
      ),
    );
  }

  /// Renders traveling missile animation into the target cell.
  Widget _buildMissileAnimation(double cellSize) {
    final target = widget.animatingMissileTarget!;
    final targetX = target.col * cellSize + cellSize * 0.5;
    final targetY = target.row * cellSize + cellSize * 0.5;

    return AnimatedBuilder(
      animation: _missileProgress,
      builder: (context, child) {
        final t = _missileProgress.value;
        // Start from top of board with slight horizontal offset
        final startY = -40.0;
        final startX = targetX;
        final currentX = math.sin((1.0 - t) * math.pi) * 8.0 + startX;
        final currentY = startY + (targetY - startY) * t;

        return Positioned(
          left: currentX - 12,
          top: currentY - 12,
          width: 24,
          height: 24,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: math.pi / 2, // Point downwards
              child: const Center(
                child: Text('🚀', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(Coordinate coord, double cellSize) {
    CellShotStatus status = CellShotStatus.unshot;

    if (widget.isTargetGrid) {
      status = widget.targetShots?[coord] ?? CellShotStatus.unshot;
    } else {
      if (widget.ownBoard != null) {
        status = widget.ownBoard!.shotStatusAt(coord);
      }
    }

    // Determine cell background and icon
    Color bgColor = BattleshipColors.gridCell;
    Widget? icon;

    if (status == CellShotStatus.hit) {
      // Clear drawn explosion on HIT
      bgColor = BattleshipColors.hitColor.withValues(alpha: 0.18);
      icon = CustomPaint(
        size: Size(cellSize * 0.75, cellSize * 0.75),
        painter: const ExplosionPainter(),
      );
    } else if (status == CellShotStatus.miss) {
      // Soft water ripple on MISS
      bgColor = BattleshipColors.missColor.withValues(alpha: 0.08);
      icon = CustomPaint(
        size: Size(cellSize * 0.75, cellSize * 0.75),
        painter: const SplashRipplePainter(),
      );
    }

    final isSelected = widget.selectedCoordinate == coord;
    final canTap = widget.interactive &&
        widget.onCellTap != null &&
        (widget.isTargetGrid ? status == CellShotStatus.unshot : true);

    return GestureDetector(
      key: Key(
        '${widget.isTargetGrid ? "target" : "own"}_cell_${coord.row}_${coord.col}',
      ),
      behavior: HitTestBehavior.opaque,
      onTap: canTap ? () => widget.onCellTap!(coord) : null,
      child: Container(
        margin: const EdgeInsets.all(0.4),
        decoration: BoxDecoration(
          color: isSelected
              ? BattleshipColors.accentCyan.withValues(alpha: 0.35)
              : bgColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isSelected
                ? BattleshipColors.accentCyan
                : BattleshipColors.gridCellBorder.withValues(alpha: 0.4),
            width: isSelected ? 1.0 : 0.4,
          ),
        ),
        child: Center(child: icon),
      ),
    );
  }
}
