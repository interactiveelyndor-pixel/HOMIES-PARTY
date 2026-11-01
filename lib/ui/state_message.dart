import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_text_styles.dart';

/// A calm full-area message for empty or failed screens: what happened, what
/// to do next, and one button that does it.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.panel,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.ink, width: 3),
                boxShadow: const [
                  BoxShadow(color: AppPalette.ink, offset: Offset(0, 4)),
                ],
              ),
              child: Icon(icon, size: 34, color: AppPalette.confetti),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.heading),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppPalette.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: actionKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.confetti,
                    foregroundColor: AppPalette.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    textStyle: AppTextStyles.button,
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet": an icon and one plain sentence. Keeps its text intact so
/// it reads the same to screen readers and tests.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyHint({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppPalette.panel,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.ink, width: 3),
              boxShadow: const [BoxShadow(color: AppPalette.ink, offset: Offset(0, 4))],
            ),
            child: Icon(icon, size: 30, color: AppPalette.confetti),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppPalette.textSecondary),
          ),
        ],
      ),
    );
  }
}
