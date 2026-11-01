import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/account_screen.dart';
import 'package:classic_ludo/screens/app_shell.dart';
import 'package:classic_ludo/screens/consent_sheet.dart';
import 'package:classic_ludo/screens/online_reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

class FakeApi extends ApiClient {
  Eligibility eligibility = const Eligibility(
    consented: false,
    ageBand: null,
    online: false,
    social: false,
    policyVersion: '1',
  );
  final accepted = <String>[];
  bool offline = false;

  @override
  Future<UserProfile> authenticateGuest() async => _me;
  @override
  Future<UserProfile> getProfile() async => _me;

  @override
  Future<Eligibility> getEligibility() async {
    if (offline) {
      throw const ApiException(statusCode: 503, error: 'x', message: 'offline');
    }
    return eligibility;
  }

  @override
  Future<Eligibility> acceptConsent(String v, String band) async {
    accepted.add('$v:$band');
    eligibility = Eligibility(
      consented: true,
      ageBand: band,
      online: true,
      social: band != 'under13',
      policyVersion: v,
    );
    return eligibility;
  }

  @override
  Future<Progress> getProgress() async => const Progress(
    xp: 70,
    level: 2,
    levelStartXp: 50,
    nextLevelXp: 200,
    played: 3,
    wins: 1,
  );

  @override
  Future<Map<String, dynamic>> exportMyData() async => {
    'profile': {'id': 'me'},
  };
}

final _me = UserProfile(
  id: 'me',
  nickname: 'Guest1234',
  createdAt: DateTime(2026),
);

Map<String, dynamic> _state({int version = 4}) => {
  'players': [
    {'userId': 'me'},
    {'userId': 'you'},
  ],
  'turn': 0,
  'winnerId': null,
  'draw': false,
  'version': version,
  'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
};

Room _room(Map<String, dynamic> state) => Room.fromJson({
  'id': 'r',
  'code': 'ABC234',
  'hostUserId': 'me',
  'status': 'playing',
  'maxPlayers': 2,
  'gameType': 'connect4',
  'gameState': state,
  'players': [
    {'userId': 'me', 'nickname': 'Me'},
    {'userId': 'you', 'nickname': 'You'},
  ],
});

/// A button that calls [ensureConsent] and records the answer.
Widget _host(FakeApi api, List<bool> results) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        key: const Key('go'),
        onPressed: () async => results.add(await ensureConsent(context, api)),
        child: const Text('go'),
      ),
    ),
  ),
);

void main() {
  group('consent and age range', () {
    testWidgets('asks once, saves the answer, then lets the player through', (
      t,
    ) async {
      final api = FakeApi();
      final results = <bool>[];
      await t.pumpWidget(_host(api, results));
      await t.tap(find.byKey(const Key('go')));
      await t.pumpAndSettle();

      expect(find.text('Before you play online'), findsOneWidget);
      expect(find.text('Community rules'), findsOneWidget);
      // Cannot agree before choosing an age range.
      final agree = find.byKey(const Key('consent_accept'));
      expect(t.widget<FilledButton>(agree).onPressed, isNull);

      await t.ensureVisible(find.byKey(const Key('age_13_17'))); // the sheet scrolls
      await t.pump();
      await t.tap(find.byKey(const Key('age_13_17')));
      await t.pump();
      await t.ensureVisible(agree);
      await t.pump();
      await t.tap(agree);
      await t.pumpAndSettle();
      expect(api.accepted, ['1:13_17']);
      expect(results, [true]);

      // Second time: already accepted, no sheet.
      await t.tap(find.byKey(const Key('go')));
      await t.pumpAndSettle();
      expect(find.text('Before you play online'), findsNothing);
      expect(results, [true, true]);
    });

    testWidgets('dismissing the sheet means no online play', (t) async {
      final api = FakeApi();
      final results = <bool>[];
      await t.pumpWidget(_host(api, results));
      await t.tap(find.byKey(const Key('go')));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(10, 10)); // outside the sheet
      await t.pumpAndSettle();
      expect(results, [false]);
      expect(api.accepted, isEmpty);
    });

    testWidgets('offline: does not block, the server decides', (t) async {
      final api = FakeApi()..offline = true;
      final results = <bool>[];
      await t.pumpWidget(_host(api, results));
      await t.tap(find.byKey(const Key('go')));
      await t.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('Before you play online'), findsNothing);
    });
  });

  group('Quick Match switch', () {
    Future<void> pumpPlay(WidgetTester t, bool on) async {
      await t.pumpWidget(
        MaterialApp(
          home: PlayScreen(
            onBrowseGames: () {},
            api: FakeApi(),
            loadConfig: () async => AppConfig(
              policyVersion: '1',
              minClientVersion: '0.0.0',
              publicDiscovery: on,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, -500)); // below the party card
      await t.pumpAndSettle();
    }

    testWidgets('is switched off: tile is disabled and says so', (t) async {
      await pumpPlay(t, false);
      expect(find.textContaining('Not available right now'), findsOneWidget);
      final tile = t.widget<ListTile>(
        find.descendant(
          of: find.byKey(const Key('play_match')),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.onTap, isNull);
      expect(tile.enabled, isFalse);
    });

    testWidgets('is switched on: tile works', (t) async {
      await pumpPlay(t, true);
      expect(find.textContaining('Not available right now'), findsNothing);
      final tile = t.widget<ListTile>(
        find.descendant(
          of: find.byKey(const Key('play_match')),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.onTap, isNotNull);
    });
  });

  group('stale-action protection', () {
    test('rolls and moves carry the revision the player was looking at', () async {
      final s = FakeSocket();
      final g = OnlineGameSession(
        room: _room(_state(version: 4)),
        myUserId: 'me',
        socket: s,
      );
      await g.act({'column': 3});
      expect(s.revisions, [4]);
      s.stateCtl.add({'code': 'ABC234', 'state': _state(version: 6)});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await g.act();
      expect(s.revisions, [4, 6]);
      g.dispose();
    });

    test('a revision conflict resyncs instead of leaving a stale board', () async {
      final s = FakeSocket()
        ..actionError = const ApiException(
          statusCode: 409,
          error: 'Conflict',
          message: 'The game moved on. Refreshing.',
          code: 'REVISION_CONFLICT',
        )
        ..subscribeResult = _room(_state(version: 9));
      final g = OnlineGameSession(
        room: _room(_state(version: 4)),
        myUserId: 'me',
        socket: s,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.calls.clear();
      await g.act({'column': 1});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(s.calls, contains('subscribe:ABC234'));
      expect(g.version, 9, reason: 'fresh state was fetched');
      g.dispose();
    });
  });

  group('quick phrases and reaction targets', () {
    testWidgets('phrases send fixed text; emoji targets are at least 48dp', (
      t,
    ) async {
      final s = FakeSocket();
      final g = OnlineGameSession(
        room: _room(_state()),
        myUserId: 'me',
        socket: s,
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OnlineReactions(session: g)),
        ),
      );
      for (final e in gameReactions) {
        final size = t.getSize(find.byKey(Key('react_$e')));
        expect(size.width, greaterThanOrEqualTo(48), reason: e);
        expect(size.height, greaterThanOrEqualTo(48), reason: e);
      }
      await t.tap(find.byKey(const Key('phrase_Good luck!')));
      await t.pump(const Duration(milliseconds: 600));
      expect(s.calls, contains('react:Good luck!'));
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'no free-text input anywhere',
      );
      g.dispose();
      await t.pump(const Duration(seconds: 4));
    });
  });

  group('account screen', () {
    testWidgets('shows the rules and copies the data export', (t) async {
      t.view.physicalSize = const Size(390 * 2, 1200 * 2);
      t.view.devicePixelRatio = 2.0;
      addTearDown(() => t.view.resetPhysicalSize());
      String? clipboard;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await t.pumpWidget(MaterialApp(home: AccountScreen(api: FakeApi())));
      await t.pumpAndSettle();
      expect(find.text('Community rules'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.textContaining('70 of 200 XP to level 3'), findsOneWidget);
      expect(find.textContaining('1 wins in 3 online games'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('account_export')));
      await t.tap(find.byKey(const Key('account_export')));
      await t.pumpAndSettle();
      expect(clipboard, contains('"id": "me"'));
    });
  });
}
