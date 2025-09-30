import 'dart:async';

/// Simple app-wide event bus for notifications.
class NotificationEvents {
  NotificationEvents._internal();
  static final NotificationEvents instance = NotificationEvents._internal();

  // Event without payload (for badge refresh, simple triggers)
  final StreamController<void> _newNotificationCtrl =
      StreamController<void>.broadcast();
  Stream<void> get onNewNotification => _newNotificationCtrl.stream;

  // Event with payload to allow immediate UI insertion
  final StreamController<Map<String, dynamic>> _payloadCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationPayload => _payloadCtrl.stream;

  void emitNewNotification() {
    if (!_newNotificationCtrl.isClosed) {
      _newNotificationCtrl.add(null);
    }
  }

  void emitNotificationPayload(Map<String, dynamic> payload) {
    if (!_payloadCtrl.isClosed) {
      _payloadCtrl.add(payload);
    }
  }

  void dispose() {
    _newNotificationCtrl.close();
    _payloadCtrl.close();
  }
}
