import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/lobby_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RoomPlayer player(String id, String name, {bool ready = false, bool host = false}) => RoomPlayer.fromJson({
  'userId': id,
  'nickname': name,
  'isReady': ready,
  'isHost': host,
});

Future<void> pump(WidgetTester t, Widget child, {double w = 390, double h = 844, double scale = 1}) async {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
  await t.pumpWidget(MaterialApp(
    builder: (c, ch) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: ch!,
    ),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: child)),
  ));
}

void main() {
  pickChipTests();
  testWidgets('GamePicker lists every online game plus Party and reports the choice', (t) async {
    String? picked;
    await pump(t, GamePicker(selected: 'ludo', onSelect: (id) => picked = id));
    for (final id in ['ludo', 'snl', 'connect4', 'wordrush', 'bluff', 'party']) {
      expect(find.byKey(Key('lobby_game_$id')), findsOneWidget, reason: id);
    }
    expect(t.widget<GamePickTile>(find.byKey(const Key('lobby_game_ludo'))).selected, isTrue);
    expect(t.widget<GamePickTile>(find.byKey(const Key('lobby_game_snl'))).selected, isFalse);
    expect(find.text('3-4 players'), findsOneWidget, reason: 'Bluff needs at least three');
    await t.tap(find.byKey(const Key('lobby_game_party')));
    expect(picked, 'party');
  });

  testWidgets('RoomTicket shows the code one tile per character and copies it', (t) async {
    var copied = 0;
    await pump(t, RoomTicket(code: '9VTCVC', playing: 'Ludo', onCopy: () => copied++));
    for (final c in ['9', 'V', 'T', 'C']) {
      expect(find.text(c), findsWidgets);
    }
    expect(find.text('Ludo'), findsOneWidget);
    await t.tap(find.byKey(const Key('room_copy')));
    expect(copied, 1);
  });

  testWidgets('PlayerSeat shows You/Host, ready state and a remove button only when allowed', (t) async {
    var kicked = 0;
    await pump(
      t,
      Column(children: [
        PlayerSeat(player: player('me', 'Alex', host: true), index: 0, isMe: true),
        const SizedBox(height: 8),
        PlayerSeat(player: player('you', 'Zed', ready: true), index: 1, isMe: false, onKick: () => kicked++),
      ]),
    );
    expect(find.text('You · Host'), findsOneWidget);
    expect(find.text('Not ready'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byKey(const Key('kick_me')), findsNothing);
    await t.tap(find.byKey(const Key('kick_you')));
    expect(kicked, 1);
  });

  testWidgets('seats and ticket fit 360x640 at 1.4x text', (t) async {
    await pump(
      t,
      SingleChildScrollView(
        child: Column(children: [
          RoomTicket(code: 'ABC234', playing: '🎉 Party · 5 rounds, a new game each time', onCopy: () {}),
          PlayerSeat(player: player('a', 'A very long nickname here', host: true), index: 0, isMe: true),
          PlayerSeat(player: player('b', 'Zed', ready: true), index: 1, isMe: false, onKick: () {}),
          const EmptySeat(),
        ]),
      ),
      w: 360,
      h: 640,
      scale: 1.4,
    );
    expect(t.takeException(), isNull);
  });
}

void pickChipTests() {
  testWidgets('PickChip is as wide as its label, not the whole line', (t) async {
    await pump(t, Wrap(spacing: 8, children: [
      PickChip(label: '3 rounds', selected: true, onTap: () {}),
      PickChip(label: '5 rounds', selected: false, onTap: () {}),
    ]));
    expect(t.getSize(find.byType(PickChip).first).width, lessThan(200));
    expect(t.getTopLeft(find.byType(PickChip).last).dy, t.getTopLeft(find.byType(PickChip).first).dy);
  });
}
