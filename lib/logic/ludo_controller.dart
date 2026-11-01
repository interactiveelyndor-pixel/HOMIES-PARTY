import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/board_path.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../models/token.dart';

class LudoController extends ChangeNotifier {
  late GameState _state;
  final Random _random;
  final bool enableDelays;
  final Duration rollDuration;
  final Duration stepDuration;
  final Duration autoSkipDuration;

  bool _isProcessingAction = false;
  int _actionSequence = 0;

  LudoController({
    int playerCount = 4,
    List<PlayerColor>? customColors,
    Random? random,
    this.enableDelays = true,
    this.rollDuration = const Duration(milliseconds: 400),
    this.stepDuration = const Duration(milliseconds: 140),
    this.autoSkipDuration = const Duration(milliseconds: 800),
  }) : _random = random ?? Random() {
    initGame(playerCount: playerCount, customColors: customColors);
  }

  GameState get state => _state;
  bool get isProcessingAction => _isProcessingAction;

  /// Initializes a new game with the given player count.
  /// 2 players: Red & Yellow (opposites) by default.
  /// 3 players: Red, Green, Yellow.
  /// 4 players: Red, Green, Yellow, Blue.
  void initGame({int playerCount = 4, List<PlayerColor>? customColors}) {
    List<PlayerColor> colors;
    if (customColors != null && customColors.isNotEmpty) {
      colors = customColors;
    } else {
      switch (playerCount) {
        case 2:
          colors = [PlayerColor.red, PlayerColor.yellow];
          break;
        case 3:
          colors = [PlayerColor.red, PlayerColor.green, PlayerColor.yellow];
          break;
        case 4:
        default:
          colors = [
            PlayerColor.red,
            PlayerColor.green,
            PlayerColor.yellow,
            PlayerColor.blue,
          ];
          break;
      }
    }

    final players = colors.map((c) => Player.initial(c)).toList();
    _actionSequence++;
    _isProcessingAction = false;

    _state = GameState(
      players: players,
      currentPlayerIndex: 0,
      diceValue: null,
      phase: TurnPhase.waitingForRoll,
      consecutiveSixes: 0,
      movableTokenIds: const {},
      movingTokenId: null,
      winner: null,
      message: '${players[0].name}\'s turn. Roll the dice!',
      actionSequenceId: _actionSequence,
    );

    notifyListeners();
  }

  @visibleForTesting
  void setStateForTesting(GameState state) {
    _state = state;
    notifyListeners();
  }

  /// Evaluates which tokens of the current player can legally move given [dice].
  Set<int> getLegalMoves(Player player, int dice) {
    final movable = <int>{};
    for (final token in player.tokens) {
      if (token.isHome) continue;

      if (token.isInBase) {
        if (dice == 6) {
          movable.add(token.id);
        }
      } else if (token.isOnTrack) {
        final targetStep = token.stepCount + dice;
        if (targetStep <= BoardPath.totalStepsToHome) {
          movable.add(token.id);
        }
      }
    }
    return movable;
  }

  /// Rolls the dice for the current player.
  /// [forcedValue] can be provided for deterministic unit tests.
  Future<void> rollDice({int? forcedValue}) async {
    if (!_state.canRollDice || _isProcessingAction) return;

    _isProcessingAction = true;
    final currentSeq = ++_actionSequence;

    // Transition to rolling phase
    _state = _state.copyWith(
      phase: TurnPhase.rollingDice,
      clearDiceValue: true,
      movableTokenIds: const {},
      message: '${_state.currentPlayer.name} is rolling...',
      actionSequenceId: currentSeq,
    );
    notifyListeners();

    if (enableDelays && rollDuration > Duration.zero) {
      await Future<void>.delayed(rollDuration);
      if (currentSeq != _actionSequence) return;
    }

    final rolledValue = forcedValue ?? (_random.nextInt(6) + 1);

    // Check consecutive 6s rule
    int nextConsecutiveSixes = _state.consecutiveSixes;
    if (rolledValue == 6) {
      nextConsecutiveSixes++;
    } else {
      nextConsecutiveSixes = 0;
    }

    if (nextConsecutiveSixes >= 3) {
      // Three 6s in a row -> forfeit turn
      _state = _state.copyWith(
        diceValue: rolledValue,
        consecutiveSixes: 0,
        phase: TurnPhase.waitingForRoll,
        message: 'Three 6s rolled in a row! Turn forfeited.',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays && autoSkipDuration > Duration.zero) {
        await Future<void>.delayed(autoSkipDuration);
        if (currentSeq != _actionSequence) return;
      }

      _advanceToNextPlayer();
      _isProcessingAction = false;
      notifyListeners();
      return;
    }

    final legalTokens = getLegalMoves(_state.currentPlayer, rolledValue);

    if (legalTokens.isEmpty) {
      // No legal moves available -> auto skip turn
      _state = _state.copyWith(
        diceValue: rolledValue,
        consecutiveSixes: nextConsecutiveSixes,
        movableTokenIds: const {},
        phase: TurnPhase.waitingForRoll,
        message: 'Rolled a $rolledValue. No legal moves!',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays && autoSkipDuration > Duration.zero) {
        await Future<void>.delayed(autoSkipDuration);
        if (currentSeq != _actionSequence) return;
      }

      _advanceToNextPlayer();
      _isProcessingAction = false;
      notifyListeners();
      return;
    }

    // Waiting for token selection
    _state = _state.copyWith(
      diceValue: rolledValue,
      consecutiveSixes: nextConsecutiveSixes,
      movableTokenIds: legalTokens,
      phase: TurnPhase.waitingForTokenSelection,
      message: 'Rolled a $rolledValue! Select a token to move.',
      actionSequenceId: currentSeq,
    );
    _isProcessingAction = false;
    notifyListeners();
  }

  /// Selects and moves a legally movable token.
  Future<void> selectToken(int tokenId) async {
    if (!_state.canSelectToken || _isProcessingAction) return;
    if (!_state.movableTokenIds.contains(tokenId)) return;

    _isProcessingAction = true;
    final currentSeq = ++_actionSequence;
    final dice = _state.diceValue!;
    final player = _state.currentPlayer;
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    _state = _state.copyWith(
      phase: TurnPhase.animatingMove,
      movingTokenId: tokenId,
      movableTokenIds: const {},
      message: 'Moving token...',
      actionSequenceId: currentSeq,
    );
    notifyListeners();

    if (token.isInBase) {
      // Leaving base on a 6: directly moves to step 0
      final updatedToken = token.copyWith(stepCount: 0);
      _updateTokenInState(player.color, updatedToken);

      if (enableDelays && stepDuration > Duration.zero) {
        await Future<void>.delayed(stepDuration);
        if (currentSeq != _actionSequence) return;
      }
    } else {
      // Step-by-step movement
      final startStep = token.stepCount;
      final targetStep = startStep + dice;

      for (int step = startStep + 1; step <= targetStep; step++) {
        final updatedToken = token.copyWith(stepCount: step);
        _updateTokenInState(player.color, updatedToken);

        if (enableDelays && stepDuration > Duration.zero) {
          await Future<void>.delayed(stepDuration);
          if (currentSeq != _actionSequence) return;
        }
      }
    }

    // Resolve post-movement logic: captures, home entry, extra turns, victory
    await _resolvePostMove(player.color, tokenId, dice, currentSeq);
  }

  void _updateTokenInState(PlayerColor color, Token updatedToken) {
    final updatedPlayers = _state.players.map((p) {
      if (p.color == color) {
        final newTokens = p.tokens.map((t) {
          return t.id == updatedToken.id ? updatedToken : t;
        }).toList();
        return p.copyWith(tokens: newTokens);
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers);
    notifyListeners();
  }

  Future<void> _resolvePostMove(
    PlayerColor playerColor,
    int tokenId,
    int diceRolled,
    int currentSeq,
  ) async {
    final playerIndex =
        _state.players.indexWhere((p) => p.color == playerColor);
    final player = _state.players[playerIndex];
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    bool earnedBonusTurn = false;
    String completionMessage = '';

    // 1. Check if token reached HOME
    if (token.isHome) {
      if (player.allHome) {
        // Player has won the game!
        final winnerPlayer = player.copyWith(hasWon: true, finishRank: 1);
        final updatedPlayers = List<Player>.from(_state.players);
        updatedPlayers[playerIndex] = winnerPlayer;

        _state = _state.copyWith(
          players: updatedPlayers,
          winner: winnerPlayer,
          phase: TurnPhase.gameWon,
          clearMovingToken: true,
          clearDiceValue: true,
          message: '🎉 ${winnerPlayer.name} has won the game! 🎉',
          actionSequenceId: currentSeq,
        );
        _isProcessingAction = false;
        notifyListeners();
        return;
      } else {
        earnedBonusTurn = true;
        completionMessage = 'Token reached HOME! Bonus roll!';
      }
    }

    // 2. Check for captures (only possible on track before home stretch)
    if (token.isOnTrack && !token.isInHomeStretch) {
      final landingCoord = BoardPath.getCoordinate(playerColor, token.stepCount);

      if (!BoardPath.isSafe(landingCoord)) {
        bool capturedAny = false;
        final updatedPlayers = <Player>[];

        for (final otherPlayer in _state.players) {
          if (otherPlayer.color == playerColor) {
            updatedPlayers.add(otherPlayer);
            continue;
          }

          final updatedTokens = <Token>[];
          for (final oppToken in otherPlayer.tokens) {
            if (oppToken.isOnTrack && !oppToken.isInHomeStretch) {
              final oppCoord = BoardPath.getCoordinate(
                otherPlayer.color,
                oppToken.stepCount,
              );
              if (oppCoord == landingCoord) {
                // Captured! Return to base
                capturedAny = true;
                updatedTokens.add(oppToken.copyWith(stepCount: -1));
              } else {
                updatedTokens.add(oppToken);
              }
            } else {
              updatedTokens.add(oppToken);
            }
          }
          updatedPlayers.add(otherPlayer.copyWith(tokens: updatedTokens));
        }

        if (capturedAny) {
          earnedBonusTurn = true;
          completionMessage = 'Captured opponent token! Bonus roll!';
          _state = _state.copyWith(players: updatedPlayers);
          notifyListeners();

          if (enableDelays && stepDuration > Duration.zero) {
            await Future<void>.delayed(stepDuration);
            if (currentSeq != _actionSequence) return;
          }
        }
      }
    }

    // 3. Check for rolling a 6
    if (diceRolled == 6) {
      earnedBonusTurn = true;
      if (completionMessage.isEmpty) {
        completionMessage = 'Rolled a 6! Extra roll!';
      }
    }

    // Transition turn
    if (earnedBonusTurn) {
      _state = _state.copyWith(
        phase: TurnPhase.waitingForRoll,
        clearMovingToken: true,
        clearDiceValue: true,
        message: completionMessage,
        actionSequenceId: currentSeq,
      );
    } else {
      _advanceToNextPlayer(customMessage: completionMessage);
    }

    _isProcessingAction = false;
    notifyListeners();
  }

  void _advanceToNextPlayer({String? customMessage}) {
    int nextIndex = (_state.currentPlayerIndex + 1) % _state.players.length;

    // If next player already won (for multi-rank finishing), skip to active player
    int attempts = 0;
    while (_state.players[nextIndex].hasWon &&
        attempts < _state.players.length) {
      nextIndex = (nextIndex + 1) % _state.players.length;
      attempts++;
    }

    final nextPlayer = _state.players[nextIndex];
    _state = _state.copyWith(
      currentPlayerIndex: nextIndex,
      diceValue: null,
      clearDiceValue: true,
      phase: TurnPhase.waitingForRoll,
      consecutiveSixes: 0,
      movableTokenIds: const {},
      clearMovingToken: true,
      message: customMessage != null && customMessage.isNotEmpty
          ? '$customMessage ${nextPlayer.name}\'s turn.'
          : '${nextPlayer.name}\'s turn. Roll the dice!',
    );
  }

  /// Direct token tap handler from UI.
  /// Strictly checks current player, phase, movable list, and locks against rapid taps.
  void onTokenTap(Token token) {
    if (_isProcessingAction) return;
    if (_state.phase != TurnPhase.waitingForTokenSelection) return;
    if (token.color != _state.currentPlayer.color) return;
    if (!_state.movableTokenIds.contains(token.id)) return;

    selectToken(token.id);
  }
}
