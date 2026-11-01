import 'package:flutter/material.dart';

import '../network/network.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';

/// Must match REACTIONS in server/src/socket.ts.
const gameReactions = ['👍', '😂', '😮', '🔥', '👏', '😢'];

/// Must match PHRASES in server/src/socket.ts. Fixed text only, never typed.
const gamePhrases = [
  'Good luck!',
  'Well played!',
  'Nooo!',
  'Nice move!',
  'Hahaha!',
  'Oops!',
];

/// Reaction buttons plus a short feed of what other players just sent.
class OnlineReactions extends StatelessWidget {
  final OnlineGameSession session;
  const OnlineReactions({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always reserve the feed's height so the board does not jump.
        SizedBox(
          height: 34,
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final r in session.reactions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      key: Key('reaction_${r.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppPalette.ink, width: 2),
                      ),
                      child: Text(
                        r.userId == session.myUserId
                            ? r.emoji
                            : '${session.nameOf(r.userId)} ${r.emoji}',
                        style: AppTextStyles.bodyBold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final e in gameReactions)
              Semantics(
                button: true,
                label: 'Send $e',
                excludeSemantics: true,
                child: GestureDetector(
                  key: Key('react_$e'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => session.react(e),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in gamePhrases)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ActionChip(
                    key: Key('phrase_$p'),
                    label: Text(p),
                    labelStyle: AppTextStyles.bodyBold,
                    backgroundColor: AppPalette.panel,
                    side: const BorderSide(color: AppPalette.ink, width: 2.5),
                    onPressed: () => session.react(p),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
