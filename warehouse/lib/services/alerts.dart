import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The new-order alert: a heads-up notification with a sound, loud enough to
/// notice across a warehouse floor.
///
/// **Local, not Firebase.** The server can push to the rider app, but that
/// needs a Firebase service account the shop has not issued. Everything here
/// works without one: the app polls while someone is signed in and raises the
/// alert itself. When push is configured, [showNewOrder] is what its message
/// handler should call, so nothing below has to change.
///
/// **The sound and the importance belong to the CHANNEL, and are fixed when
/// Android first creates it.** Changing either later means shipping a new
/// channel id -- hence the `_v1` suffix.
class Alerts {
  Alerts({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const channelId = 'new_order_v1';
  static const _channelName = 'New orders';
  static const _channelDescription =
      'Alerts when a new order arrives to be packed.';

  bool _ready = false;

  /// Idempotent: safe to call on every sign-in.
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Importance.max is what makes it slide down over whatever is on the
        // screen rather than landing silently in the tray.
        await android
            .createNotificationChannel(const AndroidNotificationChannel(
          channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));
        // Android 13+ shows nothing until this is granted, and it must be
        // asked for at a moment the person understands -- signing in.
        await android.requestNotificationsPermission();
      }
      _ready = true;
    } catch (error) {
      // Someone who declines the permission, or an OEM that refuses the
      // channel, must still get a working app -- just a quieter one.
      debugPrint('Alerts unavailable: $error');
    }
  }

  /// Raise the alert for one order that has just arrived.
  Future<void> showNewOrder({
    required String orderId,
    required String code,
    required String customer,
    required String summary,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;

    final body = [
      if (customer.isNotEmpty) customer,
      if (summary.isNotEmpty) summary,
    ].join(' · ');

    try {
      await _plugin.show(
        // The order id as the notification id, so two orders do not collapse
        // into one and the same one seen twice does not stack.
        orderId.hashCode & 0x7fffffff,
        'New order · $code',
        body.isEmpty ? 'Open the app to pack it.' : body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            playSound: true,
            enableVibration: true,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: orderId,
      );
    } catch (error) {
      debugPrint('Could not raise the new-order alert: $error');
    }
  }
}
