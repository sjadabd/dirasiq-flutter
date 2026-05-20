// Socket.IO client wrapper.
//
// ── Send / receive separation (Phase 6 architectural decision) ──────────────
// SEND PATH   : Flutter → REST API only (POST /chat/messages, etc.).
// RECEIVE PATH: Socket.IO only (message:new, message:typing, conversation:read,
//               group:updated, member:added/removed, message:deleted,
//               message:pin_updated).
//
// Reasoning: the chat service rebroadcasts `message:new` from inside the
// service layer once a REST send succeeds, so emitting BOTH a REST `POST
// /chat/messages` AND a socket `message:send` would persist (and broadcast)
// the message twice. Keep the paths separate; let the broadcast come from
// the server.
//
// The ONLY client→server socket events we emit are:
//   - `message:typing`  — ephemeral, no DB write
//   - `message:read`    — small idempotent update
//
// One singleton socket — there's no useful split between conversations.
// Controllers subscribe via `on(event, callback)` and unsubscribe in their
// `onClose` / `dispose`. The socket auto-reconnects with the same JWT.
//
// On reconnect we emit a `socketReconnected` so the conversations
// controller can pull a fresh list (the user may have been moved into / out
// of rooms while disconnected).

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/config/app_config.dart';

typedef ChatEventListener = void Function(dynamic data);

class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  final Map<String, List<ChatEventListener>> _listeners = {};

  /// True after a successful `connect` and before `disconnect`.
  bool get isConnected => _socket?.connected == true;

  /// Fires on every successful (re)connection. Subscribers should re-fetch
  /// conversation list and rejoin any UI subscriptions.
  final StreamController<void> _connected = StreamController.broadcast();
  Stream<void> get onConnected => _connected.stream;

  /// Open the socket. Safe to call multiple times — idempotent.
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw StateError('chat socket: no token in SharedPreferences');
    }

    final socket = io.io(
      AppConfig.chatBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionAttempts(60)
          .setReconnectionDelay(2000)
          .build(),
    );

    socket
      ..onConnect((_) {
        _connected.add(null);
      })
      ..onConnectError((err) {
        // Bad token / server down — let the upper layer decide whether to retry.
      })
      ..onAny((event, data) {
        final list = _listeners[event];
        if (list == null) return;
        for (final cb in list) {
          try {
            cb(data);
          } catch (_) {/* a buggy listener shouldn't kill the dispatch */}
        }
      });

    socket.connect();
    _socket = socket;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  /// Subscribe to a server event. Returns an unsubscribe function.
  void Function() on(String event, ChatEventListener listener) {
    final list = _listeners.putIfAbsent(event, () => <ChatEventListener>[]);
    list.add(listener);
    return () => list.remove(listener);
  }

  /// Emit a typed client→server event.
  /// Emit a typed client→server event.
  ///
  /// Allowlisted — see the file header. Sending a message goes through REST.
  /// We assert here so a future refactor can't accidentally regress.
  void emit(String event, Map<String, dynamic> payload) {
    assert(
      event != 'message:send',
      'chat: send path is REST only — do not emit message:send from the client',
    );
    _socket?.emit(event, payload);
  }
}
