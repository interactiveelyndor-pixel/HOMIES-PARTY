import 'package:flutter/material.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'wyr_game_screen.dart';

/// Entry screen: choose how many people share the phone.
class WyrSetupScreen extends StatefulWidget {
  const WyrSetupScreen({super.key});

  @override
  State<WyrSetupScreen> createState() => _WyrSetupScreenState();
}

class _WyrSetupScreenState extends State<WyrSetupScreen> {
  static const _min = 2, _max = 8;
  int _players = 3;

  // Plain tap target (no AppCard): +/- must accept quick repeated taps.
  Widget _step(Key key, IconData icon, String label, bool enabled, int delta) =>
      Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => setState(() => _players += delta) : null,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: enabled ? AppPalette.confetti : AppPalette.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.ink, width: 3),
              boxShadow: const [
                BoxShadow(color: AppPalette.ink, offset: Offset(0, 4)),
              ],
            ),
            child: Icon(icon,
                size: 30,
                color: enabled ? AppPalette.ink : AppPalette.textMuted),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppPalette.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBackButton(key: Key('wyr_back_button')),
                const SizedBox(height: 22),
                const Text('Would You Rather', style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text(
                  'One phone, passed around. Everyone votes in secret, then '
                  'the room finds out who thinks alike.',
                  style: AppTextStyles.subheading,
                ),
                const Spacer(),
                Center(
                  child: Column(children: [
                    Text('How many players?', style: AppTextStyles.heading),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _step(const Key('wyr_players_minus'), Icons.remove_rounded,
                            'One fewer player', _players > _min, -1),
                        SizedBox(
                          width: 110,
                          child: Text(
                            '$_players',
                            key: const Key('wyr_players'),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.title.copyWith(
                                fontSize: 64, color: AppPalette.confetti),
                          ),
                        ),
                        _step(const Key('wyr_players_plus'), Icons.add_rounded,
                            'One more player', _players < _max, 1),
                      ],
                    ),
                  ]),
                ),
                const Spacer(),
                AppButton(
                  key: const Key('wyr_start'),
                  text: 'Start',
                  width: double.infinity,
                  height: 58,
                  onPressed: () => Navigator.of(context).push(
                      appPageRoute(WyrGameScreen(playerCount: _players))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
