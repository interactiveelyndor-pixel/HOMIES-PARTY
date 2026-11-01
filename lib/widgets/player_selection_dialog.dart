import 'package:flutter/material.dart';
import '../models/player_color.dart';
import '../theme/ludo_colors.dart';
import '../theme/ludo_theme.dart';

/// Callback when the user confirms a mode selection.
/// [count] is the player count; [vsComputer] is true when the user picks
/// "vs Computer" (only valid for 2-player mode).
typedef OnModeSelected = void Function(int count, {bool vsComputer});

class PlayerSelectionDialog extends StatefulWidget {
  final int currentCount;
  final bool currentVsComputer;
  final OnModeSelected onSelectMode;

  /// Legacy convenience constructor — keeps the old [onSelectCount] signature
  /// working so tests and callers that have not been updated continue to compile.
  const PlayerSelectionDialog({
    super.key,
    required this.currentCount,
    this.currentVsComputer = false,
    required this.onSelectMode,
  });

  @override
  State<PlayerSelectionDialog> createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  late int _selectedCount;
  late bool _vsComputer;

  @override
  void initState() {
    super.initState();
    _selectedCount = widget.currentCount;
    _vsComputer = widget.currentVsComputer;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Players',
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
            const SizedBox(height: 10),

            // ── Player count options ─────────────────────────────────────────
            _buildOption(
              context,
              count: 2,
              title: '2 Players',
              subtitle: 'Red vs Yellow (Classic Opposites)',
              colors: [PlayerColor.red, PlayerColor.yellow],
            ),
            const SizedBox(height: 8),
            _buildOption(
              context,
              count: 3,
              title: '3 Players',
              subtitle: 'Red, Green & Yellow',
              colors: [PlayerColor.red, PlayerColor.green, PlayerColor.yellow],
            ),
            const SizedBox(height: 8),
            _buildOption(
              context,
              count: 4,
              title: '4 Players',
              subtitle: 'Red, Green, Yellow & Blue',
              colors: [
                PlayerColor.red,
                PlayerColor.green,
                PlayerColor.yellow,
                PlayerColor.blue,
              ],
            ),

            // ── vs Computer toggle (only for 2-player) ───────────────────────
            if (_selectedCount == 2) ...[
              const SizedBox(height: 14),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
              _buildModeToggle(),
            ],

            // ── Confirm button ───────────────────────────────────────────────
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('player_mode_confirm'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSelectMode(
                    _selectedCount,
                    vsComputer: _selectedCount == 2 && _vsComputer,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LudoColors.bluePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Mode',
          style: TextStyle(
            color: LudoColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildModeChip(
              key: const Key('mode_friends'),
              label: 'Friends',
              icon: Icons.people_rounded,
              selected: !_vsComputer,
              onTap: () => setState(() => _vsComputer = false),
            ),
            const SizedBox(width: 8),
            _buildModeChip(
              key: const Key('mode_vs_computer'),
              label: 'vs Computer',
              icon: Icons.computer_rounded,
              selected: _vsComputer,
              onTap: () => setState(() => _vsComputer = true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? LudoColors.bluePrimary.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? LudoColors.bluePrimary : Colors.white12,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : LudoColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : LudoColors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required int count,
    required String title,
    required String subtitle,
    required List<PlayerColor> colors,
  }) {
    final isSelected = _selectedCount == count;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCount = count;
          // Reset vs computer when switching away from 2-player.
          if (count != 2) _vsComputer = false;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? LudoColors.bluePrimary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? LudoColors.bluePrimary : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : LudoColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: LudoColors.textSecondary,
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: colors.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LudoTheme.getPrimary(c),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
