import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends ApiClient {
  final calls = <String>[];
  bool failDelete = false;

  @override
  Future<UserProfile> authenticateGuest() async => _me;
  @override
  Future<UserProfile> getProfile() async => _me;
  @override
  Future<UserProfile> updateProfile({String? nickname, String? avatar}) async {
    calls.add('rename:$nickname');
    return _me;
  }

  @override
  Future<void> deleteAccount() async {
    if (failDelete) {
      throw const ApiException(statusCode: 500, error: 'x', message: 'nope');
    }
    calls.add('delete');
  }
}

final _me =
    UserProfile(id: 'me', nickname: 'Guest1234', createdAt: DateTime(2026));

Future<void> _pump(WidgetTester t, FakeApi api, VoidCallback onOut) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
  await t.pumpWidget(
      MaterialApp(home: AccountScreen(api: api, onSignedOut: onOut)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows the name, validates and saves a new one', (t) async {
    final api = FakeApi();
    await _pump(t, api, () {});
    expect(find.widgetWithText(TextField, 'Guest1234'), findsOneWidget);

    await t.enterText(find.byKey(const Key('account_name')), 'A');
    await t.tap(find.byKey(const Key('account_save')));
    await t.pump();
    expect(api.calls, isEmpty, reason: 'too short, not sent');

    await t.enterText(find.byKey(const Key('account_name')), 'Neo');
    await t.tap(find.byKey(const Key('account_save')));
    await t.pumpAndSettle();
    expect(api.calls, ['rename:Neo']);
  });

  testWidgets('delete needs confirmation, then signs out', (t) async {
    final api = FakeApi();
    var signedOut = false;
    await _pump(t, api, () => signedOut = true);
    await t.drag(find.byType(ListView), const Offset(0, -900)); // the button is below the avatar picker
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('account_delete')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(signedOut, isFalse);

    await t.drag(find.byType(ListView), const Offset(0, -900)); // the button is below the avatar picker
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('account_delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm_delete_account')));
    await t.pumpAndSettle();
    expect(api.calls, ['delete']);
    expect(signedOut, isTrue);
  });

  testWidgets('a failed deletion keeps the session', (t) async {
    final api = FakeApi()..failDelete = true;
    var signedOut = false;
    await _pump(t, api, () => signedOut = true);
    await t.drag(find.byType(ListView), const Offset(0, -900)); // the button is below the avatar picker
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('account_delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm_delete_account')));
    await t.pumpAndSettle();
    expect(signedOut, isFalse);
    expect(find.byKey(const Key('account_delete')), findsOneWidget);
  });
}
