import 'dart:math';
import 'wyr_prompts.dart';

enum WyrPhase { voting, reveal, finished }

/// Would You Rather, pass-and-play. Pure Dart, no Flutter imports.
///
/// Each round every player secretly picks A or B in turn. On the reveal,
/// players in the majority score a point; a tie scores nobody.
class WyrGame {
  static const defaultRounds = 8;

  final List<String> players;
  final List<WyrPrompt> prompts; // one per round

  int round = 0;
  int voter = 0; // index of the player who votes next
  WyrPhase phase = WyrPhase.voting;
  final List<int?> votes; // this round: 0 = A, 1 = B
  final List<int> scores;

  WyrGame({required this.players, required this.prompts})
      : assert(players.length >= 2 && prompts.isNotEmpty),
        votes = List.filled(players.length, null),
        scores = List.filled(players.length, 0);

  factory WyrGame.random(int playerCount,
      {int rounds = defaultRounds, Random? random}) {
    final deck = [...wyrPrompts]..shuffle(random);
    return WyrGame(
      players: [for (var i = 1; i <= playerCount; i++) 'Player $i'],
      prompts: deck.take(min(rounds, deck.length)).toList(),
    );
  }

  WyrPrompt get prompt => prompts[round];
  int get totalRounds => prompts.length;

  /// How many players picked A and B this round.
  (int, int) get counts =>
      (votes.where((v) => v == 0).length, votes.where((v) => v == 1).length);

  /// 0 or 1 for the winning option this round, or -1 for a tie.
  int get majority {
    final (a, b) = counts;
    return a == b ? -1 : (a > b ? 0 : 1);
  }

  /// Records the current voter's pick. Returns false if voting is closed.
  bool vote(int choice) {
    if (phase != WyrPhase.voting || (choice != 0 && choice != 1)) return false;
    votes[voter] = choice;
    voter++;
    if (voter == players.length) {
      phase = WyrPhase.reveal;
      final m = majority;
      if (m != -1) {
        for (var i = 0; i < players.length; i++) {
          if (votes[i] == m) scores[i]++;
        }
      }
    }
    return true;
  }

  /// Moves from the reveal to the next round, or to the final scores.
  void next() {
    if (phase != WyrPhase.reveal) return;
    round++;
    if (round >= totalRounds) {
      phase = WyrPhase.finished;
      return;
    }
    voter = 0;
    votes.fillRange(0, votes.length, null);
    phase = WyrPhase.voting;
  }

  /// Everyone on the top score (several players on a tie).
  List<String> get winners {
    final top = scores.reduce(max);
    return [
      for (var i = 0; i < players.length; i++)
        if (scores[i] == top) players[i]
    ];
  }
}
