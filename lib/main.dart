import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'data/app_state.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // FCM must be set up after Firebase is initialised and before
  // `runApp`, so the background handler is registered in time for
  // messages delivered while the app is closed.
  await NotificationService.instance.init();

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
        // Gives the notification banner a way to reach the app's
        // messenger from outside the widget tree.
        scaffoldMessengerKey: _messengerKey,
        // The `home` is determined by Firebase auth state. We listen to the
        // stream so logout / login automatically re-routes the app without
        // any explicit navigation code in the screens.
        home: const _AuthGate(),
        builder: (context, child) {
          // Show an in-app banner for notifications that arrive while the
          // app is already open. Background and terminated notifications
          // are rendered by Android itself from the `notification` payload,
          // so this only affects the foreground case.
          _showForegroundNotifications();

          // The app may have been launched by tapping a notification that
          // was delivered while the app was closed. Android has already
          // shown the system notification; this surfaces the same content
          // inside the app so the tap doesn't feel like it did nothing.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLaunchedNotification();
          });
          return child!;
        },
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
        // Register this device so the user can receive purchase and chat
        // notifications. Fire-and-forget: the service swallows its own
        // errors, so a failure here never blocks the app from opening.
        //
        // The builder can run more than once for the same user (any
        // rebuild of the tree re-runs it), so the registration is
        // guarded by the last-registered uid. Otherwise every rebuild
        // would repeat the token fetch and the Firestore write.
        if (_lastRegisteredUid != user.uid) {
          _lastRegisteredUid = user.uid;
          NotificationService.instance.registerDeviceToken(user.uid);
        }
        return const HomeScreen();
      },
    );
  }
}

/// The uid whose device token was last registered, so the auth gate only
/// registers once per sign-in.
String? _lastRegisteredUid;

// ----- Foreground notification banner ---------------------------------

/// The foreground listener is installed once, the first time the app
/// builds. It is a module-level flag rather than per-widget state so a
/// rebuild never registers a second listener (which would show the same
/// notification twice).
bool _foregroundListenerInstalled = false;

/// Set once the notification that launched the app has been shown, so
/// the banner isn't repeated on every rebuild.
bool _launchNotificationShown = false;

/// Key used to reach the app's [ScaffoldMessenger] from outside the
/// widget tree.
///
/// The messenger is looked up through this key at the moment a message
/// arrives, rather than captured once when the listener is installed.
/// Capturing it up front is unreliable: the messenger may not exist yet
/// on the first build (the listener would then never be installed at
/// all), and a captured messenger can go stale when routes change.
final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows a banner for notifications received while the app is open.
///
/// The banner names the sender and shows the relevant text, matching what
/// the system notification would say.
void _showForegroundNotifications() {
  if (_foregroundListenerInstalled) return;
  _foregroundListenerInstalled = true;

  NotificationService.instance.foregroundMessages.listen((message) {
    _showNotificationBanner(message);
  });
}

/// Surfaces the notification the user tapped to launch the app.
///
/// Called from a post-frame callback after the first frame, so the
/// `ScaffoldMessenger` is mounted and able to show a banner.
///
/// The message is only marked as shown once the banner has actually been
/// displayed. If the messenger is not ready yet (the app may still be on
/// the login screen at this point) the message is kept, and the next
/// rebuild tries again.
void _showLaunchedNotification() {
  if (_launchNotificationShown) return;
  final message = NotificationService.instance.initialMessage;
  if (message == null) return;

  if (_showNotificationBanner(message)) {
    _launchNotificationShown = true;
  }
}

/// Renders a notification as an in-app banner.
///
/// The heading prefers the sender's name so the banner reads the same way
/// the system notification does; the detail is the notification body, or
/// the listing title when there is no body.
///
/// Returns true when the banner was shown, false when there was no
/// messenger available yet.
bool _showNotificationBanner(RemoteMessage message) {
  final messenger = _messengerKey.currentState;
  if (messenger == null) return false;

  final data = message.data;
  final sender = (data['senderName'] ?? '').toString().trim();
  final body = (message.notification?.body ?? '').toString().trim();
  final title = (message.notification?.title ?? '').toString().trim();

  final heading = sender.isNotEmpty ? sender : title;
  final detail = body.isNotEmpty
      ? body
      : (data['listingTitle'] ?? '').toString().trim();

  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading.isEmpty ? 'New notification' : heading,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ),
  );
  return true;
}
