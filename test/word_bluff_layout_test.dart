import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/online_bluff_screen.dart';
import 'package:classic_ludo/screens/online_wordrush_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

Map<String, dynamic> base(Map<String, dynamic> extra) => {
  'players': [
    {'userId': 'me'},
    {'userId': 'you'},
    {'userId': 'amy'},
    {'userId': 'bob'},
  ],
  'turn': 0,
  'winnerId': null,
  'draw': false,
  'version': 1,
  'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
  'simultaneous': true,
  'round': 1,
  'rounds': 5,
  'scores': {'me': 12, 'you': 9, 'amy': 6, 'bob': 3},
  ...extra,
};

Room room(String type, Map<String, dynamic> state) => Room.fromJson({
  'id': 'r',
  'code': 'ABC234',
  'hostUserId': 'me',
  'status': 'playing',
  'maxPlayers': 4,
  'gameType': type,
  'gameState': state,
  'players': [
    {'userId': 'me', 'nickname': 'Me'},
    {'userId': 'you', 'nickname': 'Zed the Magnificent'},
    {'userId': 'amy', 'nickname': 'Amy-Lou Longname'},
    {'userId': 'bob', 'nickname': 'Bob'},
  ],
});

Future<void> pumpSmall(WidgetTester t, Widget screen) async {
  t.view.physicalSize = const Size(360 * 2, 640 * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: screen,
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Word Rush: no overflow on 360x640 at 1.4x text', (t) async {
    await pumpSmall(
      t,
      OnlineWordRushScreen(
        key: UniqueKey(),
        room: room(
          'wordrush',
          base({
            'scramble': 'ctopuso',
            'guessesLeft': {'me': 5, 'you': 5, 'amy': 5, 'bob': 5},
            'last': {'word': 'giraffe', 'winnerId': 'you'},
          }),
        ),
        myUserId: 'me',
        socket: FakeSocket(),
      ),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  for (final phase in ['write', 'vote', 'reveal']) {
    testWidgets('Bluff $phase: no overflow on 360x640 at 1.4x text', (t) async {
      final options = [
        for (var i = 0; i < 4; i++) {'id': i, 'text': 'A fairly long believable answer $i'},
      ];
      await pumpSmall(
        t,
        OnlineBluffScreen(
          key: UniqueKey(),
          room: room(
            'bluff',
            base({
              'phase': phase,
              'question': 'Which city hosted the first modern Olympic Games in 1896?',
              'submitted': ['you'],
              'voted': ['you'],
              'options': phase == 'write' ? null : options,
              'reveal': phase == 'reveal'
                  ? {
                      'truthId': 0,
                      'authors': {
                        '0': [],
                        '1': ['you'],
                        '2': ['amy'],
                        '3': ['bob'],
                      },
                      'votes': {
                        '0': ['me'],
                        '1': ['amy', 'bob'],
                        '2': [],
                        '3': ['you'],
                      },
                      'gained': {'me': 2, 'you': 3, 'amy': 0, 'bob': 1},
                    }
                  : null,
            }),
          ),
          myUserId: 'me',
          socket: FakeSocket(),
          api: ApiClient(),
        ),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
