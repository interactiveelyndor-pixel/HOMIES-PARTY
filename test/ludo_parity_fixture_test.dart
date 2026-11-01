// Records games from the offline Ludo controller so the server port
// (server/src/games/ludo.ts) can be checked against it move by move.
//
// Regenerate with:  GEN_LUDO_FIXTURE=1 flutter test test/ludo_parity_fixture_test.dart
// It writes server/scripts/fixtures/ludo_parity.json. Without the variable the
// test only checks that the committed fixture is present and sane.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:classic_ludo/logic/ludo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const fixturePath = 'server/scripts/fixtures/ludo_parity.json';

Future<Map<String, dynamic>> recordGame(int players, int seed) async {
  final dice = Random(seed);
  final c = LudoController(
    playerCount: players,
    enableDelays: false,
    random: Random(0),
  );
  final rolls = <int>[];
  final steps = <Map<String, dynamic>>[];
  // Weight 6s a little higher so games reach captures, homes and wins.
  int nextRoll() => dice.nextInt(8) >= 6 ? 6 : dice.nextInt(6) + 1;

  while (!c.state.isGameOver && rolls.length < 6000) {
    final roll = nextRoll();
    rolls.add(roll);
    await c.rollDice(forcedValue: roll);
    if (c.state.movableTokenIds.isNotEmpty) {
      // Same policy the server replay uses: the lowest token id.
      final pick = (c.state.movableTokenIds.toList()..sort()).first;
      await c.selectToken(pick);
    }
    steps.add({
      'turn': c.state.currentPlayerIndex,
      'tokens': [
        for (final p in c.state.players) [for (final t in p.tokens) t.stepCount]
      ],
      'winner': c.state.winner == null
          ? null
          : c.state.players.indexWhere((p) => p.color == c.state.winner!.color),
    });
  }
  return {'players': players, 'rolls': rolls, 'steps': steps};
}

void main() {
  test('generate the Ludo parity fixture (only with GEN_LUDO_FIXTURE=1)',
      () async {
    final games = <Map<String, dynamic>>[];
    for (final players in [2, 3, 4]) {
      for (var seed = 1; seed <= 12; seed++) {
        games.add(await recordGame(players, players * 100 + seed));
      }
    }
    File(fixturePath).writeAsStringSync(jsonEncode({'games': games}));
    final wins = games.where((g) => (g['steps'] as List).last['winner'] != null).length;
    // ignore: avoid_print
    print('wrote ${games.length} games ($wins finished) to $fixturePath');
  }, skip: Platform.environment['GEN_LUDO_FIXTURE'] == null
      ? 'set GEN_LUDO_FIXTURE=1 to regenerate'
      : false);

  test('the committed Ludo parity fixture is present and covers captures',
      () {
    final f = File(fixturePath);
    expect(f.existsSync(), isTrue, reason: 'run the generator once');
    final games = (jsonDecode(f.readAsStringSync())['games'] as List);
    expect(games.length, greaterThanOrEqualTo(30));
    expect({for (final g in games) g['players']}, {2, 3, 4});
    expect(games.where((g) => (g['steps'] as List).last['winner'] != null).length,
        greaterThan(10));
  });
}
