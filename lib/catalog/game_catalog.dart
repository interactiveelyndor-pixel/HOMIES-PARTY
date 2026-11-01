import 'package:flutter/material.dart';
import '../battleship/battleship_mode_select_screen.dart';
import '../carrom/carrom_mode_select_screen.dart';
import '../connect4/connect4_mode_select_screen.dart';
import '../pen_fight/pen_fight_mode_select_screen.dart';
import '../screens/ludo_mode_select_screen.dart';
import '../snl/snl_game_screen.dart';
import '../ui/app_palette.dart';
import '../would_you_rather/wyr_setup_screen.dart';

enum GameCategory { board, party }

/// One entry in the game catalogue. To add a game: append a [GameInfo] to
/// [GameCatalog.all] with its launch screen builder. Nothing else changes.
class GameInfo {
  final String id;
  final String title;
  final String emoji;
  final String badge;
  final String subtitle;
  final GameCategory category;
  final int minPlayers;
  final int maxPlayers;
  final bool hasComputerMode;

  /// Short rules shown on the details screen, one line each.
  final List<String> rules;

  /// Rough length of one game, e.g. '10-20 min' (an estimate, not a promise).
  final String duration;
  final Color accent;
  final List<Color> gradient;
  final Color glow;

  /// Small card art under assets/, or null to show [emoji] on the game colour.
  final String? art;

  /// Builds the game's existing entry screen (mode select or game screen).
  final Widget Function() launch;

  const GameInfo({
    required this.id,
    required this.title,
    required this.emoji,
    required this.badge,
    required this.subtitle,
    required this.category,
    required this.minPlayers,
    required this.maxPlayers,
    required this.hasComputerMode,
    required this.rules,
    required this.duration,
    required this.accent,
    required this.gradient,
    required this.glow,
    required this.launch,
    this.art,
  });
}

/// Single source of truth for the games shown in the app. All entries are
/// local (pass-and-play / vs computer); none supports online play yet.
class GameCatalog {
  GameCatalog._();

  static final List<GameInfo> all = [
    GameInfo(
      id: 'ludo',
      title: 'Ludo',
      emoji: '♟️',
      badge: 'STRATEGY',
      subtitle: '2–4 players · 4 tokens each\nRace all tokens home',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 4,
      hasComputerMode: true,
      accent: AppPalette.ludo,
      gradient: AppPalette.ludoGradient,
      glow: AppPalette.ludoGlow,
      rules: [
        'Roll a six to bring a token out of your base.',
        'Move a token clockwise by the number you roll.',
        'Landing on an opponent sends their token back to base.',
        'Get all four of your tokens home first to win.',
      ],
      duration: '10-30 min',
      launch: () => const LudoModeSelectScreen(),
      art: 'assets/images/small/ludo.webp',
    ),
    GameInfo(
      id: 'snl',
      title: 'Snakes & Ladders',
      emoji: '🐍',
      badge: 'CLASSIC',
      subtitle: '2–4 players · 1 token each\nBe first to reach 100',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 4,
      hasComputerMode: false,
      accent: AppPalette.snl,
      gradient: AppPalette.snlGradient,
      glow: AppPalette.snlGlow,
      rules: [
        'Take turns rolling the dice and moving your token.',
        'Ladders lift you up. Snakes slide you down.',
        'You need the exact roll to land on 100.',
        'First to reach 100 wins.',
      ],
      duration: '5-15 min',
      launch: () => const SnlGameScreen(),
      art: 'assets/images/small/snakes.webp',
    ),
    GameInfo(
      id: 'carrom',
      title: 'Carrom',
      emoji: '🎯',
      badge: 'PHYSICS',
      subtitle: '2 players · 9 coins each + Queen\nPocket & cover Queen to win',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 2,
      hasComputerMode: true,
      accent: AppPalette.carrom,
      gradient: AppPalette.carromGradient,
      glow: AppPalette.carromGlow,
      rules: [
        'Flick the striker to pocket your coins.',
        'Pocket the Queen, then cover it with one of your own coins.',
        'Clear all your coins to win.',
      ],
      duration: '10-20 min',
      launch: () => const CarromModeSelectScreen(),
      art: 'assets/images/small/carrom.webp',
    ),
    GameInfo(
      id: 'battleship',
      title: 'Battleship',
      emoji: '🚢',
      badge: 'RADAR DUEL',
      subtitle: '2 players · 4 ships each\nLocate and sink enemy fleet',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 2,
      hasComputerMode: true,
      accent: AppPalette.battleship,
      gradient: AppPalette.battleshipGradient,
      glow: AppPalette.battleshipGlow,
      rules: [
        'Place your four ships on the grid in secret.',
        'Take turns guessing a square on your opponent\'s grid.',
        'A hit lets you know a ship is there. Sink every ship to win.',
      ],
      duration: '10-15 min',
      launch: () => const BattleshipModeSelectScreen(),
      art: 'assets/images/small/battleship.webp',
    ),
    GameInfo(
      id: 'pen_fight',
      title: 'Pen Fight',
      emoji: '🖊️',
      badge: 'TABLETOP',
      subtitle: '2 players · Best of 3 rounds\nAim, flick & knock opponent off',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 2,
      hasComputerMode: true,
      accent: AppPalette.candy,
      gradient: [Color(0xFF8E3BFF), AppPalette.candy],
      glow: Color(0x40FF5C8A),
      rules: [
        'Aim and flick your pen to knock the other pen off the table.',
        'Best of three rounds wins.',
      ],
      duration: '3-5 min',
      launch: () => const PenFightModeSelectScreen(),
    ),
    GameInfo(
      id: 'connect4',
      title: 'Connect Four',
      emoji: '🔴',
      badge: 'STRATEGY',
      subtitle: '2 players, line up four discs',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 2,
      hasComputerMode: true,
      accent: AppPalette.sky,
      gradient: [Color(0xFF6D5BFF), AppPalette.sky],
      glow: Color(0x403DB8FF),
      rules: [
        'Take turns dropping a disc into a column.',
        'The first player to line up four in a row wins.',
        'Lines can run across, up and down, or diagonally.',
      ],
      duration: '3-8 min',
      launch: () => const ConnectFourModeSelectScreen(),
    ),
    GameInfo(
      id: 'wyr',
      title: 'Would You Rather',
      emoji: '🤔',
      badge: 'PARTY',
      subtitle: '2-8 players, one phone, secret votes',
      category: GameCategory.party,
      minPlayers: 2,
      maxPlayers: 8,
      hasComputerMode: false,
      accent: AppPalette.candy,
      gradient: [AppPalette.candy, Color(0xFFFFB400)],
      glow: Color(0x40FF5C8A),
      rules: [
        'Pass one phone around the group.',
        'Everyone votes in secret on a would-you-rather question.',
        'Then see how the group voted.',
      ],
      duration: '5-20 min',
      launch: () => const WyrSetupScreen(),
    ),
  ];

  static List<GameInfo> byCategory(GameCategory c) =>
      all.where((g) => g.category == c).toList();
}
