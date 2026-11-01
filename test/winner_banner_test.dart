import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/widgets/winner_banner.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('WinnerBanner shows WINNER! text', (tester) async {
    await tester.pumpWidget(wrap(
      const WinnerBanner(winnerName: 'Red', winnerColor: Colors.red),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('WINNER!'), findsOneWidget);
  });

  testWidgets('WinnerBanner shows the winner name', (tester) async {
    await tester.pumpWidget(wrap(
      const WinnerBanner(winnerName: 'Blue', winnerColor: Colors.blue),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Blue'), findsOneWidget);
  });

  testWidgets('WinnerBanner is wrapped in IgnorePointer', (tester) async {
    await tester.pumpWidget(wrap(
      const WinnerBanner(winnerName: 'Green', winnerColor: Colors.green),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(IgnorePointer), findsAtLeastNWidgets(1));
    expect(find.text('WINNER!'), findsOneWidget);
  });
}
