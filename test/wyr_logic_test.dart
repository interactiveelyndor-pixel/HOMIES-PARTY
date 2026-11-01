import 'dart:math';
import 'package:classic_ludo/would_you_rather/wyr_logic.dart';
import 'package:classic_ludo/would_you_rather/wyr_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

WyrGame game(int players, {int rounds = 2}) => WyrGame(
      players: [for (var i = 1; i <= players; i++) 'P$i'],
      prompts: wyrPrompts.take(rounds).toList(),
    );

void main() {
  test('prompts are well formed and unique', () {
    expect(wyrPrompts.length, greaterThanOrEqualTo(30));
    final seen = <String>{};
    for (final p in wyrPrompts) {
      expect(p.a.isNotEmpty && p.b.isNotEmpty, isTrue);
      expect(p.a, isNot(p.b));
      expect(seen.add('${p.a}|${p.b}'), isTrue, reason: 'duplicate: ${p.a}');
    }
  });

  test('players vote in turn, then the round is revealed', () {
    final g = game(3);
    expect(g.phase, WyrPhase.voting);
    g.vote(0);
    expect(g.voter, 1);
    g.vote(0);
    expect(g.phase, WyrPhase.voting);
    g.vote(1);
    expect(g.phase, WyrPhase.reveal);
    expect(g.counts, (2, 1));
    expect(g.majority, 0);
  });

  test('majority scores a point, the minority does not', () {
    final g = game(3)..vote(0)..vote(0)..vote(1);
    expect(g.scores, [1, 1, 0]);
  });

  test('a tie scores nobody', () {
    final g = game(4)..vote(0)..vote(1)..vote(0)..vote(1);
    expect(g.majority, -1);
    expect(g.scores, [0, 0, 0, 0]);
  });

  test('votes are ignored outside the voting phase or when invalid', () {
    final g = game(2);
    expect(g.vote(2), isFalse);
    expect(g.vote(-1), isFalse);
    g..vote(0)..vote(0);
    expect(g.vote(1), isFalse, reason: 'reveal phase');
    expect(g.scores, [1, 1]);
  });

  test('next() resets votes, advances rounds, then finishes', () {
    final g = game(2, rounds: 2)..vote(0)..vote(0);
    g.next();
    expect(g.round, 1);
    expect(g.phase, WyrPhase.voting);
    expect(g.votes, [null, null]);
    expect(g.voter, 0);
    g..vote(1)..vote(0);
    g.next();
    expect(g.phase, WyrPhase.finished);
    g.next(); // harmless
    expect(g.phase, WyrPhase.finished);
  });

  test('next() does nothing while players are still voting', () {
    final g = game(2)..vote(0);
    g.next();
    expect(g.round, 0);
    expect(g.phase, WyrPhase.voting);
  });

  test('winners lists everyone on the top score', () {
    final g = game(3, rounds: 2)..vote(0)..vote(0)..vote(1);
    g.next();
    g..vote(0)..vote(1)..vote(1); // P1 is in the minority this time
    expect(g.scores, [1, 2, 1]);
    expect(g.winners, ['P2']);
    final tie = game(2, rounds: 1)..vote(0)..vote(0);
    expect(tie.winners, ['P1', 'P2']);
  });

  test('random games use distinct prompts', () {
    final g = WyrGame.random(4, random: Random(3));
    expect(g.players.length, 4);
    expect(g.prompts.length, WyrGame.defaultRounds);
    expect({for (final p in g.prompts) p.a}.length, g.prompts.length);
  });
}
