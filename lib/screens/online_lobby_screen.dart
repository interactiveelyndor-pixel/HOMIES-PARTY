import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/network.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import '../profile/local_profile.dart';
import 'consent_sheet.dart';
import 'lobby_widgets.dart';
import 'play_widgets.dart';
import 'online_game_router.dart';

/// Minimal standalone Online Lobby screen establishing the Flutter-to-backend foundation.
/// Provides room creation, joining, ready states, and live Socket.IO room sync.
class OnlineLobbyScreen extends StatefulWidget {
  /// Game to preselect when creating a room; null keeps the default.
  final String? initialGame;

  /// A room code to join as soon as the player is signed in and has agreed to the rules.
  final String? joinCode;
  const OnlineLobbyScreen({super.key, this.initialGame, this.joinCode});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _apiClient = ApiClient();
  final _authService = AuthService();
  final _socketService = SocketService();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  UserProfile? _userProfile;
  Room? _currentRoom;
  int _selectedMaxPlayers = 4;
  late String _selectedGame =
      widget.initialGame == 'party' ||
          onlineGames.any((g) => g.id == widget.initialGame)
      ? widget.initialGame!
      : 'snl';

  /// Party Mode: the server picks a random game each round.
  bool get _isParty => _selectedGame == 'party';
  int _partyRounds = 3;

  StreamSubscription<Room>? _roomUpdatedSub;
  StreamSubscription<Room>? _roomStartedSub;
  StreamSubscription<RoomGone>? _roomGoneSub;
  StreamSubscription<bool>? _socketConnSub;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _roomUpdatedSub?.cancel();
    _roomStartedSub?.cancel();
    _roomGoneSub?.cancel();
    _socketConnSub?.cancel();
    _codeController.dispose();
    if (_currentRoom != null) {
      _socketService.unsubscribeFromRoom(_currentRoom!.code);
    }
    super.dispose();
  }

  void _setupSocketListeners() {
    _roomUpdatedSub = _socketService.onRoomUpdated.listen((updatedRoom) {
      if (!mounted) return;
      if (_currentRoom != null && _currentRoom!.code == updatedRoom.code) {
        setState(() {
          _currentRoom = updatedRoom;
        });
      }
    });

    _roomGoneSub = _socketService.onRoomGone.listen((gone) {
      if (!mounted || _currentRoom?.code != gone.code) return;
      setState(() => _currentRoom = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gone.kicked
                ? 'The host removed you from the room.'
                : 'That room expired because the game never started.',
          ),
        ),
      );
    });

    _roomStartedSub = _socketService.onRoomStarted.listen((startedRoom) {
      if (!mounted) return;
      if (_currentRoom != null && _currentRoom!.code == startedRoom.code) {
        setState(() {
          _currentRoom = startedRoom;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The host has started the game!'),
            backgroundColor: AppPalette.success,
          ),
        );
        final me = _userProfile?.id;
        final screen = me == null ? null : onlineGameScreen(startedRoom, me);
        if (screen != null) {
          Navigator.of(context).push(appPageRoute(screen));
        }
      }
    });

    _socketConnSub = _socketService.onConnectionStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var profile = await _apiClient.authenticateGuest();
      // Send the name and avatar picked at first launch, then show them.
      if (await syncLocalProfile(_apiClient)) profile = await _apiClient.getProfile();
      final token = await _authService.getIdToken();
      await _socketService.connect(token);
      if (!mounted) return;
      if (!await ensureConsent(context, _apiClient)) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
      final code = widget.joinCode;
      if (mounted && code != null && _currentRoom == null) {
        _codeController.text = code;
        await _joinRoom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _describe(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Plain words for the player, never the exception's class name and status code.
  String _describe(Object e) => e is ApiException
      ? e.message
      : 'Could not reach the game server. Check your connection and try again.';

  OnlineGame get _selectedOnlineGame => onlineGames.firstWhere(
    (g) => g.id == _selectedGame,
    orElse: () => onlineGames.first,
  );

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await _apiClient.createRoom(
        party: _isParty,
        rounds: _isParty ? _partyRounds : null,
        gameType: _isParty ? null : _selectedGame,
        // Games with a player range let the host pick; the others fix their size.
        maxPlayers: _isParty
            ? null
            : _selectedOnlineGame.minPlayers != _selectedOnlineGame.maxPlayers
            ? _selectedMaxPlayers
            : null,
      );
      await _socketService.subscribeToRoom(room.code);

      if (mounted) {
        setState(() {
          _currentRoom = room;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _describe(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid room code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await _apiClient.joinRoom(code);
      await _socketService.subscribeToRoom(room.code);

      if (mounted) {
        _codeController.clear();
        setState(() {
          _currentRoom = room;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _describe(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleReady() async {
    if (_currentRoom == null || _userProfile == null) return;
    final myPlayer = _currentRoom!.getPlayer(_userProfile!.id);
    final nextReady = !(myPlayer?.isReady ?? false);

    setState(() => _isLoading = true);
    try {
      final updatedRoom = await _apiClient.setReady(
        _currentRoom!.code,
        nextReady,
      );
      if (mounted) {
        setState(() {
          _currentRoom = updatedRoom;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _describe(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _leaveRoom() async {
    if (_currentRoom == null) return;
    final code = _currentRoom!.code;

    setState(() => _isLoading = true);
    try {
      await _socketService.unsubscribeFromRoom(code);
      await _apiClient.leaveRoom(code);

      if (mounted) {
        setState(() {
          _currentRoom = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentRoom = null;
          _errorMessage = _describe(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _kick(String code, RoomPlayer player) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${player.nickname}?'),
        content: const Text('They cannot rejoin this room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('kick_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final room = await _apiClient.kickPlayer(code, player.userId);
      if (mounted) setState(() => _currentRoom = room);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not remove them.'),
          ),
        );
      }
    }
  }

  Future<void> _startRoom() async {
    if (_currentRoom == null) return;

    setState(() => _isLoading = true);
    try {
      final updatedRoom = await _apiClient.startRoom(_currentRoom!.code);
      if (mounted) {
        setState(() {
          _currentRoom = updatedRoom;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _describe(e);
          _isLoading = false;
        });
      }
    }
  }

  void _showConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.backgroundElevated,
        title: const Text(
          'Backend URL Configuration',
          style: AppTextStyles.heading,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure the server IP or tunnel address:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: AppTextStyles.bodyBold,
              decoration: const InputDecoration(
                hintText: 'e.g. http://192.168.1.100:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Windows: http://127.0.0.1:3000\n'
              'Android Emulator: http://10.0.2.2:3000\n'
              'Physical Device: LAN IP (e.g. 192.168.x.x:3000)',
              style: AppTextStyles.caption.copyWith(
                color: AppPalette.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.setBaseUrl(controller.text);
              Navigator.of(ctx).pop();
              _initializeUser();
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundTop,
      appBar: AppBar(
        backgroundColor: AppPalette.backgroundTop,
        elevation: 0,
        title: const Text(
          'Play online',
          style: AppTextStyles.heading,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppPalette.textSecondary,
            ),
            tooltip: 'Configure Backend URL',
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: _currentRoom != null
              ? _buildRoomView()
              : _buildLobbyOverview(),
        ),
      ),
    );
  }

  Widget _buildLobbyOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection & Profile Status Card
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppPalette.ludo.withValues(alpha: 0.2),
                  child: const Text('🎮', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userProfile?.nickname ?? 'Connecting...',
                        style: AppTextStyles.heading,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _socketService.isConnected
                                  ? AppPalette.success
                                  : AppPalette.warning,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _socketService.isConnected
                                  ? 'Real-time connected'
                                  : 'Offline / Connecting',
                              style: AppTextStyles.caption.copyWith(
                                color: AppPalette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: AppPalette.textSecondary,
                    ),
                    tooltip: 'Reconnect Profile',
                    onPressed: _initializeUser,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppPalette.danger.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppPalette.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.body.copyWith(
                        color: AppPalette.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 1. Create Room Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('✨', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Create a Room', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a private room and share the 6-character code with your friends.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                const Text('What do you want to play?', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                GamePicker(
                  selected: _selectedGame,
                  onSelect: (id) => setState(() => _selectedGame = id),
                ),
                const SizedBox(height: 14),
                if (_isParty) ...[
                  const Text('Rounds:', style: AppTextStyles.subheading),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in [3, 5, 7])
                        PickChip(
                          key: Key('party_rounds_$n'),
                          label: '$n rounds',
                          selected: _partyRounds == n,
                          onTap: () => setState(() => _partyRounds = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                if (!_isParty &&
                    _selectedOnlineGame.minPlayers !=
                    _selectedOnlineGame.maxPlayers) ...[
                  const Text('Max Players:', style: AppTextStyles.subheading),
                  const SizedBox(height: 8),
                  Row(
                    children: [2, 3, 4]
                        .where((c) => c >= _selectedOnlineGame.minPlayers)
                        .map((count) {
                      final selected = _selectedMaxPlayers == count;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PickChip(
                          key: Key('max_players_$count'),
                          label: '$count players',
                          selected: selected,
                          onTap: () =>
                              setState(() => _selectedMaxPlayers = count),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    key: const Key('lobby_create'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.confetti,
                      foregroundColor: AppPalette.ink,
                      textStyle: AppTextStyles.button,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_isParty ? 'Start party room' : 'Create room'),
                    onPressed: _isLoading ? null : _createRoom,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Join Room Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🔑', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Join Room', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the 6-character code shared by the host to join.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                RoomCodeField(
                  onJoin: (code) {
                    _codeController.text = code;
                    _joinRoom();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Backend connection info footer
          Center(
            child: TextButton.icon(
              icon: const Icon(
                Icons.wifi,
                size: 16,
                color: AppPalette.textMuted,
              ),
              label: Text(
                'Server: ${ApiConfig.baseUrl}',
                style: AppTextStyles.caption.copyWith(
                  color: AppPalette.textMuted,
                ),
              ),
              onPressed: _showConfigDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomView() {
    final room = _currentRoom!;
    final myUserId = _userProfile?.id ?? '';
    final isHost = room.isUserHost(myUserId);
    final myPlayer = room.getPlayer(myUserId);
    final isReady = myPlayer?.isReady ?? false;
    final canStart =
        isHost &&
        room.players.length >= 2 &&
        room.players.every((p) => p.isReady);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The code to share, then who is here
          RoomTicket(
            code: room.code,
            playing: room.party != null
                ? '🎉 Party · ${(room.party!['rounds'] as num?)?.toInt() ?? 0} rounds, a new game each time'
                : onlineGames.firstWhere(
                    (g) => g.id == room.gameType,
                    orElse: () => onlineGames.first,
                  ).title,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: room.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room code copied')),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            '${room.players.length} of ${room.maxPlayers} players',
            key: const Key('room_count'),
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < room.players.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PlayerSeat(
                      player: room.players[i],
                      index: i,
                      isMe: room.players[i].userId == myUserId,
                      onKick:
                          isHost &&
                              room.players[i].userId != myUserId &&
                              room.status == 'lobby'
                          ? () => _kick(room.code, room.players[i])
                          : null,
                    ),
                  ),
                for (var i = room.players.length; i < room.maxPlayers; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: EmptySeat(),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppPalette.danger, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppPalette.danger),
                  ),
                  icon: const Icon(Icons.exit_to_app, color: AppPalette.danger),
                  label: const Text(
                    'Leave',
                    style: TextStyle(color: AppPalette.danger),
                  ),
                  onPressed: _isLoading ? null : _leaveRoom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReady
                        ? AppPalette.panel
                        : AppPalette.mint,
                    foregroundColor: isReady
                        ? AppPalette.textPrimary
                        : AppPalette.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(isReady ? Icons.close : Icons.check),
                  label: Text(
                    isReady ? 'Not ready' : 'I\'m ready',
                    style: AppTextStyles.button,
                  ),
                  onPressed: _isLoading ? null : _toggleReady,
                ),
              ),
            ],
          ),

          if ((room.isPlaying || room.isFinished) &&
              onlineGameScreen(room, myUserId) != null) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const Key('lobby_return_to_game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.sports_esports),
              label: const Text('Return to game', style: AppTextStyles.button),
              onPressed: () =>
                  Navigator.of(context)
                      .push(appPageRoute(onlineGameScreen(room, myUserId)!)),
            ),
          ],

          if (isHost) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart
                    ? AppPalette.confetti
                    : AppPalette.textMuted.withValues(alpha: 0.3),
                foregroundColor: canStart ? AppPalette.ink : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                canStart ? 'Start game' : 'Waiting for everyone to be ready',
                style: AppTextStyles.button,
              ),
              onPressed: canStart && !_isLoading ? _startRoom : null,
            ),
          ],
        ],
      ),
    );
  }
}
