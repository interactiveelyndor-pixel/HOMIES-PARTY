import 'dart:async';
import 'dart:math' as math;
import 'battleship_board.dart';
import 'battleship_computer_player.dart';
import 'battleship_config.dart';
import 'battleship_models.dart';

/// Pure Dart controller for Battleship game.
/// Zero Flutter imports. Handles rules, turns, placement, firing, missile animations, and CPU actions.
class BattleshipController {
  final BattleshipGameMode gameMode;
  final bool enableDelays;
  final math.Random? randomSource;

  final BattleshipBoard _player1Board = BattleshipBoard();
  final BattleshipBoard _player2Board = BattleshipBoard();

  late final BattleshipComputerPlayer _computerPlayer;

  BattleshipPlayerId _activePlayer = BattleshipPlayerId.player1;
  BattleshipPhase _phase = BattleshipPhase.placement;
  BattleshipPlayerId? _winner;

  // Placement state
  ShipType _selectedShip = ShipType.battleship;
  ShipOrientation _placementOrientation = ShipOrientation.horizontal;
  BattleshipPlayerId _placingPlayer = BattleshipPlayerId.player1;

  // Firing and animation state
  ShotResult? _lastShotResult;
  bool _isProcessingAction = false;
  bool _isCpuThinking = false;
  Coordinate? _animatingMissileTarget;
  BattleshipPlayerId? _animatingShooter;
  Timer? _cpuTimer;
  Timer? _missileTimer;

  // Listeners
  final List<void Function()> _listeners = [];

  BattleshipController({
    this.gameMode = BattleshipGameMode.vsComputer,
    this.enableDelays = true,
    this.randomSource,
  }) {
    _computerPlayer = BattleshipComputerPlayer(random: randomSource);
  }

  // --- Getters ---
  BattleshipBoard get player1Board => _player1Board;
  BattleshipBoard get player2Board => _player2Board;
  BattleshipPhase get phase => _phase;
  BattleshipPlayerId get activePlayer => _activePlayer;
  BattleshipPlayerId get placingPlayer => _placingPlayer;
  BattleshipPlayerId? get winner => _winner;
  ShipType get selectedShip => _selectedShip;
  ShipOrientation get placementOrientation => _placementOrientation;
  ShotResult? get lastShotResult => _lastShotResult;
  bool get isProcessingAction => _isProcessingAction;
  bool get isCpuThinking => _isCpuThinking;
  Coordinate? get animatingMissileTarget => _animatingMissileTarget;
  BattleshipPlayerId? get animatingShooter => _animatingShooter;
  bool get isMissileInFlight => _animatingMissileTarget != null;

  /// Returns the board of the currently active player (shows own ships and opponent hits).
  BattleshipBoard get currentOwnBoard =>
      _activePlayer == BattleshipPlayerId.player1 ? _player1Board : _player2Board;

  /// Returns the opponent board.
  BattleshipBoard get currentOpponentBoard =>
      _activePlayer == BattleshipPlayerId.player1 ? _player2Board : _player1Board;

  /// Returns the opponent's received shots map for the target board.
  /// Does NOT expose opponent's unhit ship positions.
  Map<Coordinate, CellShotStatus> get targetBoardShots =>
      currentOpponentBoard.receivedShots;

  /// Returns only the placed ships of the opponent that are already completely sunk.
  /// Unsunk opponent ships are strictly NEVER returned.
  List<PlacedShip> get opponentSunkShips =>
      currentOpponentBoard.sunkPlacedShips;

  /// True if current placing player's fleet is complete.
  bool get isCurrentPlacementComplete {
    final board = _placingPlayer == BattleshipPlayerId.player1
        ? _player1Board
        : _player2Board;
    return board.isFleetComplete;
  }

  // --- Listener management ---
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  // --- Placement Methods ---

  /// Changes the currently selected ship for placement.
  void selectShip(ShipType type) {
    if (_phase != BattleshipPhase.placement) return;
    _selectedShip = type;
    _notifyListeners();
  }

  /// Toggles orientation between horizontal and vertical.
  void rotateOrientation() {
    _placementOrientation = _placementOrientation.rotated;
    _notifyListeners();
  }

  /// Taps a cell to place the currently selected ship.
  bool placeSelectedShip(Coordinate bow) {
    if (_phase != BattleshipPhase.placement) return false;
    final board = _placingPlayer == BattleshipPlayerId.player1
        ? _player1Board
        : _player2Board;

    final success = board.placeShip(_selectedShip, bow, _placementOrientation);
    if (success) {
      // Auto-advance to next unplaced ship if any
      final unplaced = ShipType.values
          .where((t) => !board.ships.containsKey(t))
          .toList();
      if (unplaced.isNotEmpty) {
        _selectedShip = unplaced.first;
      }
      _notifyListeners();
    }
    return success;
  }

  /// Places all 4 ships randomly for the currently placing player.
  void placeRandomFleet() {
    if (_phase != BattleshipPhase.placement) return;
    final board = _placingPlayer == BattleshipPlayerId.player1
        ? _player1Board
        : _player2Board;

    BattleshipComputerPlayer.placeRandomFleet(
      board,
      random: randomSource,
    );
    _notifyListeners();
  }

  /// Clears all ship placements for current placing player.
  void resetPlacement() {
    if (_phase != BattleshipPhase.placement) return;
    final board = _placingPlayer == BattleshipPlayerId.player1
        ? _player1Board
        : _player2Board;

    board.clearShips();
    _selectedShip = ShipType.battleship;
    _notifyListeners();
  }

  /// Confirms placement and progresses to the next step.
  bool confirmPlacement() {
    if (_phase != BattleshipPhase.placement) return false;
    final board = _placingPlayer == BattleshipPlayerId.player1
        ? _player1Board
        : _player2Board;

    if (!board.isFleetComplete) return false;

    if (gameMode == BattleshipGameMode.vsComputer) {
      // CPU places its fleet randomly
      BattleshipComputerPlayer.placeRandomFleet(
        _player2Board,
        random: randomSource,
      );
      _phase = BattleshipPhase.battle;
      _activePlayer = BattleshipPlayerId.player1;
      _notifyListeners();
      return true;
    } else {
      // Multiplayer mode: 2 humans on 1 phone
      if (_placingPlayer == BattleshipPlayerId.player1) {
        // Player 1 finished, pass to Player 2 to place fleet
        _placingPlayer = BattleshipPlayerId.player2;
        _activePlayer = BattleshipPlayerId.player2;
        _phase = BattleshipPhase.passDevice;
        _selectedShip = ShipType.battleship;
        _notifyListeners();
        return true;
      } else {
        // Player 2 finished, pass to Player 1 to start battle!
        _phase = BattleshipPhase.passDevice;
        _activePlayer = BattleshipPlayerId.player1;
        _notifyListeners();
        return true;
      }
    }
  }

  /// Called when the player taps "Ready" on the pass-the-phone screen.
  void onPassDeviceReady() {
    if (_phase != BattleshipPhase.passDevice) return;

    if (_placingPlayer == BattleshipPlayerId.player2 && !_player2Board.isFleetComplete) {
      // Transition to Player 2's placement screen
      _phase = BattleshipPhase.placement;
    } else {
      // Transition to battle screen for the active player
      _phase = BattleshipPhase.battle;
      _lastShotResult = null;
    }
    _notifyListeners();
  }

  // --- Battle Methods ---

  /// Fires a shot at the given [target] coordinate on opponent's grid.
  /// Rejects repeated cells, input during animations, and input during CPU turns.
  ShotResult? fireShot(Coordinate target) {
    if (_phase != BattleshipPhase.battle) return null;
    if (_isProcessingAction || _isCpuThinking || isMissileInFlight) return null;
    if (!target.isValid) return null;

    final opponentBoard = currentOpponentBoard;
    if (opponentBoard.hasBeenShot(target)) {
      return null; // Cell already shot, ignore
    }

    _isProcessingAction = true;

    if (enableDelays && BattleshipConfig.missileAnimationDurationMs > 0) {
      // Launch missile animation (~400 ms)
      _animatingMissileTarget = target;
      _animatingShooter = _activePlayer;
      _notifyListeners();

      _missileTimer?.cancel();
      _missileTimer = Timer(
        Duration(milliseconds: BattleshipConfig.missileAnimationDurationMs),
        () => _resolveHumanShot(target),
      );
      return null;
    } else {
      return _resolveHumanShot(target);
    }
  }

  ShotResult? _resolveHumanShot(Coordinate target) {
    _animatingMissileTarget = null;
    _animatingShooter = null;

    final opponentBoard = currentOpponentBoard;
    final result = opponentBoard.receiveShot(target);
    _lastShotResult = result;

    if (result.isWin) {
      _winner = _activePlayer;
      _phase = BattleshipPhase.gameOver;
      _isProcessingAction = false;
      _notifyListeners();
      return result;
    }

    if (gameMode == BattleshipGameMode.vsComputer) {
      // Human fired, turn switches to CPU
      _activePlayer = BattleshipPlayerId.player2;
      _isProcessingAction = false;
      _notifyListeners();
      _triggerCpuTurn();
    } else {
      // Multiplayer: Human fired, shot result is visible
      _isProcessingAction = false;
      _notifyListeners();
    }

    return result;
  }

  /// In multiplayer mode, advances turn to the next player and shows pass phone overlay.
  void advanceMultiplayerTurn() {
    if (gameMode != BattleshipGameMode.multiplayer) return;
    if (_phase != BattleshipPhase.battle) return;
    if (_winner != null || _isProcessingAction || isMissileInFlight) return;

    _activePlayer = _activePlayer.opponent;
    _phase = BattleshipPhase.passDevice;
    _notifyListeners();
  }

  /// Triggers the computer player's automated turn.
  void _triggerCpuTurn() {
    if (_phase != BattleshipPhase.battle || _winner != null) return;

    _isCpuThinking = true;
    _notifyListeners();

    if (enableDelays && BattleshipConfig.computerShotDelayMs > 0) {
      _cpuTimer?.cancel();
      _cpuTimer = Timer(
        Duration(milliseconds: BattleshipConfig.computerShotDelayMs),
        _launchCpuMissile,
      );
    } else {
      _launchCpuMissile();
    }
  }

  /// CPU launches missile animation toward its chosen target.
  void _launchCpuMissile() {
    if (_phase != BattleshipPhase.battle || _winner != null) {
      _isCpuThinking = false;
      _notifyListeners();
      return;
    }

    final target = _computerPlayer.getNextShot();

    if (enableDelays && BattleshipConfig.missileAnimationDurationMs > 0) {
      _isCpuThinking = false;
      _isProcessingAction = true;
      _animatingMissileTarget = target;
      _animatingShooter = BattleshipPlayerId.player2;
      _notifyListeners();

      _missileTimer?.cancel();
      _missileTimer = Timer(
        Duration(milliseconds: BattleshipConfig.missileAnimationDurationMs),
        () => _resolveCpuShot(target),
      );
    } else {
      _isCpuThinking = false;
      _resolveCpuShot(target);
    }
  }

  /// Resolves the computer's shot after missile animation lands.
  void _resolveCpuShot(Coordinate target) {
    _animatingMissileTarget = null;
    _animatingShooter = null;

    final result = _player1Board.receiveShot(target);
    _computerPlayer.recordShotResult(result);
    _lastShotResult = result;

    _isProcessingAction = false;

    if (result.isWin) {
      _winner = BattleshipPlayerId.player2;
      _phase = BattleshipPhase.gameOver;
    } else {
      _activePlayer = BattleshipPlayerId.player1;
    }

    _notifyListeners();
  }

  /// Restarts the game to initial state.
  void restart() {
    _missileTimer?.cancel();
    _missileTimer = null;
    _cpuTimer?.cancel();
    _cpuTimer = null;
    _animatingMissileTarget = null;
    _animatingShooter = null;
    _player1Board.clear();
    _player2Board.clear();
    _activePlayer = BattleshipPlayerId.player1;
    _placingPlayer = BattleshipPlayerId.player1;
    _selectedShip = ShipType.battleship;
    _placementOrientation = ShipOrientation.horizontal;
    _phase = BattleshipPhase.placement;
    _winner = null;
    _lastShotResult = null;
    _isProcessingAction = false;
    _isCpuThinking = false;
    _notifyListeners();
  }

  /// Disposes active timers and listeners safely.
  void dispose() {
    _missileTimer?.cancel();
    _missileTimer = null;
    _cpuTimer?.cancel();
    _cpuTimer = null;
    _animatingMissileTarget = null;
    _animatingShooter = null;
    _listeners.clear();
  }
}
