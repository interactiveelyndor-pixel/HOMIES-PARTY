import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/network/network.dart';

void main() {
  group('ApiConfig Tests', () {
    test('Default base URL is properly structured and ends without trailing slash', () {
      final defaultUrl = ApiConfig.defaultBaseUrl;
      expect(defaultUrl.startsWith('http://'), isTrue);
      expect(defaultUrl.endsWith('/'), isFalse);
    });

    test('Custom base URL override works and strips trailing slashes', () {
      ApiConfig.setBaseUrl('http://192.168.1.150:3000/');
      expect(ApiConfig.baseUrl, 'http://192.168.1.150:3000');
      expect(ApiConfig.roomsUrl, 'http://192.168.1.150:3000/v1/rooms');
      expect(ApiConfig.roomDetailsUrl('ABC234'), 'http://192.168.1.150:3000/v1/rooms/ABC234');
      expect(ApiConfig.roomReadyUrl('ABC234'), 'http://192.168.1.150:3000/v1/rooms/ABC234/ready');
      expect(ApiConfig.roomLeaveUrl('ABC234'), 'http://192.168.1.150:3000/v1/rooms/ABC234/leave');
      expect(ApiConfig.roomStartUrl('ABC234'), 'http://192.168.1.150:3000/v1/rooms/ABC234/start');
    });
  });

  group('Network Models Deserialization Tests', () {
    test('UserProfile parses backend payload correctly', () {
      final json = {
        'id': 'user-123',
        'firebase_uid': 'firebase-abc',
        'nickname': 'Guest4567',
        'avatar': 'avatar1',
        'created_at': '2026-10-23T01:30:00.000Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, 'user-123');
      expect(profile.firebaseUid, 'firebase-abc');
      expect(profile.nickname, 'Guest4567');
      expect(profile.avatar, 'avatar1');
      expect(profile.createdAt.isUtc, isTrue);

      final encoded = profile.toJson();
      expect(encoded['id'], 'user-123');
      expect(encoded['nickname'], 'Guest4567');
    });

    test('Room and RoomPlayer parse full room state correctly', () {
      final json = {
        'id': 'room-uuid-1',
        'code': 'L4L5GQ',
        'hostUserId': 'host-uuid-1',
        'status': 'lobby',
        'maxPlayers': 4,
        'createdAt': '2026-10-23T02:00:00.000Z',
        'players': [
          {
            'id': 'host-uuid-1',
            'userId': 'host-uuid-1',
            'nickname': 'HostPlayer',
            'avatar': null,
            'isReady': true,
            'isHost': true,
            'joinedAt': '2026-10-23T02:00:00.000Z',
          },
          {
            'id': 'guest-uuid-2',
            'userId': 'guest-uuid-2',
            'nickname': 'GuestPlayer',
            'avatar': 'avatar_dog',
            'isReady': false,
            'isHost': false,
            'joinedAt': '2026-10-23T02:01:00.000Z',
          }
        ],
      };

      final room = Room.fromJson(json);
      expect(room.id, 'room-uuid-1');
      expect(room.code, 'L4L5GQ');
      expect(room.isLobby, isTrue);
      expect(room.isPlaying, isFalse);
      expect(room.isFull, isFalse);
      expect(room.isUserHost('host-uuid-1'), isTrue);
      expect(room.isUserHost('guest-uuid-2'), isFalse);
      expect(room.players.length, 2);

      final player1 = room.getPlayer('host-uuid-1');
      expect(player1, isNotNull);
      expect(player1!.isHost, isTrue);
      expect(player1.isReady, isTrue);

      final player2 = room.getPlayer('guest-uuid-2');
      expect(player2, isNotNull);
      expect(player2!.isHost, isFalse);
      expect(player2.isReady, isFalse);
    });

    test('LeaveRoomResult parses both roomDeleted true and false correctly', () {
      final deletedJson = {
        'message': 'Room was deleted because it became empty.',
        'roomDeleted': true,
      };
      final deletedResult = LeaveRoomResult.fromJson(deletedJson);
      expect(deletedResult.roomDeleted, isTrue);
      expect(deletedResult.room, isNull);

      final transferredJson = {
        'message': 'Left room successfully.',
        'roomDeleted': false,
        'newHostAssigned': true,
        'room': {
          'id': 'room-uuid-1',
          'code': 'L4L5GQ',
          'hostUserId': 'guest-uuid-2',
          'status': 'lobby',
          'maxPlayers': 4,
          'players': [],
        },
      };
      final transferredResult = LeaveRoomResult.fromJson(transferredJson);
      expect(transferredResult.roomDeleted, isFalse);
      expect(transferredResult.newHostAssigned, isTrue);
      expect(transferredResult.room, isNotNull);
      expect(transferredResult.room!.hostUserId, 'guest-uuid-2');
    });
  });

  group('SocketService & AuthService Instances', () {
    test('Services provide singleton access', () {
      final socket1 = SocketService();
      final socket2 = SocketService();
      expect(identical(socket1, socket2), isTrue);

      final auth1 = AuthService();
      final auth2 = AuthService();
      expect(identical(auth1, auth2), isTrue);
    });

    test('AuthService tracks initialization error and throws AuthException', () async {
      final auth = AuthService();
      auth.signOut();
      auth.setInitError('Test Firebase initialization failure');
      expect(auth.initError, 'Test Firebase initialization failure');

      expect(
        () => auth.getIdToken(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Test Firebase initialization failure'),
          ),
        ),
      );
    });
  });
}
