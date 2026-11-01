import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';
import 'api_config.dart';
import 'models/room.dart';
import 'match_search.dart';
import 'online_game_session.dart';

/// Service managing real-time Socket.IO communication with the backend.
class SocketService implements GameSocket, MatchSocket {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;

  final _connectionStateController = StreamController<bool>.broadcast();
  final _roomUpdatedController = StreamController<Room>.broadcast();
  final _roomGoneController = StreamController<RoomGone>.broadcast();
  final _roomStartedController = StreamController<Room>.broadcast();
  final _gameStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _matchFoundController = StreamController<Room>.broadcast();
  final _matchEndController = StreamController<ApiException>.broadcast();

  bool get isConnected => _isConnected;
  @override
  Stream<bool> get onConnectionStateChanged =>
      _connectionStateController.stream;
  Stream<Room> get onRoomUpdated => _roomUpdatedController.stream;

  /// The host removed this player, or the room expired.
  Stream<RoomGone> get onRoomGone => _roomGoneController.stream;
  Stream<Room> get onRoomStarted => _roomStartedController.stream;

  /// Emits `{code, state}` whenever the server applies a game move.
  @override
  Stream<Map<String, dynamic>> get onGameState => _gameStateController.stream;

  /// Connects to the backend Socket.IO server using the provided Firebase ID token.
  Future<void> connect(String token) async {
    if (_socket != null && _isConnected) {
      return;
    }

    disconnect();

    final completer = Completer<void>();

    final options = io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setReconnectionAttempts(5)
        .setAuth({'token': token})
        .build();

    _socket = io.io(ApiConfig.baseUrl, options);

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionStateController.add(true);
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionStateController.add(false);
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _connectionStateController.add(false);
      if (!completer.isCompleted) {
        completer.completeError(
          ApiException(
            statusCode: 401,
            error: 'SocketConnectError',
            message: err.toString(),
          ),
        );
      }
    });

    // Listen for room updates
    _socket!.on('room:updated', (data) {
      if (data is Map<String, dynamic>) {
        final room = Room.fromJson(data);
        _roomUpdatedController.add(room);
      }
    });

    for (final kicked in [true, false]) {
      _socket!.on(kicked ? 'room:kicked' : 'room:closed', (data) {
        if (data is Map && data['code'] is String) {
          _roomGoneController.add(RoomGone('${data['code']}', kicked: kicked));
        }
      });
    }

    // Listen for game start
    _socket!.on('room:started', (data) {
      if (data is Map<String, dynamic>) {
        final room = Room.fromJson(data);
        _roomStartedController.add(room);
      }
    });

    _socket!.on('game:reaction', (data) {
      if (data is Map) {
        _reactionController.add(Map<String, dynamic>.from(data));
      }
    });

    // Quick Match results
    _socket!.on('match:found', (data) {
      if (data is Map && data['room'] is Map) {
        _matchFoundController.add(
          Room.fromJson(Map<String, dynamic>.from(data['room'] as Map)),
        );
      }
    });
    _socket!.on('match:timeout', (_) {
      _matchEndController.add(
        const ApiException(
          statusCode: 408,
          error: 'Timeout',
          message: 'No one else is searching for this game right now.',
        ),
      );
    });
    _socket!.on('match:error', (data) {
      _matchEndController.add(
        ApiException(
          statusCode: 500,
          error: 'MatchError',
          message: data is Map
              ? '${data['message'] ?? 'Could not start the match.'}'
              : 'Could not start the match.',
        ),
      );
    });

    _socket!.on('game:state', (data) {
      if (data is Map) {
        _gameStateController.add(Map<String, dynamic>.from(data));
      }
    });

    // Timeout if connection doesn't establish
    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.completeError(
          const ApiException(
            statusCode: 408,
            error: 'ConnectionTimeout',
            message: 'Timed out connecting to real-time server.',
          ),
        );
      }
    });

    return completer.future;
  }

  /// Subscribes to room updates via Socket.IO for the given room [code].
  ///
  /// Returns the current [Room] state received in the server acknowledgement.
  @override
  Future<Room> subscribeToRoom(String code) {
    final completer = Completer<Room>();
    if (_socket == null || !_isConnected) {
      completer.completeError(
        const ApiException(
          statusCode: 503,
          error: 'NotConnected',
          message: 'Socket is not connected to the real-time server.',
        ),
      );
      return completer.future;
    }

    _socket!.emitWithAck(
      'room:subscribe',
      {'code': code.trim().toUpperCase()},
      ack: (response) {
        if (response is Map) {
          final map = Map<String, dynamic>.from(response);
          if (map.containsKey('error')) {
            completer.completeError(
              ApiException(
                statusCode: map['error'] == 'Forbidden'
                    ? 403
                    : (map['error'] == 'Not Found' ? 404 : 400),
                error: map['error'].toString(),
                message: map['message']?.toString() ?? 'Subscription failed',
              ),
            );
            return;
          }

          final roomData = map['room'] is Map<String, dynamic>
              ? map['room'] as Map<String, dynamic>
              : map;

          completer.complete(Room.fromJson(roomData));
        } else {
          completer.completeError(
            const ApiException(
              statusCode: 500,
              error: 'InvalidResponse',
              message: 'Invalid room:subscribe acknowledgement response.',
            ),
          );
        }
      },
    );

    return completer.future;
  }

  /// Asks the server to roll the dice for the current user in room [code].
  /// The result arrives on [onGameState]; throws [ApiException] if rejected.
  @override
  Future<void> rollDice(String code, {int? expectedRevision}) =>
      _gameAction('game:roll', code, {'expectedRevision': ?expectedRevision});

  /// Sends a game-specific move, e.g. `{'column': 3}` in Connect Four.
  @override
  Future<void> move(
    String code,
    Map<String, dynamic> input, {
    int? expectedRevision,
  }) => _gameAction('game:move', code, {
    'move': input,
    'expectedRevision': ?expectedRevision,
  });

  /// Reports that the current turn's deadline passed; the server verifies it.
  @override
  Future<void> skipTurn(String code) => _gameAction('game:skip', code);

  @override
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;

  /// Sends one of the fixed reactions to the other players in the room.
  @override
  Future<void> react(String code, String emoji) =>
      _gameAction('game:react', code, {'emoji': emoji});

  /// Starts a new game in a finished room.
  @override
  Future<void> rematch(String code) => _gameAction('game:rematch', code);

  Future<void> _gameAction(
    String event,
    String code, [
    Map<String, dynamic> extra = const {},
  ]) {
    final completer = Completer<void>();
    if (_socket == null || !_isConnected) {
      completer.completeError(
        const ApiException(
          statusCode: 503,
          error: 'NotConnected',
          message: 'Not connected to the real-time server.',
        ),
      );
      return completer.future;
    }
    _socket!.emitWithAck(
      event,
      {'code': code.trim().toUpperCase(), ...extra},
      ack: (response) {
        if (completer.isCompleted) return;
        if (response is Map && response['success'] == true) {
          completer.complete();
        } else {
          completer.completeError(
            ApiException(
              statusCode: 409,
              error: response is Map
                  ? '${response['error']}'
                  : 'InvalidResponse',
              message: response is Map
                  ? '${response['message'] ?? 'Roll rejected'}'
                  : 'Invalid response',
              code: response is Map ? response['code'] as String? : null,
            ),
          );
        }
      },
    );
    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.completeError(
          const ApiException(
            statusCode: 408,
            error: 'Timeout',
            message: 'The server did not answer the roll.',
          ),
        );
      }
    });
    return completer.future;
  }

  /// Starts looking for another player who picked [gameType].
  @override
  MatchSearch findMatch(String gameType) {
    final completer = Completer<Room>();
    late final StreamSubscription<Room> found;
    late final StreamSubscription<ApiException> ended;
    void finish() {
      found.cancel();
      ended.cancel();
    }

    void fail(Object error) {
      if (!completer.isCompleted) completer.completeError(error);
      finish();
    }

    found = _matchFoundController.stream.listen((room) {
      if (!completer.isCompleted) completer.complete(room);
      finish();
    });
    ended = _matchEndController.stream.listen(fail);

    if (_socket == null || !_isConnected) {
      scheduleMicrotask(
        () => fail(
          const ApiException(
            statusCode: 503,
            error: 'NotConnected',
            message: 'Not connected to the real-time server.',
          ),
        ),
      );
    } else {
      _socket!.emitWithAck(
        'match:join',
        {'gameType': gameType},
        ack: (res) {
          if (res is Map && res['error'] != null) {
            fail(
              ApiException(
                statusCode: res['error'] == 'Too Many Requests' ? 429 : 400,
                error: '${res['error']}',
                message: '${res['message'] ?? 'Could not start matchmaking.'}',
              ),
            );
          }
        },
      );
    }

    return MatchSearch(completer.future, () {
      _socket?.emit('match:cancel', {});
      fail(const MatchCancelled());
    });
  }

  /// Unsubscribes from room events for [code].
  Future<void> unsubscribeFromRoom(String code) {
    final completer = Completer<void>();
    if (_socket == null || !_isConnected) {
      completer.complete();
      return completer.future;
    }

    _socket!.emitWithAck(
      'room:unsubscribe',
      {'code': code.trim().toUpperCase()},
      ack: (_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    // Ensure future completes even if server doesn't ack
    Future.delayed(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Disconnects the socket and resets connection state.
  void disconnect() {
    if (_socket != null) {
      try {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
    _isConnected = false;
    _connectionStateController.add(false);
  }
}

/// A room this player was in is no longer available to them.
class RoomGone {
  final String code;

  /// True when the host removed them; false when the room expired.
  final bool kicked;
  const RoomGone(this.code, {required this.kicked});
}
