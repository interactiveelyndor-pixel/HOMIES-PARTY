import 'package:flutter/material.dart';

import '../network/network.dart';
import 'online_connect4_screen.dart';
import 'online_bluff_screen.dart';
import 'online_ludo_screen.dart';
import 'online_wordrush_screen.dart';
import 'online_snl_screen.dart';
import 'party_screen.dart';

/// A game the server can run online.
class OnlineGame {
  final String id; // the room's game_type
  final String title;
  final int minPlayers;
  final int maxPlayers;

  /// Players write text others see, so it is never offered for Quick Match.
  final bool privateOnly;
  final String emoji;
  const OnlineGame(
    this.id,
    this.title,
    this.minPlayers,
    this.maxPlayers, {
    this.privateOnly = false,
    this.emoji = '🎮',
  });
}

/// Games that support online play. Keep in step with server/src/games/registry.ts.
const onlineGames = [
  OnlineGame('ludo', 'Ludo', 2, 4, emoji: '♟️'),
  OnlineGame('snl', 'Snakes & Ladders', 2, 4, emoji: '🐍'),
  OnlineGame('connect4', 'Connect Four', 2, 2, emoji: '🔴'),
  OnlineGame('wordrush', 'Word Rush', 2, 4, emoji: '🔤'),
  OnlineGame('bluff', 'Bluff & Vote', 3, 4, privateOnly: true, emoji: '🤥'),
];

/// The screen for a room's running game, or null if this app version does not
/// know the game or the room has no game state yet.
Widget? onlineGameScreen(Room room, String myUserId) {
  if (room.gameState == null) return null;
  if (room.party != null) return PartyScreen(room: room, myUserId: myUserId);
  return onlineRoundScreen(room, myUserId);
}

/// The game screen alone, without any party scoreboard.
Widget? onlineRoundScreen(Room room, String myUserId) {
  if (room.gameState == null) return null;
  switch (room.gameType) {
    case 'snl':
      return OnlineSnlScreen(room: room, myUserId: myUserId);
    case 'connect4':
      return OnlineConnectFourScreen(room: room, myUserId: myUserId);
    case 'ludo':
      return OnlineLudoScreen(room: room, myUserId: myUserId);
    case 'wordrush':
      return OnlineWordRushScreen(room: room, myUserId: myUserId);
    case 'bluff':
      return OnlineBluffScreen(room: room, myUserId: myUserId);
  }
  return null;
}
