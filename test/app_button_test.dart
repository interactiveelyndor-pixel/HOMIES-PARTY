import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/ui/app_button.dart';

void main() {
  group('AppButton Component Tests', () {
    testWidgets('Tap works when enabled and triggers onPressed', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                text: 'Play Game',
                onPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Play Game'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(tapCount, equals(1));
    });

    testWidgets('Disabled button does not fire onPressed', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                text: 'Disabled Action',
                enabled: false,
                onPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(tapCount, equals(0));
    });

    testWidgets('Rapid double-tap fires onPressed only once (debounce safe)',
        (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                text: 'Rapid Tap',
                onPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );

      final button = find.byType(AppButton);
      // Rapid double tap within milliseconds
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tapCount, equals(1));
    });

    testWidgets('Loading state shows spinner and does not fire onPressed',
        (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                text: 'Loading Action',
                isLoading: true,
                onPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tapCount, equals(0));
    });

    testWidgets('Supports primary, secondary, and danger variants',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton(
                  text: 'Primary',
                  variant: AppButtonVariant.primary,
                  onPressed: () {},
                ),
                AppButton(
                  text: 'Secondary',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                AppButton(
                  text: 'Danger',
                  variant: AppButtonVariant.danger,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Danger'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
