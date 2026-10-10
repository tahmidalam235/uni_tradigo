import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'data/app_state.dart';
import 'services/auth_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const UniTradigoApp());
}

class UniTradigoApp extends StatelessWidget {
  const UniTradigoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AppState is a tiny in-memory store wrapped in AppStateScope so any
    // screen can call AppStateScope.of(context) to read/listen to changes.
    return AppStateScope(
      appState: AppState(),
      child: MaterialApp(
        title: 'Uni-Tradigo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // The `home` is determined by Firebase auth state. We listen to the
        // stream so logout / login automatically re-routes the app without
        // any explicit navigation code in the screens.
        home: const _AuthGate(),
      ),
    );
  }
}

/// Decides which screen to show based on whether a Firebase user is
/// signed in. While the first auth-state event is still resolving we keep
/// showing the splash screen (logo + tagline).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return const HomeScreen();
      },
    );
  }
}
