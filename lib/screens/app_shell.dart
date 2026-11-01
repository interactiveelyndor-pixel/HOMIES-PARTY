import 'package:flutter/material.dart';

import '../catalog/game_catalog.dart';
import '../catalog/game_tile.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import '../network/network.dart';
import 'consent_sheet.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'online_game_router.dart';
import 'play_widgets.dart';
import 'online_lobby_screen.dart';
import 'quick_match_screen.dart';
import 'social_screen.dart';

/// Bottom-navigation shell: Home, Games, Party, Friends, Profile. Only the active tab is built,
/// so inactive tabs hold no state or listeners.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const GamesScreen(),
      PlayScreen(onBrowseGames: () => setState(() => _index = 1)),
      const SocialScreen(),
      const AccountScreen(title: 'Profile'),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        key: const Key('app_nav_bar'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.casino_rounded),
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.celebration_rounded),
            label: 'Party',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_rounded),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Catalogue grouped by category. Party games have no entries yet.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Games', style: AppTextStyles.title),
            const SizedBox(height: 16),
            for (final c in GameCategory.values) ..._section(context, c),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, GameCategory c) {
    final games = GameCatalog.byCategory(c);
    return [
      Text(
        c == GameCategory.board ? 'Board Games' : 'Party Games',
        style: AppTextStyles.heading,
      ),
      const SizedBox(height: 10),
      if (games.isEmpty)
        Padding(
          key: Key('games_empty_${c.name}'),
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'Coming soon',
            style: AppTextStyles.body.copyWith(color: AppPalette.textSecondary),
          ),
        ),
      if (games.isNotEmpty) GameGrid(games: games, keyPrefix: 'games'),
      const SizedBox(height: 8),
    ];
  }
}

/// Lists only play options that actually work today.
class PlayScreen extends StatefulWidget {
  final VoidCallback onBrowseGames;

  /// Injectable for tests. Default: ask the server.
  final Future<AppConfig> Function()? loadConfig;
  final ApiClient? api;
  const PlayScreen({
    super.key,
    required this.onBrowseGames,
    this.loadConfig,
    this.api,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  /// Null until the server answers. Unknown counts as available: the server
  /// refuses Quick Match itself when it is switched off.
  bool? _quickMatchOn;

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    try {
      final c = await (widget.loadConfig ?? _api.getConfig)();
      if (mounted) setState(() => _quickMatchOn = c.publicDiscovery);
    } catch (_) {}
  }

  VoidCallback get onBrowseGames => widget.onBrowseGames;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Party', style: AppTextStyles.title),
            const SizedBox(height: 18),
            PartyInvite(
              onStart: () => Navigator.of(context).push(
                appPageRoute(const OnlineLobbyScreen(initialGame: 'party')),
              ),
            ),
            const SizedBox(height: 26),
            const Text('Got a code?', style: AppTextStyles.heading),
            const SizedBox(height: 10),
            RoomCodeField(
              onJoin: (code) => Navigator.of(context).push(
                appPageRoute(OnlineLobbyScreen(joinCode: code)),
              ),
            ),
            const SizedBox(height: 26),
            const Text('More ways to play', style: AppTextStyles.heading),
            const SizedBox(height: 10),
            _tile(
              key: 'play_local',
              icon: Icons.groups_rounded,
              title: 'Play on this device',
              subtitle: 'Pass the phone around, or play the computer',
              onTap: onBrowseGames,
            ),
            _tile(
              key: 'play_rooms',
              icon: Icons.meeting_room_rounded,
              title: 'Private room',
              subtitle: 'Pick one game and invite friends with a code',
              onTap: () =>
                  Navigator.of(context)
                      .push(appPageRoute(const OnlineLobbyScreen())),
            ),
            _tile(
              key: 'play_match',
              icon: Icons.person_search_rounded,
              title: 'Quick match',
              subtitle: _quickMatchOn == false
                  ? 'Not available right now. Play with friends in a private room.'
                  : 'Get paired with another player online',
              onTap: _quickMatchOn == false ? null : () => _pickGame(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGame(BuildContext context) async {
    final game = await showModalBottomSheet<OnlineGame>(
      context: context,
      backgroundColor: AppPalette.backgroundElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pick a game', style: AppTextStyles.title),
            ),
            for (final g in onlineGames.where((g) => !g.privateOnly))
              ListTile(
                key: Key('qm_pick_${g.id}'),
                title: Text(g.title, style: AppTextStyles.heading),
                subtitle: Text(
                  g.minPlayers == g.maxPlayers
                      ? '${g.maxPlayers} players'
                      : '${g.minPlayers}-${g.maxPlayers} players',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, g),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (game != null && context.mounted) {
      if (!await ensureConsent(context, _api) || !context.mounted) return;
      await Navigator.of(context)
          .push(appPageRoute(QuickMatchScreen(game: game)));
    }
  }

  Widget _tile({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      key: Key(key),
      color: AppPalette.glassSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: onTap != null,
        leading: Icon(icon),
        title: Text(title, style: AppTextStyles.bodyBold),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
