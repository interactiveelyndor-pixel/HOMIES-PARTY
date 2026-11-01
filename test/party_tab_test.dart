import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/app_shell.dart';
import 'package:classic_ludo/screens/play_widgets.dart';
import 'package:classic_ludo/ui/state_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void view(WidgetTester t, {double w = 390, double h = 844}) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
}

void main() {
  group('RoomCodeField', () {
    testWidgets('shows typed characters in upper case, only letters and digits', (t) async {
      view(t);
      String? joined;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: RoomCodeField(onJoin: (c) => joined = c))),
      ));
      FilledButton join() => t.widget<FilledButton>(find.byKey(const Key('party_join')));
      expect(join().onPressed, isNull, reason: 'empty code cannot be joined');

      await t.enterText(find.byKey(const Key('party_code')), 'ab-c 2');
      await t.pump();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(join().onPressed, isNull, reason: 'only 4 of 6 characters');

      await t.enterText(find.byKey(const Key('party_code')), 'abc234xyz');
      await t.pump();
      expect(find.text('X'), findsNothing, reason: 'capped at 6 characters');
      expect(join().onPressed, isNotNull);
      await t.tap(find.byKey(const Key('party_join')));
      expect(joined, 'ABC234');
    });
  });

  group('Party tab', () {
    Future<void> pump(WidgetTester t, {double w = 390, double h = 844, double scale = 1}) async {
      view(t, w: w, h: h);
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: PlayScreen(
            onBrowseGames: () {},
            api: ApiClient(),
            loadConfig: () async => const AppConfig(policyVersion: '1', minClientVersion: '0.0.0', publicDiscovery: true),
          ),
        ),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('leads with the party invitation, then the code, then quieter options', (t) async {
      await pump(t);
      expect(find.byKey(const Key('party_start')), findsOneWidget);
      expect(find.text('Got a code?'), findsOneWidget);
      expect(find.byKey(const Key('party_code')), findsOneWidget);
      expect(find.text('More ways to play'), findsOneWidget);
      expect(find.byKey(const Key('play_local')), findsOneWidget);
    });

    testWidgets('no overflow on 360x640 at 1.4x text', (t) async {
      await pump(t, w: 360, h: 640, scale: 1.4);
      expect(t.takeException(), isNull);
      await t.drag(find.byType(ListView), const Offset(0, -900));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('play_match')), findsOneWidget);
    });
  });

  testWidgets('StateMessage shows what happened and a button that works', (t) async {
    view(t);
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Can\'t load your friends',
          body: 'Check your connection.',
          actionLabel: 'Try again',
          actionKey: const Key('retry'),
          onAction: () => taps++,
        ),
      ),
    ));
    expect(find.text('Can\'t load your friends'), findsOneWidget);
    await t.tap(find.byKey(const Key('retry')));
    expect(taps, 1);
  });
}
