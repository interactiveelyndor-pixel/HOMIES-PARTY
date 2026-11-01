import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/online_bluff_screen.dart';
import 'package:classic_ludo/screens/online_wordrush_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

int _later() => DateTime.now().millisecondsSinceEpoch + 600000;

Map<String, dynamic> base(Map<String, dynamic> extra) => {
  'players': [
    {'userId': 'me'},
    {'userId': 'you'},
    {'userId': 'amy'},
  ],
  'turn': 0,
  'winnerId': null,
  'draw': false,
  'version': 1,
  'turnDeadline': _later(),
  'simultaneous': true,
  'round': 1,
  'rounds': 3,
  'scores': {'me': 0, 'you': 0, 'amy': 0},
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
    {'userId': 'you', 'nickname': 'Zed'},
    {'userId': 'amy', 'nickname': 'Amy'},
  ],
});

class FakeApi extends ApiClient {
  final reports = <String>[];
  @override
  Future<void> reportUser(
    String userId,
    String reason, {
    String? details,
  }) async {
    reports.add('$userId:$reason:$details');
  }
}

void view(WidgetTester t) {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
}

const tick = Duration(milliseconds: 300);

void main() {
  group('Word Rush', () {
    Map<String, dynamic> wr({
      int left = 5,
      Map? last,
      int version = 1,
      int round = 1,
    }) => base({
      'scramble': 'tenalp',
      'round': round,
      'version': version,
      'guessesLeft': {'me': left, 'you': 5, 'amy': 5},
      'last': last,
    });

    Future<FakeSocket> open(WidgetTester t, Map<String, dynamic> state) async {
      view(t);
      final s = FakeSocket();
      await t.pumpWidget(
        MaterialApp(
          home: OnlineWordRushScreen(
            key: UniqueKey(),
            room: room('wordrush', state),
            myUserId: 'me',
            socket: s,
          ),
        ),
      );
      await t.pump(tick);
      return s;
    }

    testWidgets('shows letters and sends a guess without waiting for a turn', (
      t,
    ) async {
      final s = await open(t, wr());
      expect(find.text('Round 1 of 3'), findsOneWidget);
      for (final c in 'TENALP'.split('')) {
        expect(find.text(c), findsWidgets);
      }
      expect(find.text('5 guesses left'), findsOneWidget);

      await t.enterText(find.byKey(const Key('wr_guess')), 'planet');
      await t.tap(find.byKey(const Key('wr_send')));
      await t.pump(tick);
      expect(s.calls.where((c) => c.startsWith('move')).length, 1);
      expect(s.revisions, [1], reason: 'the revision is sent too');
      expect(
        t.widget<TextField>(find.byKey(const Key('wr_guess'))).controller!.text,
        '',
        reason: 'the box is cleared',
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('only letters can be typed; one-letter guesses are not sent', (
      t,
    ) async {
      final s = await open(t, wr());
      await t.enterText(find.byKey(const Key('wr_guess')), 'a1 b!');
      expect(
        t.widget<TextField>(find.byKey(const Key('wr_guess'))).controller!.text,
        'ab',
      );
      await t.enterText(find.byKey(const Key('wr_guess')), 'a');
      await t.tap(find.byKey(const Key('wr_send')));
      await t.pump(tick);
      expect(s.calls.where((c) => c.startsWith('move')), isEmpty);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no guesses left disables input; the last word and result show', (
      t,
    ) async {
      final s = await open(
        t,
        wr(left: 0, last: {'word': 'garden', 'winnerId': 'you'}),
      );
      expect(
        t.widget<TextField>(find.byKey(const Key('wr_guess'))).enabled,
        isFalse,
      );
      expect(
        t.widget<FilledButton>(find.byKey(const Key('wr_send'))).onPressed,
        isNull,
      );
      expect(find.text('Zed got "garden"'), findsOneWidget);

      s.stateCtl.add({
        'code': 'ABC234',
        'state': wr(version: 9, round: 3)
          ..addAll({
            'winnerId': 'you',
            'last': {'word': 'dragon', 'winnerId': 'you'},
          }),
      });
      await t.pump(tick);
      expect(find.text('Zed wins!'), findsOneWidget);
      expect(find.byKey(const Key('wr_guess')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Bluff & Vote', () {
    Map<String, dynamic> bl(
      String phase, {
      List<String> submitted = const [],
      List<String> voted = const [],
      Map<String, dynamic>? reveal,
      int version = 1,
    }) => base({
      'phase': phase,
      'version': version,
      'question': 'What is a group of crows called?',
      'submitted': submitted,
      'voted': voted,
      'options': phase == 'write'
          ? null
          : [
              {'id': 0, 'text': 'A murder'},
              {'id': 1, 'text': 'My fake'},
              {'id': 2, 'text': 'A parliament'},
            ],
      'reveal': reveal,
    });

    testWidgets('write, wait, vote (not for my own), reveal and report', (
      t,
    ) async {
      view(t);
      final s = FakeSocket();
      final api = FakeApi();
      await t.pumpWidget(
        MaterialApp(
          home: OnlineBluffScreen(
            key: UniqueKey(),
            room: room('bluff', bl('write')),
            myUserId: 'me',
            socket: s,
            api: api,
          ),
        ),
      );
      await t.pump(tick);
      expect(find.text('What is a group of crows called?'), findsOneWidget);
      expect(find.text('0 of 3 written'), findsOneWidget);

      await t.enterText(find.byKey(const Key('bluff_answer')), 'My fake');
      await t.tap(find.byKey(const Key('bluff_submit')));
      await t.pump(tick);
      expect(s.calls.where((c) => c.startsWith('move')).length, 1);

      s.stateCtl.add({
        'code': 'ABC234',
        'state': bl('write', submitted: ['me'], version: 2),
      });
      await t.pump(tick);
      expect(find.byKey(const Key('bluff_locked')), findsOneWidget);
      expect(find.byKey(const Key('bluff_answer')), findsNothing);

      s.stateCtl.add({
        'code': 'ABC234',
        'state': bl('vote', submitted: ['me', 'you', 'amy'], version: 3),
      });
      await t.pump(tick);
      expect(
        t.widget<OutlinedButton>(find.byKey(const Key('bluff_option_1'))).onPressed,
        isNull,
        reason: 'my own answer',
      );
      expect(
        t.widget<OutlinedButton>(find.byKey(const Key('bluff_option_0'))).onPressed,
        isNotNull,
      );
      s.calls.clear();
      await t.tap(find.byKey(const Key('bluff_option_0')));
      await t.pump(tick);
      expect(s.calls.where((c) => c.startsWith('move')).length, 1);

      s.stateCtl.add({
        'code': 'ABC234',
        'state': bl(
          'reveal',
          version: 4,
          reveal: {
            'truthId': 0,
            'authors': {
              '0': [],
              '1': ['me'],
              '2': ['you'],
            },
            'votes': {
              '0': ['amy'],
              '1': [],
              '2': ['me'],
            },
            'gained': {'me': 0, 'you': 1, 'amy': 2},
          },
        ),
      });
      await t.pump(tick);
      expect(find.byKey(const Key('bluff_reveal')), findsOneWidget);
      expect(find.text('✅ A murder  (true)'), findsOneWidget);
      expect(find.text('Written by Zed'), findsOneWidget);
      expect(
        find.byKey(const Key('bluff_report_me')),
        findsNothing,
        reason: 'you cannot report yourself',
      );
      await t.tap(find.byKey(const Key('bluff_report_you')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('report_spam')));
      await t.pumpAndSettle();
      expect(api.reports, ['you:spam:Bluff answer: "A parliament"']);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('game over names the winner', (t) async {
      view(t);
      await t.pumpWidget(
        MaterialApp(
          home: OnlineBluffScreen(
            key: UniqueKey(),
            room: room('bluff', bl('reveal', reveal: {})..addAll({'winnerId': 'me'})),
            myUserId: 'me',
            socket: FakeSocket(),
            api: FakeApi(),
          ),
        ),
      );
      await t.pump(tick);
      expect(find.text('You win!'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });
}
