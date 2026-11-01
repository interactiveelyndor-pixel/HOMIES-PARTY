import 'package:classic_ludo/catalog/game_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue keeps the five original games and the new ones, unique ids', () {
    final ids = GameCatalog.all.map((g) => g.id).toList();
    expect(ids,
        ['ludo', 'snl', 'carrom', 'battleship', 'pen_fight', 'connect4', 'wyr']);
    expect(ids.toSet().length, ids.length);
    for (final g in GameCatalog.all) {
      expect(g.minPlayers <= g.maxPlayers, isTrue);
    }
  });
}
