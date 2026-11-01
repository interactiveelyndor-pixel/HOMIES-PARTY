import 'package:flutter/material.dart';
import '../theme/ludo_colors.dart';

class RulesDialog extends StatelessWidget {
  const RulesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Classic Ludo Rules',
                      style: TextStyle(
                        color: LudoColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: LudoColors.textSecondary),
                    iconSize: 20,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              _ruleItem(
                icon: Icons.casino_rounded,
                title: 'Leaving Base',
                desc: 'A roll of 6 is required to move a token from the base to the start cell.',
              ),
              _ruleItem(
                icon: Icons.repeat_rounded,
                title: 'Extra Turns',
                desc:
                    'Rolling a 6, capturing an opponent token, or reaching HOME grants an extra turn. Rolling three 6s in a row forfeits the turn.',
              ),
              _ruleItem(
                icon: Icons.shield_rounded,
                title: 'Safe Cells',
                desc:
                    'Start cells and star cells (⭐) are safe. Multiple tokens can share a safe cell without being captured.',
              ),
              _ruleItem(
                icon: Icons.flash_on_rounded,
                title: 'Captures',
                desc:
                    'Landing on an opponent token on an ordinary cell captures it and sends it back to base.',
              ),
              _ruleItem(
                icon: Icons.flag_rounded,
                title: 'Entering Home & Winning',
                desc:
                    'An exact dice roll is required to enter the center HOME. The first player to bring all 4 tokens HOME wins!',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LudoColors.bluePrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: LudoColors.starGold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: LudoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: LudoColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
