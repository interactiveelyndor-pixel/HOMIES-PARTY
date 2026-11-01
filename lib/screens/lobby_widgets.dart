import 'package:flutter/material.dart';

import '../network/network.dart';
import '../profile/local_profile.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'online_game_router.dart';

/// One choice in the game picker: a sticker that turns yellow when chosen.
class GamePickTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const GamePickTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppPalette.ink : AppPalette.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppPalette.confetti : AppPalette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.ink, width: 2.5),
            boxShadow: selected
                ? const [BoxShadow(color: AppPalette.ink, offset: Offset(0, 3))]
                : null,
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyBold.copyWith(color: fg),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: selected ? AppPalette.ink : AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-column choice of what to play: every online game, plus Party Mode.
class GamePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const GamePicker({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final g in onlineGames)
        (
          id: g.id,
          emoji: g.emoji,
          title: g.title,
          subtitle: g.minPlayers == g.maxPlayers
              ? '${g.maxPlayers} players'
              : '${g.minPlayers}-${g.maxPlayers} players',
        ),
      (
        id: 'party',
        emoji: '🎉',
        title: 'Party',
        subtitle: 'A new game each round',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final o in options)
              SizedBox(
                width: w,
                child: GamePickTile(
                  key: Key('lobby_game_${o.id}'),
                  emoji: o.emoji,
                  title: o.title,
                  subtitle: o.subtitle,
                  selected: selected == o.id,
                  onTap: () => onSelect(o.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The waiting room's headline: the code to share, big, with what is being played.
class RoomTicket extends StatelessWidget {
  final String code;
  final String playing;
  final VoidCallback onCopy;
  const RoomTicket({
    super.key,
    required this.code,
    required this.playing,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.ink, width: 3),
        boxShadow: const [BoxShadow(color: AppPalette.ink, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(playing, key: const Key('room_playing'), style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          Text(
            'Send this code to your friends so they can join.',
            style: AppTextStyles.caption.copyWith(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Room code ${code.split('').join(' ')}',
            excludeSemantics: true,
            child: Row(
              key: const Key('room_code'),
              children: [
                for (var i = 0; i < code.length; i++)
                  Expanded(
                    child: Container(
                      height: 56,
                      margin: EdgeInsets.only(right: i == code.length - 1 ? 0 : 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.ink, width: 2.5),
                      ),
                      child: Text(
                        code[i],
                        style: AppTextStyles.title.copyWith(
                          color: AppPalette.ink,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const Key('room_copy'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.confetti,
                foregroundColor: AppPalette.ink,
                textStyle: AppTextStyles.button,
              ),
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text('Copy code'),
            ),
          ),
        ],
      ),
    );
  }
}


/// A player in the waiting room.
class PlayerSeat extends StatelessWidget {
  final RoomPlayer player;
  final int index;
  final bool isMe;
  final VoidCallback? onKick;
  const PlayerSeat({
    super.key,
    required this.player,
    required this.index,
    required this.isMe,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    final name = player.nickname.isEmpty ? 'Player' : player.nickname;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.ink, width: 2.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  avatarPresetOf(player.avatar)?.color ??
                  AppPalette.seatColors[index % AppPalette.seatColors.length],
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.ink, width: 2.5),
            ),
            child: ExcludeSemantics(
              child: avatarPresetOf(player.avatar) != null
                  ? Text(avatarPresetOf(player.avatar)!.emoji, style: const TextStyle(fontSize: 22))
                  : Text(
                      name.characters.first.toUpperCase(),
                      style: AppTextStyles.heading.copyWith(color: AppPalette.ink),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold,
                ),
                Text(
                  [if (isMe) 'You', if (player.isHost) 'Host'].join(' · '),
                  style: AppTextStyles.caption.copyWith(color: AppPalette.confetti),
                ),
              ],
            ),
          ),
          if (onKick != null)
            IconButton(
              key: Key('kick_${player.userId}'),
              tooltip: 'Remove $name',
              icon: const Icon(Icons.person_remove_rounded),
              onPressed: onKick,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: player.isReady ? AppPalette.mint : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: player.isReady ? AppPalette.ink : AppPalette.textMuted,
                width: 2,
              ),
            ),
            child: Text(
              player.isReady ? 'Ready' : 'Not ready',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: player.isReady ? AppPalette.ink : AppPalette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An open place at the table.
class EmptySeat extends StatelessWidget {
  const EmptySeat({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.glassBorderLight, width: 2),
      ),
      child: Text(
        'Waiting for a friend…',
        style: AppTextStyles.caption.copyWith(color: AppPalette.textMuted),
      ),
    );
  }
}

/// A small either-or choice (rounds, player count) in the same sticker style.
class PickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const PickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppPalette.confetti : AppPalette.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppPalette.ink, width: 2.5),
          ),
          // A Row sizes to its text; a Container with alignment would fill the line.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyBold.copyWith(
                  color: selected ? AppPalette.ink : AppPalette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
