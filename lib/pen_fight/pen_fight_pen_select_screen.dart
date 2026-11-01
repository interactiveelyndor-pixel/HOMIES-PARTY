import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'pen_fight_game_screen.dart';
import 'pen_fight_models.dart';
import 'pen_fight_theme.dart';

/// Pre-match Pen Selection screen.
/// - In "Play with Friend" mode: Player 1 picks in turn, then Player 2 picks.
/// - In "vs Computer" mode: Player 1 picks, and CPU picks from a seeded random source.
class PenFightPenSelectScreen extends StatefulWidget {
  final bool vsComputer;
  final math.Random? random;

  const PenFightPenSelectScreen({
    super.key,
    required this.vsComputer,
    this.random,
  });

  @override
  State<PenFightPenSelectScreen> createState() => _PenFightPenSelectScreenState();
}

class _PenFightPenSelectScreenState extends State<PenFightPenSelectScreen> {
  late final math.Random _random;

  // In Friend mode: step 1 is Player 1 picking, step 2 is Player 2 picking.
  int _currentStep = 1;

  PenType _p1Selected = PenType.balanced;
  PenType _p2Selected = PenType.balanced;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? math.Random();
    if (widget.vsComputer) {
      // CPU picks from seeded random source
      _p2Selected = PenType.values[_random.nextInt(PenType.values.length)];
    }
  }

  void _onPenSelected(PenType type) {
    setState(() {
      if (_currentStep == 1) {
        _p1Selected = type;
      } else {
        _p2Selected = type;
      }
    });
  }

  void _onNext() {
    if (widget.vsComputer) {
      _startMatch();
    } else {
      if (_currentStep == 1) {
        setState(() {
          _currentStep = 2;
        });
      } else {
        _startMatch();
      }
    }
  }

  void _startMatch() {
    Navigator.of(context).pushReplacement(
      appPageRoute(
        PenFightGameScreen(
          vsComputer: widget.vsComputer,
          p1PenType: _p1Selected,
          p2PenType: _p2Selected,
          random: _random,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isP1Step = _currentStep == 1;
    final activePlayerName = isP1Step ? 'Player 1' : 'Player 2';
    final currentlySelected = isP1Step ? _p1Selected : _p2Selected;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    AppBackButton(
                      key: const Key('pen_fight_select_back_button'),
                      onPressed: () {
                        if (_currentStep == 2) {
                          setState(() => _currentStep = 1);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Select Pen',
                        style: AppTextStyles.heading.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),

              // Title Header Pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isP1Step
                                ? PenFightTheme.p1PenHighlight
                                : PenFightTheme.p2PenHighlight)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isP1Step
                                  ? PenFightTheme.p1PenHighlight
                                  : PenFightTheme.p2PenHighlight)
                              .withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.vsComputer
                            ? 'CHOOSE YOUR PEN'
                            : '${activePlayerName.toUpperCase()} · STEP $_currentStep OF 2',
                        style: AppTextStyles.badge.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.vsComputer
                          ? 'Select your pen type against CPU'
                          : '$activePlayerName, select your weapon',
                      style: AppTextStyles.body.copyWith(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Pen Type Selection Cards
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: PenType.values.map((type) {
                        final isSelected = currentlySelected == type;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PenTypeOptionCard(
                            key: Key('pen_fight_select_${type.name}'),
                            type: type,
                            isSelected: isSelected,
                            onTap: () => _onPenSelected(type),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // CPU Selection Preview (vs Computer mode)
              if (widget.vsComputer)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          'CPU chose: ${_p2Selected.displayName} Pen',
                          style: AppTextStyles.caption.copyWith(
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: AppButton(
                  key: Key(
                    (!widget.vsComputer && _currentStep == 1)
                        ? 'pen_fight_select_next_button'
                        : 'pen_fight_start_match_button',
                  ),
                  text: (!widget.vsComputer && _currentStep == 1)
                      ? 'Next (Player 2) ➔'
                      : 'Start Match ➔',
                  onPressed: _onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenTypeOptionCard extends StatelessWidget {
  final PenType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _PenTypeOptionCard({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBorder;
    Color glowColor;
    List<Color> cardGradient;

    if (isSelected) {
      cardBorder = PenFightTheme.accentLight;
      glowColor = PenFightTheme.accentGlow;
      cardGradient = const [
        Color(0xFF1E3A8A),
        Color(0xFF3B82F6),
      ];
    } else {
      cardBorder = Colors.white.withValues(alpha: 0.12);
      glowColor = Colors.transparent;
      cardGradient = [
        const Color(0xFF1E293B).withValues(alpha: 0.8),
        const Color(0xFF0F172A).withValues(alpha: 0.8),
      ];
    }

    String emoji;
    String badgeText;
    double weightVal;
    double speedVal;
    double stabilityVal;

    switch (type) {
      case PenType.heavy:
        emoji = '🛡️';
        badgeText = 'HEAVYWEIGHT';
        weightVal = 0.90;
        speedVal = 0.55;
        stabilityVal = 0.95;
        break;
      case PenType.slim:
        emoji = '⚡';
        badgeText = 'AGILE';
        weightVal = 0.40;
        speedVal = 0.95;
        stabilityVal = 0.45;
        break;
      case PenType.balanced:
        emoji = '⚖️';
        badgeText = 'ALL-ROUND';
        weightVal = 0.65;
        speedVal = 0.75;
        stabilityVal = 0.70;
        break;
    }

    return AppCard(
      onTap: onTap,
      gradientColors: cardGradient,
      glowColor: glowColor,
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Emoji / Icon box
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? cardBorder : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details & Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        type.displayName,
                        style: AppTextStyles.heading.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: AppTextStyles.badge.copyWith(
                            fontSize: 8.5,
                            color: isSelected ? Colors.white : AppPalette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type.description,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),

                // Stat bars: Mass, Speed, Stability
                Row(
                  children: [
                    Expanded(child: _statBar('Mass', weightVal)),
                    const SizedBox(width: 8),
                    Expanded(child: _statBar('Speed', speedVal)),
                    const SizedBox(width: 8),
                    Expanded(child: _statBar('Stability', stabilityVal)),
                  ],
                ),
              ],
            ),
          ),

          // Radio Selection Check
          const SizedBox(width: 10),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? PenFightTheme.accentLight : Colors.transparent,
              border: Border.all(
                color: isSelected ? PenFightTheme.accentLight : Colors.white38,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _statBar(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 3.5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              value > 0.8
                  ? const Color(0xFF38BDF8)
                  : (value > 0.6 ? const Color(0xFF34D399) : const Color(0xFFFBBF24)),
            ),
          ),
        ),
      ],
    );
  }
}
