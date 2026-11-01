import 'package:classic_ludo/main.dart';
import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/profile/local_profile.dart';
import 'package:classic_ludo/screens/app_shell.dart';
import 'package:classic_ludo/screens/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalProfileStore> freshStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return LocalProfileStore.open();
}

void view(WidgetTester t, {double w = 390, double h = 844}) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
}

const tick = Duration(milliseconds: 400);

class FakeApi extends ApiClient {
  final sent = <String>[];
  bool fail = false;
  @override
  Future<UserProfile> updateProfile({String? nickname, String? avatar}) async {
    if (fail) throw const ApiException(statusCode: 503, error: 'x', message: 'offline');
    sent.add('$nickname/$avatar');
    return UserProfile(id: 'me', nickname: nickname ?? '', avatar: avatar, createdAt: DateTime(2026));
  }
}

void main() {
  group('LocalProfileStore', () {
    test('starts empty, remembers a saved profile, and can forget it', () async {
      final store = await freshStore();
      expect(store.profile.onboarded, isFalse);
      await store.saveProfile(nickname: 'Alex', avatar: 'fox');
      final p = store.profile;
      expect([p.onboarded, p.nickname, p.avatar, p.synced], [true, 'Alex', 'fox', false]);
      await store.markSynced();
      expect(store.profile.synced, isTrue);
      await store.saveProfile(nickname: 'Sam', avatar: 'robot');
      expect(store.profile.synced, isFalse, reason: 'a new choice has to be sent again');
      await store.clear();
      expect(store.profile.onboarded, isFalse);
      expect(store.profile.nickname, isNull);
    });

    test('avatar ids map to presets, unknown ids to nothing', () {
      expect(avatarPresetOf('fox')?.emoji, '🦊');
      expect(avatarPresetOf('nope'), isNull);
      expect(avatarPresetOf(null), isNull);
      expect(avatarPresets.map((a) => a.id).toSet().length, avatarPresets.length);
      for (final a in avatarPresets) {
        expect(a.id.length, lessThanOrEqualTo(30), reason: 'the server limit');
      }
    });
  });

  group('syncLocalProfile', () {
    test('sends the choice once, then stops', () async {
      final store = await freshStore();
      LocalProfileStore.current = store;
      addTearDown(() => LocalProfileStore.current = null);
      final api = FakeApi();
      expect(await syncLocalProfile(api), isFalse, reason: 'nothing chosen yet');
      await store.saveProfile(nickname: 'Alex', avatar: 'fox');
      expect(await syncLocalProfile(api), isTrue);
      expect(api.sent, ['Alex/fox']);
      expect(await syncLocalProfile(api), isFalse);
      expect(api.sent.length, 1);
    });

    test('an offline failure keeps it for next time', () async {
      final store = await freshStore();
      LocalProfileStore.current = store;
      addTearDown(() => LocalProfileStore.current = null);
      await store.saveProfile(nickname: 'Alex', avatar: 'fox');
      final api = FakeApi()..fail = true;
      expect(await syncLocalProfile(api), isFalse);
      expect(store.profile.synced, isFalse);
      api.fail = false;
      expect(await syncLocalProfile(api), isTrue);
    });
  });

  group('OnboardingFlow', () {
    Future<(LocalProfileStore, List<int>)> open(WidgetTester t) async {
      view(t);
      final store = await freshStore();
      final done = <int>[];
      await t.pumpWidget(MaterialApp(
        home: OnboardingFlow(store: store, onDone: () => done.add(1), splashDuration: const Duration(milliseconds: 200)),
      ));
      return (store, done);
    }

    testWidgets('splash, three pages, then a profile that needs a valid name', (t) async {
      final (store, done) = await open(t);
      expect(find.byKey(const Key('onboarding_splash')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('onboarding_pages')), findsOneWidget);
      expect(find.text('Find a game'), findsOneWidget);

      await t.tap(find.byKey(const Key('onboarding_next')));
      await t.pumpAndSettle();
      expect(find.text('Play with your people'), findsOneWidget);
      await t.tap(find.byKey(const Key('onboarding_next')));
      await t.pumpAndSettle();
      expect(find.text('Play safe'), findsOneWidget);
      expect(find.text('Let\'s go'), findsOneWidget);
      await t.tap(find.byKey(const Key('onboarding_next')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_profile')), findsOneWidget);
      FilledButton save() => t.widget<FilledButton>(find.byKey(const Key('onboarding_save')));
      expect(save().onPressed, isNull, reason: 'a name is required');
      await t.enterText(find.byKey(const Key('onboarding_name')), 'A');
      await t.pump();
      expect(save().onPressed, isNull, reason: 'too short');
      await t.enterText(find.byKey(const Key('onboarding_name')), '  Alex  ');
      await t.pump();
      expect(save().onPressed, isNotNull);

      await t.tap(find.byKey(const Key('avatar_panda')));
      await t.pump();
      await t.tap(find.byKey(const Key('onboarding_save')));
      await t.pumpAndSettle();
      expect(done, [1]);
      final p = store.profile;
      expect([p.onboarded, p.nickname, p.avatar], [true, 'Alex', 'panda'], reason: 'trimmed, with the chosen avatar');
    });

    testWidgets('Skip jumps past the pages; Skip for now keeps the guest name', (t) async {
      final (store, done) = await open(t);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const Key('onboarding_skip')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_profile')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('onboarding_profile_skip')));
      await t.tap(find.byKey(const Key('onboarding_profile_skip')));
      await t.pumpAndSettle();
      expect(done, [1]);
      expect(store.profile.onboarded, isTrue);
      expect(store.profile.nickname, isNull, reason: 'nothing to send to the server');
    });

    testWidgets('fits 360x640 at 1.4x text on every step', (t) async {
      view(t, w: 360, h: 640);
      final store = await freshStore();
      await t.pumpWidget(MaterialApp(
        builder: (c, ch) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: ch!,
        ),
        home: OnboardingFlow(store: store, onDone: () {}, splashDuration: const Duration(milliseconds: 100)),
      ));
      expect(t.takeException(), isNull);
      await t.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 3; i++) {
        expect(t.takeException(), isNull, reason: 'page $i');
        await t.tap(find.byKey(const Key('onboarding_next')));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull, reason: 'profile step');
    });
  });

  group('app start', () {
    testWidgets('first launch shows onboarding, then the app', (t) async {
      view(t);
      final store = await freshStore();
      await t.pumpWidget(ClassicBoardGamesApp(store: store, onboarded: false));
      await t.pump(const Duration(milliseconds: 2000));
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      await t.tap(find.byKey(const Key('onboarding_skip')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('onboarding_name')), 'Alex');
      await t.pump();
      await t.tap(find.byKey(const Key('onboarding_save')));
      await t.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('a returning player goes straight to the app', (t) async {
      view(t);
      final store = await freshStore({'onboarded': true});
      await t.pumpWidget(ClassicBoardGamesApp(store: store, onboarded: store.profile.onboarded));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
    });
  });
}
