import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';

/// The Party tab's one loud element: a tilted yellow invitation to start a
/// party room (random games, one scoreboard).
class PartyInvite extends StatelessWidget {
  final VoidCallback onStart;
  const PartyInvite({super.key, required this.onStart});

  static const _games = ['♟️', '🐍', '🔴', '🔤', '🤥'];

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.018,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: AppPalette.confetti,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: AppPalette.ink, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start a party',
              style: AppTextStyles.title.copyWith(
                color: AppPalette.ink,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A new game every round and one scoreboard. Pick 3, 5 or 7 rounds, then send the code to your friends.',
              style: AppTextStyles.body.copyWith(color: AppPalette.ink),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final g in _games)
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppPalette.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppPalette.ink, width: 2.5),
                    ),
                    child: ExcludeSemantics(
                      child: Text(g, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                key: const Key('party_start'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.ink,
                  foregroundColor: AppPalette.cream,
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onStart,
                icon: const Icon(Icons.celebration_rounded),
                label: const Text('Start a party'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 6-character room code drawn as ticket tiles. One real (invisible) text
/// field sits on top, so typing, pasting and screen readers all work.
class RoomCodeField extends StatefulWidget {
  final void Function(String code) onJoin;
  const RoomCodeField({super.key, required this.onJoin});

  static const length = 6;

  @override
  State<RoomCodeField> createState() => _RoomCodeFieldState();
}

class _RoomCodeFieldState extends State<RoomCodeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _code => _controller.text;
  bool get _complete => _code.length == RoomCodeField.length;

  void _join() {
    if (_complete) widget.onJoin(_code);
  }

  @override
  Widget build(BuildContext context) {
    final active = _focus.hasFocus
        ? _code.length.clamp(0, RoomCodeField.length - 1)
        : -1;
    // TextField needs a Material ancestor; this keeps the widget usable anywhere.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Room code, ${RoomCodeField.length} characters',
              textField: true,
              child: SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < RoomCodeField.length; i++)
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i == RoomCodeField.length - 1 ? 0 : 6,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppPalette.panel,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: i == active
                                      ? AppPalette.confetti
                                      : AppPalette.ink,
                                  width: i == active ? 3 : 2.5,
                                ),
                              ),
                              child: Text(
                                i < _code.length ? _code[i] : '',
                                style: AppTextStyles.heading.copyWith(
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned.fill(
                      child: TextField(
                        key: const Key('party_code'),
                        controller: _controller,
                        focusNode: _focus,
                        maxLength: RoomCodeField.length,
                        autocorrect: false,
                        enableSuggestions: false,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                        cursorColor: Colors.transparent,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[a-zA-Z0-9]'),
                          ),
                          TextInputFormatter.withFunction(
                            (_, v) => v.copyWith(text: v.text.toUpperCase()),
                          ),
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _join(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: FilledButton(
              key: const Key('party_join'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.mint,
                foregroundColor: AppPalette.ink,
                textStyle: AppTextStyles.button,
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              onPressed: _complete ? _join : null,
              child: const Text('Join'),
            ),
          ),
        ],
      ),
    );
  }
}
