import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/carrom/carrom_board_layout.dart';
import 'package:classic_ludo/carrom/carrom_config.dart';
import 'package:classic_ludo/carrom/carrom_controller.dart';
import 'package:classic_ludo/carrom/carrom_models.dart';
import 'package:classic_ludo/carrom/carrom_physics.dart';
import 'package:classic_ludo/carrom/carrom_vec2.dart';

void main() {
  group('Carrom - Board Configuration & Layout Setup', () {
    test('Initializes exactly 19 coins (9 White, 9 Black, 1 Red Queen)', () {
      final coins = CarromBoardLayout.createInitialCoins();
      expect(coins.length, equals(19));

      final whiteCount = coins.where((c) => c.isWhite).length;
      final blackCount = coins.where((c) => c.isBlack).length;
      final queenCount = coins.where((c) => c.isQueen).length;

      expect(whiteCount, equals(9));
      expect(blackCount, equals(9));
      expect(queenCount, equals(1));
    });

    test('Red Queen is positioned at the exact center (400, 400)', () {
      final coins = CarromBoardLayout.createInitialCoins();
      final queen = coins.firstWhere((c) => c.isQueen);
      expect(queen.position.x, closeTo(400.0, 0.01));
      expect(queen.position.y, closeTo(400.0, 0.01));
    });

    test('Baseline Y values are correctly assigned for Player 1 and Player 2', () {
      expect(CarromPlayerId.player1.baselineY, equals(CarromConfig.player1BaselineY));
      expect(CarromPlayerId.player2.baselineY, equals(CarromConfig.player2BaselineY));
      expect(CarromConfig.player1BaselineY, equals(640.0));
      expect(CarromConfig.player2BaselineY, equals(160.0));
    });

    test('Nearest free spot returns center if unoccupied', () {
      final coins = <CarromCoin>[];
      final spot = CarromBoardLayout.findNearestFreeCenterSpot(coins);
      expect(spot.x, closeTo(400.0, 0.01));
      expect(spot.y, closeTo(400.0, 0.01));
    });

    test('Nearest free spot returns adjacent non-overlapping spot if center is occupied', () {
      final coins = [
        CarromCoin(
          id: 1,
          type: CoinType.queen,
          position: CarromConfig.centerPoint,
        ),
      ];
      final spot = CarromBoardLayout.findNearestFreeCenterSpot(coins);
      expect(spot, isNot(equals(CarromConfig.centerPoint)));
      expect(CarromBoardLayout.isSpotFree(spot, CarromConfig.coinRadius, coins), isTrue);
    });
  });

  group('Carrom - Physics Engine (Collisions, Wall Bounces, Friction, Pockets)', () {
    test('Momentum transfer: Striker hitting stationary coin accelerates the coin', () {
      final striker = CarromCoin(
        id: 999,
        type: CoinType.striker,
        position: const CarromVec2(400.0, 500.0),
        velocity: const CarromVec2(0.0, -400.0),
      );
      final coin = CarromCoin(
        id: 1,
        type: CoinType.white,
        position: const CarromVec2(400.0, 470.0),
        velocity: CarromVec2.zero,
      );

      final pieces = [striker, coin];
      CarromPhysics.stepSimulation(coins: pieces, deltaTime: 1.0 / 60.0);

      // Coin was pushed upward (-y direction)
      expect(coin.velocity.y, lessThan(0.0));
      // Striker slowed down
      expect(striker.velocity.y, greaterThan(-400.0));
    });

    test('Wall bounce reflects velocity with restitution loss', () {
      final coin = CarromCoin(
        id: 1,
        type: CoinType.white,
        position: const CarromVec2(CarromConfig.playableMin + 5.0, 400.0),
        velocity: const CarromVec2(-200.0, 0.0),
      );

      CarromPhysics.stepSimulation(coins: [coin], deltaTime: 1.0 / 60.0);

      // Bounced off left wall to positive X direction with damped speed
      expect(coin.velocity.x, greaterThan(0.0));
      expect(coin.velocity.x, closeTo(200.0 * CarromConfig.wallRestitution, 20.0));
    });

    test('Friction decelerates moving coins to rest', () {
      final coin = CarromCoin(
        id: 1,
        type: CoinType.white,
        position: const CarromVec2(400.0, 400.0),
        velocity: const CarromVec2(100.0, 0.0),
      );

      // Step for 1 second of simulation
      for (var i = 0; i < 60; i++) {
        CarromPhysics.stepSimulation(coins: [coin], deltaTime: 1.0 / 60.0);
      }

      // 100 px/s with frictionDeceleration 260 px/s^2 should come to full stop
      expect(coin.velocity.x, equals(0.0));
      expect(coin.velocity.y, equals(0.0));
    });

    test('Velocity cap prevents tunneling', () {
      final coin = CarromCoin(
        id: 1,
        type: CoinType.white,
        position: const CarromVec2(400.0, 400.0),
        velocity: const CarromVec2(5000.0, 0.0),
      );

      CarromPhysics.stepSimulation(coins: [coin], deltaTime: 1.0 / 240.0);
      expect(coin.velocity.length, lessThanOrEqualTo(CarromConfig.maxVelocity + 1.0));
    });

    test('Pocket detection marks coin as pocketed when entering corner pocket', () {
      final pocket = CarromConfig.pocketCenters.first; // Top-Left pocket
      final coin = CarromCoin(
        id: 1,
        type: CoinType.white,
        position: CarromVec2(pocket.x + 10.0, pocket.y + 10.0),
        velocity: const CarromVec2(-50.0, -50.0),
      );

      final newlyPocketed = CarromPhysics.stepSimulation(
        coins: [coin],
        deltaTime: 1.0 / 60.0,
      );

      expect(newlyPocketed.length, equals(1));
      expect(coin.isPocketed, isTrue);
      expect(coin.velocity, equals(CarromVec2.zero));
    });
  });

  group('Carrom - Striker Positioning & Aiming Controls', () {
    test('Striker slides along current player baseline within legal bounds', () {
      final controller = CarromController();
      expect(controller.state.phase, equals(CarromTurnPhase.positioningStriker));

      // Slide to legal position 350
      controller.setStrikerPosition(350.0);
      expect(controller.state.strikerX, equals(350.0));
      expect(controller.state.striker.position.x, equals(350.0));
      expect(controller.state.striker.position.y, equals(CarromConfig.player1BaselineY));

      // Slide beyond min bound -> clamped to baselineMinX
      controller.setStrikerPosition(100.0);
      expect(controller.state.strikerX, equals(CarromConfig.baselineMinX));

      // Slide beyond max bound -> clamped to baselineMaxX
      controller.setStrikerPosition(900.0);
      expect(controller.state.strikerX, equals(CarromConfig.baselineMaxX));
    });

    test('Striker cannot be placed overlapping an active coin', () {
      final controller = CarromController();
      // Place a coin directly on Player 1's baseline at x = 400
      controller.state.coins.first.position =
          const CarromVec2(400.0, CarromConfig.player1BaselineY);

      controller.setStrikerPosition(400.0);
      // Striker must be nudged to a legal non-overlapping position
      final dist = (controller.state.striker.position - controller.state.coins.first.position).length;
      expect(dist, greaterThanOrEqualTo(CarromConfig.strikerRadius + CarromConfig.coinRadius));
    });

    test('Aim drag sets aim vector and power ratio', () {
      final controller = CarromController();
      final strikerPos = controller.state.striker.position;

      // Pull back by (0, 70) pixels (half max pull)
      controller.startAiming(strikerPos + const Offset(0, 70).toVec2());
      expect(controller.state.phase, equals(CarromTurnPhase.aiming));
      expect(controller.state.aimPower, closeTo(0.5, 0.05));

      // Pull back by (0, 200) pixels -> clamped to max pull (power 1.0)
      controller.updateAim(strikerPos + const Offset(0, 200).toVec2());
      expect(controller.state.aimPower, equals(1.0));
    });

    test('Release shot transfers velocity and enters simulating phase', () {
      final controller = CarromController();
      final strikerPos = controller.state.striker.position;

      // Aim forward by dragging down
      controller.startAiming(strikerPos + const Offset(0, 70).toVec2());
      final shotFired = controller.releaseShot();

      expect(shotFired, isTrue);
      expect(controller.state.phase, equals(CarromTurnPhase.simulating));
      expect(controller.state.striker.velocity.y, lessThan(0.0)); // Shoots upward
    });

    test('Tiny drag cancels aim without shooting', () {
      final controller = CarromController();
      final strikerPos = controller.state.striker.position;

      controller.startAiming(strikerPos + const Offset(0, 5).toVec2());
      final shotFired = controller.releaseShot();

      expect(shotFired, isFalse);
      expect(controller.state.phase, equals(CarromTurnPhase.positioningStriker));
    });
  });

  group('Carrom - Rules & Turn Resolution', () {
    test('Pocketing own coin awards extra turn to same player', () {
      final controller = CarromController();
      // Setup state: Player 1's white coin is in front of top-left pocket
      final pocket = CarromConfig.pocketCenters.first;
      final whiteCoin = controller.state.coins.firstWhere((c) => c.isWhite);
      whiteCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      // Trigger shot and run to completion
      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.player1.pocketedCount, greaterThanOrEqualTo(1));
      // Same player gets another turn
      expect(controller.state.currentTurn, equals(CarromPlayerId.player1));
      expect(controller.state.phase, equals(CarromTurnPhase.positioningStriker));
    });

    test('No coin pocketed passes turn deterministically to opponent', () {
      final controller = CarromController();
      expect(controller.state.currentTurn, equals(CarromPlayerId.player1));

      // Weak shot with no collisions
      controller.startAiming(controller.state.striker.position + const Offset(0, 20).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
      expect(controller.state.phase, equals(CarromTurnPhase.positioningStriker));
      expect(controller.state.striker.position.y, equals(CarromConfig.player2BaselineY));
    });

    test('Player can pocket a black coin regardless of assigned colour and receive points', () {
      final controller = CarromController();
      // Current player: Player 1 (White baseline). Place a Black coin in the pocket
      final pocket = CarromConfig.pocketCenters.first;
      final blackCoin = controller.state.coins.firstWhere((c) => c.isBlack);
      blackCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.player1.blackCoinsPocketed, equals(1));
      expect(controller.state.player1.score, equals(CarromConfig.blackCoinPoints));
      expect(controller.state.currentTurn, equals(CarromPlayerId.player1));
    });

    test('Player can pocket a white coin regardless of assigned colour and receive points', () {
      final controller = CarromController();
      // Current player: Player 2 (Black baseline). Place a White coin in the pocket
      controller.setStateForTesting(
        controller.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );
      final pocket = CarromConfig.pocketCenters.first;
      final whiteCoin = controller.state.coins.firstWhere((c) => c.isWhite);
      whiteCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.player2.whiteCoinsPocketed, equals(1));
      expect(controller.state.player2.score, equals(CarromConfig.whiteCoinPoints));
      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
    });

    test('Striker pocketed is a foul: penalty coin returned to center, turn ends', () {
      final controller = CarromController();
      controller.state.player1.pocketedCount = 2;
      controller.state.coins.firstWhere((c) => c.isWhite).isPocketed = true;

      // Place striker right at pocket
      final pocket = CarromConfig.pocketCenters.last;
      controller.state.striker.position = CarromVec2(pocket.x - 5.0, pocket.y - 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 30).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Penalty applied: 1 coin deducted and returned
      expect(controller.state.player1.pocketedCount, equals(1));
      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
    });

    test('Foul with 0 pocketed coins ends turn without negative score', () {
      final controller = CarromController();
      controller.state.player1.pocketedCount = 0;

      final pocket = CarromConfig.pocketCenters.last;
      controller.state.striker.position = CarromVec2(pocket.x - 5.0, pocket.y - 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 30).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.player1.pocketedCount, equals(0));
      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
    });

    test('Queen pocketed alone enters pendingCover status and awards extra shot', () {
      final controller = CarromController();
      final pocket = CarromConfig.pocketCenters.first;
      final queen = controller.state.coins.firstWhere((c) => c.isQueen);
      queen.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.queenStatus, equals(QueenStatus.pendingCover));
      expect(controller.state.queenPocketedBy, equals(CarromPlayerId.player1));
      expect(controller.state.currentTurn, equals(CarromPlayerId.player1));
    });

    test('Failing to cover Queen on next shot returns Queen to center', () {
      final controller = CarromController();
      // Setup Queen as pending cover by Player 1
      controller.setStateForTesting(
        controller.state.copyWith(
          queenStatus: QueenStatus.pendingCover,
          queenPocketedBy: () => CarromPlayerId.player1,
        ),
      );

      // Player 1 fires a blank shot without pocketing any coin
      controller.startAiming(controller.state.striker.position + const Offset(0, 20).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Queen returns to center
      expect(controller.state.queenStatus, equals(QueenStatus.onBoard));
      expect(controller.state.queenPocketedBy, isNull);
      expect(controller.state.coins.firstWhere((c) => c.isQueen).isPocketed, isFalse);
      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
    });

    test('Pocketing own coin covers pending Queen successfully', () {
      final controller = CarromController();
      final pocket = CarromConfig.pocketCenters.first;
      final whiteCoin = controller.state.coins.firstWhere((c) => c.isWhite);
      whiteCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.setStateForTesting(
        controller.state.copyWith(
          queenStatus: QueenStatus.pendingCover,
          queenPocketedBy: () => CarromPlayerId.player1,
        ),
      );

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.queenStatus, equals(QueenStatus.covered));
      expect(controller.state.player1.hasCoveredQueen, isTrue);
      expect(controller.state.currentTurn, equals(CarromPlayerId.player1));
    });

    test('Finishing one player\'s original colour does not end the game while valid coins remain', () {
      final controller = CarromController();
      final whites = controller.state.coins.where((c) => c.isWhite).toList();
      for (int i = 0; i < 8; i++) {
        whites[i].isPocketed = true;
      }
      controller.state.player1.whiteCoinsPocketed = 8;
      controller.state.player1.hasCoveredQueen = true;

      // 9th white coin placed in pocket
      final pocket = CarromConfig.pocketCenters.first;
      whites[8].position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Black coins remain on board, so game is NOT over! Both players continue having chances.
      expect(controller.state.phase, isNot(equals(CarromTurnPhase.gameOver)));
      expect(controller.state.winner, isNull);
      expect(controller.state.whiteCoinsRemaining, equals(0));
      expect(controller.state.blackCoinsRemaining, greaterThan(0));
    });

    test(
        'Foul: own coin pocketed same shot as striker is credited, not silently lost',
        () {
      // Regression: before the fix, ownCoinsPocketed in the foul branch was
      // never added to player.pocketedCount, so the coin disappeared — board
      // showed isPocketed=true but player count never incremented, making the
      // win check unreachable even when all physical coins were off the board.
      final controller = CarromController();

      // Player 1 has covered the queen and already pocketed 8 white coins.
      controller.state.player1.pocketedCount = 8;
      controller.state.player1.hasCoveredQueen = true;

      // Mark 8 white coins as already pocketed in the coin list.
      final whites = controller.state.coins.where((c) => c.isWhite).toList();
      for (int i = 0; i < 8; i++) {
        whites[i].isPocketed = true;
      }

      // The 9th (last) white coin is near a pocket — will be pocketed this shot.
      final pocket = CarromConfig.pocketCenters.first;
      whites[8].position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      // Striker is also aimed to fall into the same pocket (foul).
      controller.state.striker.position =
          CarromVec2(pocket.x - 8.0, pocket.y - 8.0);

      controller.startAiming(
          controller.state.striker.position + const Offset(0, 30).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // The own coin credit (+1) is applied before the penalty (-1),
      // so net pocketedCount is 8 and the returned penalty coin is on the board.
      expect(controller.state.player1.pocketedCount, greaterThanOrEqualTo(8));

      // The returned penalty coin must be visible on the board (not permanently lost).
      final onBoardWhites =
          controller.state.coins.where((c) => c.isWhite && !c.isPocketed);
      expect(onBoardWhites, isNotEmpty,
          reason: 'Penalty coin must reappear on board after foul return');

      // Foul ends the turn — it passes to Player 2.
      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
    });

    test('Empty board with a clear winner ends game immediately', () {
      final controller = CarromController();
      for (final coin in controller.state.coins) {
        coin.isPocketed = true;
      }
      controller.state.player1.pocketedCount = 6;
      controller.state.player2.pocketedCount = 3;

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.phase, equals(CarromTurnPhase.gameOver));
      expect(controller.state.winner, equals(CarromPlayerId.player1));
      expect(controller.state.statusMessage, contains('Player 1 wins'));
    });

    test('Empty board with a tie ends game immediately with a Draw', () {
      final controller = CarromController();
      for (final coin in controller.state.coins) {
        coin.isPocketed = true;
      }
      // Equal scores: e.g. 40 points each (2 white coins each)
      controller.state.player1.whiteCoinsPocketed = 2;
      controller.state.player1.blackCoinsPocketed = 0;
      controller.state.player2.whiteCoinsPocketed = 2;
      controller.state.player2.blackCoinsPocketed = 0;

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.phase, equals(CarromTurnPhase.gameOver));
      expect(controller.state.winner, isNull);
      expect(controller.state.statusMessage, contains('Draw'));
    });

    test('Empty board with Queen pending covers Queen and ends game immediately', () {
      final controller = CarromController();
      for (final coin in controller.state.coins) {
        coin.isPocketed = true;
      }
      controller.state.player1.pocketedCount = 7;
      controller.state.player2.pocketedCount = 3;
      controller.setStateForTesting(
        controller.state.copyWith(
          queenStatus: QueenStatus.pendingCover,
          queenPocketedBy: () => CarromPlayerId.player1,
        ),
      );

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.phase, equals(CarromTurnPhase.gameOver));
      expect(controller.state.queenStatus, equals(QueenStatus.covered));
      expect(controller.state.player1.hasCoveredQueen, isTrue);
      expect(controller.state.winner, equals(CarromPlayerId.player1));
    });

    test('Foul with coin return, then returned coin pocketed again keeps count correct and invariant holds', () {
      final controller = CarromController();

      // Setup Player 1 with 2 pocketed coins
      controller.state.player1.pocketedCount = 2;
      final whites = controller.state.coins.where((c) => c.isWhite).toList();
      whites[0].isPocketed = true;
      whites[1].isPocketed = true;

      expect(controller.checkBoardInvariants(), isTrue);

      // Shot 1: Striker fouls into pocket
      final pocket = CarromConfig.pocketCenters.first;
      controller.state.striker.position = CarromVec2(pocket.x - 8.0, pocket.y - 8.0);
      controller.startAiming(controller.state.striker.position + const Offset(0, 30).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Penalty: 1 coin returned to center, pocketedCount becomes 1
      expect(controller.state.player1.pocketedCount, equals(1));
      final onBoardWhites = controller.state.coins.where((c) => c.isWhite && !c.isPocketed).toList();
      expect(onBoardWhites.length, equals(8));
      expect(controller.checkBoardInvariants(), isTrue);

      // Look up the returned coin in controller.state.coins by ID
      final returnedCoin = controller.state.coins.firstWhere((c) => c.id == whites[0].id);
      expect(returnedCoin.isPocketed, isFalse);

      // Place the returned coin right at pocket entrance to pocket it again
      returnedCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.setStateForTesting(
        controller.state.copyWith(
          currentTurn: CarromPlayerId.player1,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      // Shot 2: Aim and pocket that returned coin cleanly (no foul)
      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Pocketed count increments back to 2, 7 white coins on board, invariant holds!
      expect(controller.state.player1.pocketedCount, equals(2));
      expect(controller.state.coins.where((c) => c.isWhite && !c.isPocketed).length, equals(7));
      expect(controller.checkBoardInvariants(), isTrue);
    });

    test('Last coin pocketed with an extra shot on an empty board ends game immediately', () {
      final controller = CarromController();

      // Configure Player 2 with higher score (e.g., 7 whites + 1 black + queen = 200 pts)
      // Player 1 has 2 whites + 7 blacks = 110 pts
      controller.state.player2.whiteCoinsPocketed = 7;
      controller.state.player2.blackCoinsPocketed = 1;
      controller.state.player2.hasCoveredQueen = true;

      controller.state.player1.whiteCoinsPocketed = 2;
      controller.state.player1.blackCoinsPocketed = 7;

      // Mark all coins as pocketed except the 9th black coin
      for (final coin in controller.state.coins) {
        coin.isPocketed = true;
      }
      final lastBlack = controller.state.coins.firstWhere((c) => c.isBlack);
      lastBlack.isPocketed = false;
      final pocket = CarromConfig.pocketCenters.first;
      lastBlack.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.setStateForTesting(
        controller.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          queenStatus: QueenStatus.covered,
          queenPocketedBy: () => CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      // Player 2 shoots and pockets the last black coin
      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Must NOT grant an extra shot or wait on an empty board.
      // Must end immediately with gameOver and declare Player 2 the winner.
      expect(controller.state.phase, equals(CarromTurnPhase.gameOver));
      expect(controller.state.winner, equals(CarromPlayerId.player2));
      expect(controller.state.player2.pocketedCount, equals(9));
      expect(controller.state.statusMessage, contains('Player 2 wins'));
      expect(controller.state.statusMessage, isNot(contains('Extra shot')));
    });

    test('Foul when the center is occupied returns penalty coin to adjacent free spot', () {
      final controller = CarromController();

      // Center is occupied by Queen at (400, 400)
      final queen = controller.state.coins.firstWhere((c) => c.isQueen);
      queen.position = CarromConfig.centerPoint;
      queen.isPocketed = false;

      // Player 1 has 2 coins pocketed
      controller.state.player1.pocketedCount = 2;
      final whites = controller.state.coins.where((c) => c.isWhite).toList();
      whites[0].isPocketed = true;
      whites[1].isPocketed = true;

      // Player 1 fouls: striker pocketed
      final pocket = CarromConfig.pocketCenters.first;
      controller.state.striker.position = CarromVec2(pocket.x - 8.0, pocket.y - 8.0);
      controller.startAiming(controller.state.striker.position + const Offset(0, 30).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      // Penalty coin returned: 1 white coin reappears on board in controller.state.coins
      final returnedCoin = controller.state.coins.firstWhere((c) => c.id == whites[0].id);
      expect(returnedCoin.isPocketed, isFalse);

      // Must NOT be placed directly at center (since Queen occupies center)
      expect(returnedCoin.position, isNot(equals(CarromConfig.centerPoint)));

      // Must be safely non-overlapping with the Queen at center
      final distToCenter = returnedCoin.position.distanceTo(CarromConfig.centerPoint);
      expect(distToCenter, greaterThanOrEqualTo(CarromConfig.coinRadius * 2));

      // Player 1 pocketedCount decremented from 2 to 1
      expect(controller.state.player1.pocketedCount, equals(1));
      expect(controller.checkBoardInvariants(), isTrue);
    });

    test('Correct points are credited: Black=10, White=20, Queen=50', () {
      final controller = CarromController();
      expect(controller.state.player1.score, equals(0));

      controller.state.player1.blackCoinsPocketed = 2; // 20
      controller.state.player1.whiteCoinsPocketed = 1; // 20
      controller.state.player1.hasCoveredQueen = true; // 50
      expect(controller.state.player1.score, equals(90));
    });

    test('Queen can be pocketed by either player (e.g. Player 2)', () {
      final controller = CarromController();
      // Set to Player 2's turn
      controller.setStateForTesting(
        controller.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final pocket = CarromConfig.pocketCenters.first;
      final queen = controller.state.coins.firstWhere((c) => c.isQueen);
      queen.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.queenStatus, equals(QueenStatus.pendingCover));
      expect(controller.state.queenPocketedBy, equals(CarromPlayerId.player2));
      expect(controller.state.currentTurn, equals(CarromPlayerId.player2));
    });

    test('Queen cover can be Black coin for Player 1', () {
      final controller = CarromController();
      final pocket = CarromConfig.pocketCenters.first;
      final blackCoin = controller.state.coins.firstWhere((c) => c.isBlack);
      blackCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.setStateForTesting(
        controller.state.copyWith(
          queenStatus: QueenStatus.pendingCover,
          queenPocketedBy: () => CarromPlayerId.player1,
        ),
      );

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.queenStatus, equals(QueenStatus.covered));
      expect(controller.state.player1.hasCoveredQueen, isTrue);
      expect(controller.state.player1.blackCoinsPocketed, equals(1));
      expect(controller.state.player1.score, equals(CarromConfig.blackCoinPoints + CarromConfig.queenPoints));
    });

    test('Queen cover can be White coin for Player 2', () {
      final controller = CarromController();
      controller.setStateForTesting(
        controller.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          queenStatus: QueenStatus.pendingCover,
          queenPocketedBy: () => CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final pocket = CarromConfig.pocketCenters.first;
      final whiteCoin = controller.state.coins.firstWhere((c) => c.isWhite);
      whiteCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.queenStatus, equals(QueenStatus.covered));
      expect(controller.state.player2.hasCoveredQueen, isTrue);
      expect(controller.state.player2.whiteCoinsPocketed, equals(1));
      expect(controller.state.player2.score, equals(CarromConfig.whiteCoinPoints + CarromConfig.queenPoints));
    });

    test('A player with fewer coins can still win with a higher score', () {
      final controller = CarromController();
      for (final coin in controller.state.coins) {
        coin.isPocketed = true;
      }

      // Player A: 3 white coins (60) + Queen (50) = 110 points (3 coins total)
      controller.state.player1.whiteCoinsPocketed = 3;
      controller.state.player1.blackCoinsPocketed = 0;
      controller.state.player1.hasCoveredQueen = true;

      // Player B: 10 black coins = 100 points (10 coins total)
      controller.state.player2.whiteCoinsPocketed = 0;
      controller.state.player2.blackCoinsPocketed = 10;
      controller.state.player2.hasCoveredQueen = false;

      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();
      controller.simulateToEndForTesting();

      expect(controller.state.phase, equals(CarromTurnPhase.gameOver));
      expect(controller.state.winner, equals(CarromPlayerId.player1));
      expect(controller.state.player1.score, equals(110));
      expect(controller.state.player2.score, equals(100));
      expect(controller.state.player1.pocketedCount, lessThan(controller.state.player2.pocketedCount));
    });
  });

  group('Carrom - Input Protection & Reliability', () {
    test('Input is blocked during simulation phase', () {
      final controller = CarromController();
      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();

      expect(controller.state.phase, equals(CarromTurnPhase.simulating));

      // Attempt to slide striker while simulating
      controller.setStrikerPosition(300.0);
      expect(controller.state.strikerX, isNot(equals(300.0)));

      // Attempt second release
      final secondRelease = controller.releaseShot();
      expect(secondRelease, isFalse);
    });

    test('Motion phase completes after maximum simulation time (6.0s)', () {
      final controller = CarromController();
      controller.startAiming(controller.state.striker.position + const Offset(0, 50).toVec2());
      controller.releaseShot();

      // Tick 7 seconds (exceeding 6.0s timeout)
      controller.tick(7.0);

      // Must have resolved shot and returned to positioning phase
      expect(controller.state.phase, equals(CarromTurnPhase.positioningStriker));
    });
  });
}

extension on Offset {
  CarromVec2 toVec2() => CarromVec2(dx, dy);
}
