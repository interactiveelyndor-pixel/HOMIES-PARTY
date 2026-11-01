import 'api_client.dart';
import 'auth_service.dart';
import 'models/user_profile.dart';
import 'socket_service.dart';

/// Signs in as a guest and opens the real-time connection. Safe to call
/// repeatedly: an existing connection is reused.
Future<UserProfile> connectOnline({
  ApiClient? api,
  AuthService? auth,
  SocketService? socket,
}) async {
  final profile = await (api ?? ApiClient()).authenticateGuest();
  final token = await (auth ?? AuthService()).getIdToken();
  await (socket ?? SocketService()).connect(token);
  return profile;
}
