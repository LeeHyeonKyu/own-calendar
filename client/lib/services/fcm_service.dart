import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// FCM push notification service.
///
/// Firebase must be configured via `flutterfire configure` before this works.
/// Until then, all methods are safe no-ops that log to debug console.
///
/// To enable:
/// 1. Run `flutterfire configure` in the client directory
/// 2. Add firebase_core and firebase_messaging to pubspec.yaml
/// 3. Uncomment the Firebase imports and implementation below
class FcmService {
  final ApiService _api = ApiService();

  /// Initialize FCM: request permissions, get token, register with server.
  Future<void> initialize() async {
    // TODO: Uncomment after running `flutterfire configure`
    //
    // try {
    //   await Firebase.initializeApp(
    //     options: DefaultFirebaseOptions.currentPlatform,
    //   );
    //
    //   final messaging = FirebaseMessaging.instance;
    //
    //   // Request permission (iOS)
    //   final settings = await messaging.requestPermission(
    //     alert: true,
    //     badge: true,
    //     sound: true,
    //   );
    //
    //   if (settings.authorizationStatus == AuthorizationStatus.authorized ||
    //       settings.authorizationStatus == AuthorizationStatus.provisional) {
    //     // Get FCM token
    //     final token = await messaging.getToken();
    //     if (token != null) {
    //       await _registerToken(token);
    //     }
    //
    //     // Listen for token refresh
    //     messaging.onTokenRefresh.listen(_registerToken);
    //
    //     // Handle foreground messages
    //     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    //
    //     // Handle background/terminated tap
    //     FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    //
    //     // Check if app was opened from a notification
    //     final initialMessage = await messaging.getInitialMessage();
    //     if (initialMessage != null) {
    //       _handleMessageTap(initialMessage);
    //     }
    //   }
    // } catch (e) {
    //   debugPrint('[FCM] Initialization failed: $e');
    // }

    debugPrint('[FCM] Firebase not configured — push notifications disabled');
    debugPrint('[FCM] Run `flutterfire configure` to enable');
  }

  // ignore: unused_element — used when Firebase is configured (see initialize())
  Future<void> _registerToken(String token) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'IOS'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'ANDROID'
              : 'WEB';

      await _api.post('/device-tokens', {
        'token': token,
        'platform': platform,
      });
      debugPrint('[FCM] Token registered');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  /// Unregister current device token from server.
  Future<void> unregister(String token) async {
    try {
      await _api.delete('/device-tokens/$token');
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] Failed to unregister token: $e');
    }
  }

  // void _handleForegroundMessage(RemoteMessage message) {
  //   debugPrint('[FCM] Foreground message: ${message.notification?.title}');
  //   // Show local notification or snackbar
  // }

  // void _handleMessageTap(RemoteMessage message) {
  //   final eventId = message.data['eventId'];
  //   if (eventId != null) {
  //     debugPrint('[FCM] Navigate to event: $eventId');
  //     // TODO: Use GoRouter to navigate to event detail
  //   }
  // }
}
