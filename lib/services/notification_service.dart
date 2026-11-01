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
///     (the background and terminated states are handled by the OS).
///
/// What this service deliberately does NOT do:
///   - Send anything. The `firebase_messaging` client SDK is receive-only
///     — it cannot target a specific user's device token. Sending is the
///     Cloud Function's job (see `functions/index.js`), which fires off
///     Firestore writes. That also means the app can never accidentally
///     notify a user about their own action.
///
/// Delivery model:
///   - Foreground  → [foregroundMessages] emits; the UI shows a banner.
///   - Background  → Android renders the `notification` payload itself.
///   - Terminated  → Android renders it too, and tapping it launches the
///     app; [initialMessage] holds what the user tapped.
///
/// Token storage:
///   - `users/{uid}.fcmTokens` — a list of device tokens. The Firestore
///     rules already allow a user to update their own document, so no
///     rules change was needed.
///
/// Singleton:
///   This class must be a single shared instance. The foreground message
///   stream is backed by a per-instance broadcast controller, so if the
///   app created two instances the one holding the `onMessage` listener
///   would be different from the one the UI listens to — and no
///   foreground banner would ever be shown. [instance] guarantees one
///   instance for the whole app.
class NotificationService {
  /// The single shared instance. Use this instead of constructing a new
  /// [NotificationService] directly.
  static final NotificationService instance = NotificationService._();

  final UserService _users = UserService();

  NotificationService._();

  /// Broadcast controller for messages received while the app is open.
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  /// The message the user tapped to open the app from a terminated
  /// state. Null when the app was opened normally.
  RemoteMessage? _initialMessage;

  /// Messages that arrive while the app is in the foreground.
  Stream<RemoteMessage> get foregroundMessages => _foregroundController.stream;

  /// The notification the user tapped to launch the app (terminated
  /// state). Null when the app was opened normally.
  RemoteMessage? get initialMessage => _initialMessage;

  /// True when the user has already granted notification permission.
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

  /// Sets up messaging. Call once from `main()` after Firebase is
  /// initialised and before `runApp`.
  ///
  /// Registers the background handler (which is what makes terminated
  /// delivery work), asks for permission, and wires up the foreground
  /// stream and token-refresh handling.
  ///
  /// Never throws — a messaging setup failure must not stop the app from
  /// starting.
  Future<void> init() async {
    try {
      // Background / terminated delivery.
      //
      // This runs in its own isolate when the OS delivers a message to
      // an app that isn't running, so it must be a top-level function
      // marked with `@pragma('vm:entry-point')`.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Android 13+ (API 33) requires an explicit runtime permission.
      // On iOS this shows the system prompt; on older Android versions
      // it is a no-op because permission is granted at install time.
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages -> the broadcast stream the UI listens to.
      FirebaseMessaging.onMessage.listen(_foregroundController.add);

      // A new token is issued when the app is reinstalled or the user
      // clears app data. Persist it so pushes keep arriving.
      messaging.onTokenRefresh.listen((token) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || uid.isEmpty) return;
        // Fire and forget — a failed write just means this device
        // won't receive pushes until the next launch.
        _users.saveFcmToken(uid, token).catchError((_) {});
      });

      // The message that launched the app from a terminated state.
      _initialMessage = await messaging.getInitialMessage();
    } catch (_) {
      // Messaging is a nice-to-have; the app must still open if it fails.
    }
  }

  /// Registers this device's FCM token against [uid].
  ///
  /// Safe to call repeatedly (it is called on every sign-in). Never
  /// throws, so it can be fired from a widget build without guarding
  /// the call site.
  Future<void> registerDeviceToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _users.saveFcmToken(uid, token);
    } catch (_) {
      // Non-critical: without a token the device simply won't receive
      // pushes. The app continues to work normally.
    }
  }

  /// Unregisters this device's FCM token from [uid].
  ///
  /// Called on sign-out so the next person to use the device doesn't
  /// receive the previous user's notifications. Best-effort: the Firestore
  /// rules only let the owner update their own document, so this must
  /// run *before* the user signs out.
  Future<void> unregisterDeviceToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _users.removeFcmToken(uid, token);
    } catch (_) {
      // Non-critical — a stale token simply means no push arrives.
    }
  }

  /// The FCM tokens registered for [uid]. Empty when the user has no
  /// device registered.
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

/// Background / terminated message handler.
///
/// The server sends a `notification` payload (title + body) alongside the
/// `data` payload. When the app is backgrounded or terminated, Android
/// renders that notification in the system tray **by itself** — no extra
/// code is required.
///
/// This handler is therefore intentionally empty. Posting a local
/// notification here as well would show the user two copies of the same
/// message, because the OS would already have shown one.
///
/// The `data` payload is still delivered in [message.data] so the app can
/// act on it when the user taps through.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty — see the doc comment above.
}
