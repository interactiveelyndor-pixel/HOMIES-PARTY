import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/screens/home_screen.dart';

void main() {
  group('HomeScreen - 5 Game Cards & Responsive Viewport Tests', () {
    testWidgets('Renders all 5 game cards on compact phone (360x640) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      expect(find.byKey(const Key('home_snl_card')), findsOneWidget);
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);
      expect(find.byKey(const Key('home_battleship_card')), findsOneWidget);
      expect(find.byKey(const Key('home_pen_fight_card')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders all 5 game cards on standard phone (390x844) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      expect(find.byKey(const Key('home_snl_card')), findsOneWidget);
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);
      expect(find.byKey(const Key('home_battleship_card')), findsOneWidget);
      expect(find.byKey(const Key('home_pen_fight_card')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders all 5 game cards on tall phone (412x923) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 923 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      expect(find.byKey(const Key('home_snl_card')), findsOneWidget);
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);
      expect(find.byKey(const Key('home_battleship_card')), findsOneWidget);
      expect(find.byKey(const Key('home_pen_fight_card')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Adapts to larger system accessibility text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.4),
              ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      expect(find.byKey(const Key('home_snl_card')), findsOneWidget);
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);
      expect(find.byKey(const Key('home_battleship_card')), findsOneWidget);
      expect(find.byKey(const Key('home_pen_fight_card')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
