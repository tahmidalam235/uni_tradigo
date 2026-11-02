import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'user_service.dart';

/// NotificationService — owns everything Firebase Cloud Messaging.
///
/// What this service does:
///   - Registers this device's FCM token against the signed-in user so
///     the Cloud Function knows where to deliver pushes.
///   - Surfaces messages that arrive while the app is in the foreground
///     or when tapped from background/terminated states.
///
/// What this service deliberately does NOT do:
///   - Send anything directly from client. The `firebase_messaging` client
///     SDK is receive-only. Sending is the Cloud Function's job (see `functions/index.js`).
///
/// Delivery model:
///   - Foreground  → [foregroundMessages] emits; the UI presents a banner.
///   - Background  → Android renders the `notification` payload in system tray.
///                   Tapping fires `onMessageOpenedApp`.
///   - Terminated  → Android renders it too; tapping launches the app and
///                   [initialMessage] holds the payload.
///
/// Token storage:
///   - `users/{uid}.fcmTokens` — a list of device tokens.
class NotificationService {
  /// The single shared instance.
  static final NotificationService instance = NotificationService._();

  final UserService _users = UserService();

  NotificationService._();

  /// Broadcast controller for messages received while the app is open or opened from background.
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  /// The message the user tapped to open the app from a terminated state.
  RemoteMessage? _initialMessage;

  /// Messages that arrive while the app is open or tapped from background.
  Stream<RemoteMessage> get foregroundMessages => _foregroundController.stream;

  /// The notification tapped to launch the app from a terminated state.
  RemoteMessage? get initialMessage => _initialMessage;

  /// True when the user has granted notification permission.
  Future<bool> hasPermission() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Sets up FCM messaging. Call once from `main()` after Firebase initialized.
  Future<void> init() async {
    try {
      // Register background handler for terminated message processing
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Request permissions (Android 13+ runtime permission & iOS prompt)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Presentation options when app is in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages -> broadcast controller
      FirebaseMessaging.onMessage.listen((message) {
        _foregroundController.add(message);
      });

      // Background notification tap -> broadcast controller
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _foregroundController.add(message);
      });

      // FCM token refresh handling
      messaging.onTokenRefresh.listen((token) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          _users.saveFcmToken(uid, token).catchError((_) {});
        }
      });

      // Message that launched the app from a terminated state
      _initialMessage = await messaging.getInitialMessage();
    } catch (_) {
      // Messaging setup is resilient; fails silently without crashing startup
    }
  }

  /// Registers this device's FCM token against [uid]. Returns true on success.
  Future<bool> registerDeviceToken(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return false;
      await _users.saveFcmToken(uid, token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unregisters this device's FCM token from [uid].
  Future<void> unregisterDeviceToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _users.removeFcmToken(uid, token);
    } catch (_) {}
  }

  /// Returns registered FCM tokens for [uid].
  Future<List<String>> tokensForUser(String uid) async {
    if (uid.isEmpty) return const [];
    try {
      return await _users.getFcmTokens(uid);
    } catch (_) {
      return const [];
    }
  }

  void dispose() {
    _foregroundController.close();
  }
}

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled by Android OS system tray using notification payload
}
