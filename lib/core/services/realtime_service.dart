// Realtime push from the main API (mulhimiq backend).
//
// Mirror of `chat_socket_service.dart` but pointed at the main API's
// Socket.IO endpoint (mounted in dirasiq_api/src/index.ts).
//
// Connection lifecycle:
//   - Call [connect] once at app start AFTER a token is present in
//     SharedPreferences (AuthController on login + splash on resume).
//   - The socket auto-reconnects with the same JWT — no manual logic
//     required when the network blinks.
//   - Call [disconnect] on logout to drop the room joins.
//
// Subscriptions:
//   - subscribe('event', cb) → returns an unsubscribe function the caller
//     should invoke in `onClose` / `dispose` to avoid leaks.
//   - Multiple subscribers per event are supported (fan-out).
//   - Server emits never block on listener exceptions — a buggy callback
//     can't kill the dispatch.
//
// Events the server sends today (from VideoCourseEvents.ts):
//   - 'video-course:created'        super_admins only
//   - 'video-course:approved'       teacher only — payload { course, at }
//   - 'video-course:rejected'       teacher only — payload { course, at }
//   - 'video-lesson:status_changed' teacher only — payload { lesson, at }

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

typedef RealtimeEventListener = void Function(dynamic data);

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  final Map<String, List<RealtimeEventListener>> _listeners = {};

  /// True after a successful `connect` and before `disconnect`.
  bool get isConnected => _socket?.connected == true;

  /// Fires on every successful (re)connection. Useful for UIs that want
  /// to refetch after a network blip.
  final StreamController<void> _connected = StreamController.broadcast();
  Stream<void> get onConnected => _connected.stream;

  /// Open the socket. Safe to call multiple times — idempotent. No-op if
  /// no JWT is stored yet (caller is responsible for retrying after login).
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;
    // If there's a stale disconnected socket lying around, dispose it
    // before creating a fresh one — otherwise the new connect call
    // wouldn't take effect (and we'd quietly stay disconnected).
    if (_socket != null) {
      try { _socket!.dispose(); } catch (_) {}
      _socket = null;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // ignore: avoid_print
    print('[realtime] connect() called — token present: ${token != null && token.isNotEmpty}');
    if (token == null || token.isEmpty) return;

    // The main API exposes Socket.IO at the default path on its
    // serverBaseUrl host (NOT the chat host). Same JWT, same auth path —
    // see dirasiq_api/src/services/realtime.service.ts attach() handler.
    //
    // setReconnectionAttempts(-1) = unlimited. socket_io_client defaults
    // to Infinity for this but Dart's binding sometimes maps a missing
    // value to 0 — be explicit. Without this, a long-lived disconnect
    // (server restart, network blip after 60 quick retries) parks the
    // socket forever and the realtime UI silently dies.
    final socket = io.io(
      AppConfig.serverBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionAttempts(1 << 30)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .enableForceNew()
          .build(),
    );

    socket
      ..onConnect((_) {
        // ignore: avoid_print
        print('[realtime] ✅ socket connected to ${AppConfig.serverBaseUrl}');
        _connected.add(null);
      })
      ..onConnectError((err) {
        // ignore: avoid_print
        print('[realtime] ❌ connect_error: $err');
      })
      ..onDisconnect((reason) {
        // ignore: avoid_print
        print('[realtime] socket disconnected: $reason');
      })
      ..onAny((event, data) {
        // ignore: avoid_print
        print('[realtime] 📨 event="$event" listeners=${_listeners[event]?.length ?? 0}');
        final list = _listeners[event];
        if (list == null) return;
        // Iterate over a copy so subscribers that unsubscribe inside their
        // own callback don't trip a ConcurrentModificationError.
        for (final cb in List<RealtimeEventListener>.from(list)) {
          try {
            cb(data);
          } catch (_) { /* a buggy listener shouldn't kill the dispatch */ }
        }
      });

    socket.connect();
    _socket = socket;
  }

  /// Close the connection. Subscribers are kept (re-attached on the next
  /// connect) — call [clearListeners] explicitly if you want a hard reset
  /// (typically only the logout flow does).
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  /// Subscribe to a server event. Returns an unsubscribe function.
  void Function() subscribe(String event, RealtimeEventListener listener) {
    final list = _listeners.putIfAbsent(event, () => <RealtimeEventListener>[]);
    list.add(listener);
    return () => list.remove(listener);
  }

  /// Wipe every registered listener. Use only on full logout.
  void clearListeners() => _listeners.clear();
}
