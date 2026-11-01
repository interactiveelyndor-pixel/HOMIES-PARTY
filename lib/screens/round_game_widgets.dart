import 'dart:async';

import 'package:flutter/material.dart';

import '../network/network.dart';
import '../ui/app_back_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';

/// Seconds left until the server's deadline, ticking once a second.
class CountdownText extends StatefulWidget {
  final int deadlineMs;
  const CountdownText({super.key, required this.deadlineMs});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left =
        ((widget.deadlineMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil()
            .clamp(0, 999);
    final urgent = left <= 5;
    return Semantics(
      label: '$left seconds left',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: urgent ? AppPalette.candy : AppPalette.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.ink, width: 2.5),
        ),
        child: Text(
          '${left}s',
          style: AppTextStyles.bodyBold.copyWith(
            color: urgent ? AppPalette.ink : AppPalette.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Back button, room code, round counter and every player's score.
class RoundGameHeader extends StatelessWidget {
  final OnlineGameSession session;
  final bool showTimer;
  const RoundGameHeader({
    super.key,
    required this.session,
    this.showTimer = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final scores = (s.state['scores'] as Map?) ?? const {};
    return Column(
      children: [
        Row(
          children: [
            const AppBackButton(),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Round ${s.state['round']} of ${s.state['rounds']}',
                key: const Key('round_label'),
                style: AppTextStyles.heading,
              ),
            ),
            if (showTimer && !s.isOver)
              CountdownText(
                key: const Key('round_timer'),
                deadlineMs: (s.state['turnDeadline'] as num).toInt(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < s.players.length; i++)
              ScorePill(
                key: Key('score_${s.players[i]['userId']}'),
                name: s.players[i]['userId'] == s.myUserId
                    ? 'You'
                    : s.nameOf(s.players[i]['userId'] as String),
                score: (scores[s.players[i]['userId']] as num?)?.toInt() ?? 0,
                color: AppPalette.seatColors[i % AppPalette.seatColors.length],
                mine: s.players[i]['userId'] == s.myUserId,
              ),
          ],
        ),
      ],
    );
  }
}

/// "You win!" / "Zed wins!" / "It is a draw", or null while the game runs.
String? roundGameResult(OnlineGameSession s) {
  if (s.winnerId != null) {
    return s.winnerId == s.myUserId ? 'You win!' : '${s.nameOf(s.winnerId)} wins!';
  }
  return s.isDraw ? 'It is a draw' : null;
}

/// A player's name and points: coloured dot, name, score. Yours has a yellow edge.
class ScorePill extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final bool mine;
  const ScorePill({
    super.key,
    required this.name,
    required this.score,
    required this.color,
    this.mine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name, $score points',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        decoration: BoxDecoration(
          color: AppPalette.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mine ? AppPalette.confetti : AppPalette.ink,
            width: 2.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.ink, width: 2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: AppPalette.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Text('$score', style: AppTextStyles.bodyBold),
          ],
        ),
      ),
    );
  }
}

/// The end-of-game card: a trophy for a win, a handshake for a draw.
class ResultBanner extends StatelessWidget {
  final OnlineGameSession session;
  final Key? textKey;
  const ResultBanner({super.key, required this.session, this.textKey});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final won = s.winnerId == s.myUserId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        color: won ? AppPalette.confetti : AppPalette.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.ink, width: 3),
        boxShadow: const [BoxShadow(color: AppPalette.ink, offset: Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              s.isDraw ? '🤝' : (won ? '🏆' : '👏'),
              style: const TextStyle(fontSize: 44),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            roundGameResult(s) ?? '',
            key: textKey,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              color: won ? AppPalette.ink : AppPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
