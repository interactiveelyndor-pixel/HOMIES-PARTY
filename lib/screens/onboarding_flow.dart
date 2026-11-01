import 'dart:async';

import 'package:flutter/material.dart';

import '../profile/local_profile.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';

enum _Step { splash, pages, profile }

/// First launch: splash, three short pages, then choose an avatar and a name.
/// Calls [onDone] when finished; nothing here needs the network.
class OnboardingFlow extends StatefulWidget {
  final LocalProfileStore store;
  final VoidCallback onDone;
  final Duration splashDuration;
  const OnboardingFlow({
    super.key,
    required this.store,
    required this.onDone,
    this.splashDuration = const Duration(milliseconds: 1600),
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  _Step _step = _Step.splash;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.splashDuration, () {
      if (mounted) setState(() => _step = _Step.pages);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Keeps the automatic guest name; it can be changed later under Profile.
  Future<void> _skip() async {
    await widget.store.markOnboarded();
    widget.onDone();
  }

  Future<void> _finish(String nickname, String avatar) async {
    await widget.store.saveProfile(nickname: nickname, avatar: avatar);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity, // fill the screen even when the step is short
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: switch (_step) {
            _Step.splash => const _Splash(),
            _Step.pages => _Pages(
              onDone: () => setState(() => _step = _Step.profile),
            ),
            _Step.profile => _ProfileSetup(onSave: _finish, onSkip: _skip),
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  static const _wordmark = TextStyle(
    fontFamily: 'Knewave',
    fontSize: 56,
    height: 1.0,
  );

  Widget _outlined(String text, Color fill) => Stack(
    children: [
      Text(
        text,
        style: _wordmark.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeJoin = StrokeJoin.round
            ..color = AppPalette.ink,
        ),
      ),
      Text(text, style: _wordmark.copyWith(color: fill)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('onboarding_splash'),
      child: Semantics(
        header: true,
        label: 'Homies: Party',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _outlined('Homies', AppPalette.cream),
            _outlined('Party', AppPalette.confetti),
            const SizedBox(height: 16),
            Text(
              'Find a game. Find your people.',
              style: AppTextStyles.body.copyWith(
                color: AppPalette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  final String emoji;
  final String title;
  final String body;
  const _PageData(this.emoji, this.title, this.body);
}

const _pages = [
  _PageData(
    '🎲',
    'Find a game',
    'Ludo, Snakes & Ladders, Connect Four and more. Play on one phone, against the computer, or online.',
  ),
  _PageData(
    '🎉',
    'Play with your people',
    'Make a private room, send the code, and start a party with a new game every round.',
  ),
  _PageData(
    '🛡️',
    'Play safe',
    'No open chat with strangers. You can block or report anyone, and your name is all we keep.',
  ),
];

class _Pages extends StatefulWidget {
  final VoidCallback onDone;
  const _Pages({required this.onDone});

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      widget.onDone();
    } else {
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _controller.jumpToPage(_index + 1);
      } else {
        _controller.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Padding(
      key: const Key('onboarding_pages'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('onboarding_skip'),
              style: TextButton.styleFrom(foregroundColor: AppPalette.textSecondary),
              onPressed: widget.onDone,
              child: const Text('Skip'),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                for (final p in _pages)
                  // Centred when there is room, scrollable when text is large.
                  LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppPalette.confetti,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppPalette.ink,
                                  width: 4,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppPalette.ink,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ExcludeSemantics(
                                child: Text(
                                  p.emoji,
                                  style: const TextStyle(fontSize: 64),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.title,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              p.body,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                color: AppPalette.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                Container(
                  width: i == _index ? 22 : 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _index ? AppPalette.confetti : AppPalette.panel,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppPalette.ink, width: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const Key('onboarding_next'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.confetti,
                foregroundColor: AppPalette.ink,
                textStyle: AppTextStyles.button,
              ),
              onPressed: _next,
              child: Text(last ? 'Let\'s go' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick an avatar and a display name. Both can be changed later under Profile.
class _ProfileSetup extends StatefulWidget {
  final Future<void> Function(String nickname, String avatar) onSave;
  final Future<void> Function() onSkip;
  const _ProfileSetup({required this.onSave, required this.onSkip});

  @override
  State<_ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<_ProfileSetup> {
  final _name = TextEditingController();
  String _avatar = avatarPresets.first.id;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();
  // Same limits the server enforces.
  bool get _valid => _trimmed.length >= 2 && _trimmed.length <= 20;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(_trimmed, _avatar);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('onboarding_profile'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Who are you?', style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(
            'Pick a look and a name. Friends in your rooms will see them.',
            style: AppTextStyles.body.copyWith(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final a in avatarPresets)
                Semantics(
                  button: true,
                  selected: _avatar == a.id,
                  label: a.label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: Key('avatar_${a.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _avatar = a.id),
                    child: Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: a.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _avatar == a.id
                              ? AppPalette.cream
                              : AppPalette.ink,
                          width: _avatar == a.id ? 4 : 3,
                        ),
                        boxShadow: _avatar == a.id
                            ? const [
                                BoxShadow(
                                  color: AppPalette.ink,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        a.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Your name', style: AppTextStyles.heading),
          const SizedBox(height: 8),
          TextField(
            key: const Key('onboarding_name'),
            controller: _name,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.heading.copyWith(fontSize: 20),
            decoration: InputDecoration(
              hintText: 'e.g. Alex',
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
                borderSide: const BorderSide(
                  color: AppPalette.confetti,
                  width: 3,
                ),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          Text(
            'Use a nickname, not your real name. 2 to 20 characters.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const Key('onboarding_save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.confetti,
                foregroundColor: AppPalette.ink,
                textStyle: AppTextStyles.button,
              ),
              onPressed: _valid && !_saving ? _save : null,
              child: const Text('Start playing'),
            ),
          ),
          Center(
            child: TextButton(
              key: const Key('onboarding_profile_skip'),
              style: TextButton.styleFrom(foregroundColor: AppPalette.textSecondary),
              onPressed: _saving ? null : widget.onSkip,
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }
}
