import 'package:flutter/material.dart';

import '../network/network.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'online_reactions.dart';
import 'round_game_widgets.dart';

/// Online Bluff & Vote. Everyone writes a fake answer to a trivia question, then
/// votes for the one they think is true. The server keeps the real answer and
/// who wrote what secret until the reveal. Played in private rooms only.
class OnlineBluffScreen extends StatefulWidget {
  final Room room;
  final String myUserId;

  /// Injectable for tests; defaults to the real connection.
  final GameSocket? socket;
  final ApiClient? api;
  const OnlineBluffScreen({
    super.key,
    required this.room,
    required this.myUserId,
    this.socket,
    this.api,
  });

  @override
  State<OnlineBluffScreen> createState() => _OnlineBluffScreenState();
}

class _OnlineBluffScreenState extends State<OnlineBluffScreen> {
  late final OnlineGameSession _session = OnlineGameSession(
    room: widget.room,
    myUserId: widget.myUserId,
    socket: widget.socket ?? SocketService(),
  );
  late final ApiClient _api = widget.api ?? ApiClient();
  final _answer = TextEditingController();
  int _round = 0;
  String? _myAnswer; // what I wrote this round, so I do not vote for it

  @override
  void dispose() {
    _session.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    await _session.act({'answer': text});
    if (_session.error == null) _myAnswer = text;
  }

  Future<void> _report(String userId, String name, String text) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Report $name\'s answer'),
        children: [
          for (final r in const {
            'harassment': 'Mean or hateful',
            'spam': 'Spam',
            'other': 'Something else',
          }.entries)
            SimpleDialogOption(
              key: Key('report_${r.key}'),
              onPressed: () => Navigator.pop(ctx, r.key),
              child: Text(r.value),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await _api.reportUser(userId, reason, details: 'Bluff answer: "$text"');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report sent. Thank you.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not send.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) {
                final s = _session;
                final round = (s.state['round'] as num).toInt();
                if (round != _round) {
                  _round = round;
                  _answer.clear();
                  _myAnswer = null;
                }
                return Column(
                  children: [
                    RoundGameHeader(session: s),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(child: _body(s)),
                    ),
                    OnlineReactions(session: s),
                    if (s.error != null)
                      Text(
                        s.error!,
                        key: const Key('bluff_error'),
                        style: AppTextStyles.caption.copyWith(
                          color: AppPalette.danger,
                        ),
                      ),
                    if (s.isOver && s.rematchLabel != null)
                      AppButton(
                        key: const Key('bluff_rematch'),
                        text: s.rematchLabel!,
                        width: double.infinity,
                        onPressed: s.rematch,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(OnlineGameSession s) {
    if (s.isOver) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: ResultBanner(
            session: s,
            textKey: const Key('bluff_result'),
          ),
        ),
      );
    }
    final phase = '${s.state['phase']}';
    final submitted = ((s.state['submitted'] as List?) ?? const []).cast<String>();
    final voted = ((s.state['voted'] as List?) ?? const []).cast<String>();
    final options = ((s.state['options'] as List?) ?? const []).cast<Map>();
    final iWrote = submitted.contains(s.myUserId);
    final iVoted = voted.contains(s.myUserId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${s.state['question']}',
          key: const Key('bluff_question'),
          textAlign: TextAlign.center,
          style: AppTextStyles.heading,
        ),
        const SizedBox(height: 16),
        if (phase == 'write') ...[
          if (!iWrote) ...[
            TextField(
              key: const Key('bluff_answer'),
              controller: _answer,
              maxLength: 30,
              style: AppTextStyles.heading.copyWith(fontSize: 20),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppPalette.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppPalette.ink, width: 2.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppPalette.ink, width: 2.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppPalette.confetti, width: 3),
                ),
                hintText: 'Write a believable fake answer',
              ),
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('bluff_submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.confetti,
                  foregroundColor: AppPalette.ink,
                  textStyle: AppTextStyles.button,
                ),
                onPressed: s.busy ? null : _submit,
                child: const Text('Submit answer'),
              ),
            ),
            const Text(
              'Keep it friendly. Others will see it, and you can be reported.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ] else
            const Text(
              'Answer locked in!',
              key: Key('bluff_locked'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold,
            ),
          const SizedBox(height: 8),
          Text(
            '${submitted.length} of ${s.players.length} written',
            key: const Key('bluff_progress'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
        if (phase == 'vote') ...[
          const Text(
            'Which one is true?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppPalette.panel,
                    foregroundColor: AppPalette.textPrimary,
                    textStyle: AppTextStyles.bodyBold,
                    side: const BorderSide(color: AppPalette.ink, width: 2.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  key: Key('bluff_option_${o['id']}'),
                  onPressed: iVoted || o['text'] == _myAnswer || s.busy
                      ? null
                      : () => s.act({'option': o['id']}),
                  child: Text('${o['text']}'),
                ),
              ),
            ),
          Text(
            iVoted
                ? 'Vote locked in. ${voted.length} of ${s.players.length} voted.'
                : '${voted.length} of ${s.players.length} voted',
            key: const Key('bluff_progress'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
        if (phase == 'reveal') _reveal(s, options),
      ],
    );
  }

  Widget _reveal(OnlineGameSession s, List<Map> options) {
    final reveal = (s.state['reveal'] as Map?) ?? const {};
    final truthId = reveal['truthId'];
    final authors = (reveal['authors'] as Map?) ?? const {};
    final votes = (reveal['votes'] as Map?) ?? const {};
    final gained = (reveal['gained'] as Map?) ?? const {};
    String who(Object? id) =>
        id == s.myUserId ? 'You' : s.nameOf(id as String?);
    return Column(
      key: const Key('bluff_reveal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in options)
          Container(
            key: Key('bluff_reveal_${o['id']}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: o['id'] == truthId ? AppPalette.mint : AppPalette.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.ink,
                width: o['id'] == truthId ? 3 : 2.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o['id'] == truthId
                            ? '✅ ${o['text']}  (true)'
                            : '${o['text']}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: o['id'] == truthId ? AppPalette.ink : null,
                        ),
                      ),
                      if (o['id'] != truthId)
                        Text(
                          'Written by ${((authors['${o['id']}'] ?? authors[o['id']]) as List? ?? const []).map(who).join(', ')}',
                          style: AppTextStyles.caption,
                        ),
                      Builder(
                        builder: (_) {
                          final voters =
                              (votes['${o['id']}'] ?? votes[o['id']]) as List? ??
                              const [];
                          return Text(
                            voters.isEmpty
                                ? 'No votes'
                                : 'Votes: ${voters.map(who).join(', ')}',
                            style: AppTextStyles.caption.copyWith(
                              color: o['id'] == truthId ? AppPalette.ink : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (o['id'] != truthId)
                  for (final a
                      in ((authors['${o['id']}'] ?? authors[o['id']]) as List? ??
                          const []))
                    if (a != s.myUserId)
                      IconButton(
                        key: Key('bluff_report_$a'),
                        tooltip: 'Report this answer',
                        icon: const Icon(Icons.flag_outlined),
                        onPressed: () =>
                            _report(a as String, who(a), '${o['text']}'),
                      ),
              ],
            ),
          ),
        Wrap(
          key: const Key('bluff_gained'),
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final p in s.players)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ((gained[p['userId']] as num?) ?? 0) > 0
                      ? AppPalette.confetti
                      : AppPalette.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppPalette.ink, width: 2.5),
                ),
                child: Text(
                  '${who(p['userId'])} +${gained[p['userId']] ?? 0}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: ((gained[p['userId']] as num?) ?? 0) > 0
                        ? AppPalette.ink
                        : AppPalette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
