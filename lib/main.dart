import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logic/ludo_controller.dart';
import 'network/auth_service.dart';
import 'profile/local_profile.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_flow.dart';
import 'screens/ludo_game_screen.dart';
import 'theme/ludo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    AuthService().setInitError(e.toString());
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final store = await LocalProfileStore.open();
  LocalProfileStore.current = store;
  runApp(ClassicBoardGamesApp(store: store, onboarded: store.profile.onboarded));
}

/// Root widget for the app — shows the home screen by default.
/// [ClassicLudoApp] is kept as a named export so existing Ludo widget tests
/// continue to work without any modification.
class ClassicBoardGamesApp extends StatefulWidget {
  /// Where the first-launch choices are kept. Null skips onboarding (tests).
  final LocalProfileStore? store;
  final bool onboarded;
  const ClassicBoardGamesApp({super.key, this.store, this.onboarded = true});

  @override
  State<ClassicBoardGamesApp> createState() => _ClassicBoardGamesAppState();
}

class _ClassicBoardGamesAppState extends State<ClassicBoardGamesApp> {
  late bool _onboarded = widget.onboarded || widget.store == null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homies: Party',
      debugShowCheckedModeBanner: false,
      theme: LudoTheme.darkTheme,
      home: _onboarded
          ? const AppShell()
          : OnboardingFlow(
              store: widget.store!,
              onDone: () => setState(() => _onboarded = true),
            ),
    );
  }
}

/// Kept for backward-compatibility with existing Ludo widget tests.
/// Do NOT modify this class.
class ClassicLudoApp extends StatelessWidget {
  final LudoController? controller;

  const ClassicLudoApp({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classic Ludo',
      debugShowCheckedModeBanner: false,
      theme: LudoTheme.darkTheme,
      home: LudoGameScreen(controller: controller),
    );
  }
}
