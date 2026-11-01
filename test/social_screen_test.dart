import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/social_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends ApiClient {
  bool fail = false;
  final calls = <String>[];
  List<SocialPlayer> friends = [];
  List<SocialPlayer> recent = [];
  List<SocialPlayer> blocked = [];
  FriendRequests requests = const FriendRequests();

  void _check() {
    if (fail) {
      throw const ApiException(
          statusCode: 500, error: 'x', message: 'Server exploded');
    }
  }

  @override
  Future<UserProfile> authenticateGuest() async {
    _check();
    return UserProfile(id: 'me', nickname: 'Me', createdAt: DateTime(2026));
  }

  @override
  Future<List<SocialPlayer>> getFriends() async => friends;
  @override
  Future<List<SocialPlayer>> getRecentPlayers() async => recent;
  @override
  Future<List<SocialPlayer>> getBlocked() async => blocked;
  @override
  Future<FriendRequests> getFriendRequests() async => requests;

  @override
  Future<String> sendFriendRequest(String userId) async {
    calls.add('request:$userId');
    return 'pending';
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async =>
      calls.add('accept:$requestId');
  @override
  Future<void> blockUser(String userId) async => calls.add('block:$userId');
  @override
  Future<void> unblockUser(String userId) async =>
      calls.add('unblock:$userId');
  @override
  Future<void> reportUser(String userId, String reason,
          {String? details}) async =>
      calls.add('report:$userId:$reason');
}

Future<void> _pump(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SocialScreen(api: api))));
  await tester.pumpAndSettle();
}

const bob = SocialPlayer(userId: 'bob', nickname: 'Bob');

void main() {
  testWidgets('shows an honest error and retries when the server fails',
      (tester) async {
    final api = FakeApi()..fail = true;
    await _pump(tester, api);
    expect(find.byKey(const Key('social_error')), findsOneWidget);
    expect(find.text('Server exploded'), findsOneWidget);

    api.fail = false;
    await tester.tap(find.byKey(const Key('social_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('social_error')), findsNothing);
    expect(find.text('No friends yet. Add players you meet in the Recent tab.'),
        findsOneWidget);
  });

  testWidgets('recent player: add friend sends a request', (tester) async {
    final api = FakeApi()..recent = [bob];
    await _pump(tester, api);
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu_bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    expect(api.calls, ['request:bob']);
  });

  testWidgets('recent player: block asks for confirmation first',
      (tester) async {
    final api = FakeApi()..recent = [bob];
    await _pump(tester, api);
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty, reason: 'nothing happens before confirming');
    await tester.tap(find.byKey(const Key('confirm_block')));
    await tester.pumpAndSettle();
    expect(api.calls, ['block:bob']);
  });

  testWidgets('report sends the chosen reason', (tester) async {
    final api = FakeApi()..recent = [bob];
    await _pump(tester, api);
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam'));
    await tester.tap(find.byKey(const Key('confirm_report')));
    await tester.pumpAndSettle();
    expect(api.calls, ['report:bob:spam']);
  });

  testWidgets('incoming request can be accepted', (tester) async {
    final api = FakeApi()
      ..requests = const FriendRequests(incoming: [
        SocialPlayer(
            userId: 'bob',
            nickname: 'Bob',
            relation: 'pending_in',
            requestId: 'req1')
      ]);
    await _pump(tester, api);
    expect(find.text('Requests (1)'), findsOneWidget);
    await tester.tap(find.text('Requests (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept_bob')));
    await tester.pumpAndSettle();
    expect(api.calls, ['accept:req1']);
  });

  testWidgets('blocked tab can unblock', (tester) async {
    final api = FakeApi()..blocked = [bob];
    await _pump(tester, api);
    await tester.tap(find.text('Blocked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(api.calls, ['unblock:bob']);
  });

  testWidgets('tabs fit on a 360px phone at 1.4x text without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final api = FakeApi()
      ..requests = const FriendRequests(incoming: [
        SocialPlayer(userId: 'b', nickname: 'Bob', requestId: 'r')
      ]);
    await tester.pumpWidget(MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: Scaffold(body: SocialScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Blocked'), findsOneWidget);
  });

  test('SocialPlayer parses server rows and tolerates junk', () {
    final p = SocialPlayer.fromJson(
        {'userId': 'u', 'nickname': 'N', 'relation': 'friend', 'requestId': 'r'});
    expect([p.userId, p.relation, p.requestId], ['u', 'friend', 'r']);
    expect(SocialPlayer.listFrom(null), isEmpty);
    expect(SocialPlayer.listFrom([1, 'x', {'userId': 'a'}]).length, 1);
  });
}
