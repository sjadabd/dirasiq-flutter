// Session-long chat unread counter.
//
// Owned by the global dependency container (`Get.put(..., permanent: true)`)
// so the AppBar badge stays consistent regardless of which conversation
// screen is currently mounted — the per-screen ConversationsController is
// torn down on dispose, this service is not.
//
// State-sync rules:
//
//   • Initial load comes from `GET /chat/me/conversations` — the same
//     endpoint the list screen uses, so the badge and the list agree.
//   • `message:new` from someone other than us bumps that conversation's
//     count by 1.
//   • `conversation:read` (server-emitted after a `POST /chat/conversations
//     /:id/read`) zeros that conversation's count.
//   • Membership changes (`group:updated` / `member:added/removed`) and the
//     socket's `onConnected` stream trigger a full re-fetch — these states
//     are rare enough that re-counting from the source is simpler and safer
//     than per-event reconciliation.
//
// The service is idempotent — `start(userId)` can be called multiple times
// from different bootstrap paths (splash, login, app resume) and only the
// first call wires the listeners. A user switch (logout → login as someone
// else) calls `reset()` first to wipe state cleanly.

import 'package:get/get.dart';

import 'chat_api_service.dart';
import 'chat_socket_service.dart';

class ChatUnreadService extends GetxService {
  static ChatUnreadService get instance => Get.find<ChatUnreadService>();

  /// Total unread across every conversation the current user belongs to.
  /// Drives the AppBar badge — wrap your `Icon` in `Obx(() => ...)` and
  /// read `instance.total.value`.
  final RxInt total = 0.obs;

  /// Per-conversation breakdown — held so `conversation:read` can zero ONE
  /// conv's count exactly, rather than re-fetching the whole list.
  final Map<String, int> _perConv = <String, int>{};

  final ChatApiService _api = ChatApiService.instance;
  final ChatSocketService _sock = ChatSocketService.instance;
  final List<void Function()> _unsubs = [];

  String? _userId;
  bool _wired = false;

  /// Idempotent. Safe to call from multiple bootstrap paths.
  Future<void> start(String userId) async {
    if (userId.isEmpty) return;
    if (_userId == userId && _wired) {
      // Already running for this user — just refresh in case we lost events.
      await _refreshFromServer();
      return;
    }
    if (_userId != null && _userId != userId) {
      // User switched (logout → login as someone else). Wipe first.
      reset();
    }
    _userId = userId;
    _wire();
    try {
      await _sock.connect();
    } catch (_) {
      // Socket failure shouldn't block the badge — REST count is still valid.
    }
    await _refreshFromServer();
  }

  /// Optimistic zeroing — call this the moment a conversation is opened or
  /// REST-marked read, before the server's `conversation:read` broadcast
  /// arrives. The badge updates instantly instead of waiting on the socket
  /// round-trip. Safe to call repeatedly; the server broadcast is idempotent.
  void markConversationRead(String conversationId) {
    if (conversationId.isEmpty) return;
    if (_perConv[conversationId] == 0) return;
    _perConv[conversationId] = 0;
    _recomputeTotal();
  }

  /// Wipe local state — called on logout. After `reset()` the service is
  /// dormant; the badge reads 0 until a fresh `start()` is invoked.
  void reset() {
    for (final unsub in _unsubs) {
      unsub();
    }
    _unsubs.clear();
    _wired = false;
    _userId = null;
    _perConv.clear();
    total.value = 0;
  }

  Future<void> _refreshFromServer() async {
    try {
      final list = await _api.listMyConversations(limit: 50);
      _perConv
        ..clear()
        ..addEntries(list.map((c) => MapEntry(c.id, c.unreadCount)));
      _recomputeTotal();
    } catch (_) {
      // Stay silent — keep last known value rather than zeroing on a flake.
    }
  }

  void _wire() {
    if (_wired) return;
    _wired = true;
    _unsubs
      ..add(_sock.on('message:new', _onMessageNew))
      ..add(_sock.on('conversation:read', _onConversationRead))
      ..add(_sock.on('message:deleted', _onMessageDeleted))
      ..add(_sock.on('group:updated', _onMembershipChanged))
      ..add(_sock.on('member:added', _onMembershipChanged))
      ..add(_sock.on('member:removed', _onMembershipChanged));
    _sock.onConnected.listen((_) {
      // On (re)connect we may have missed events while offline — re-sync.
      _refreshFromServer();
    });
  }

  void _onMessageNew(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final convId = map['conversationId']?.toString();
    final senderId = map['senderId']?.toString();
    if (convId == null) return;
    // Don't count my own messages.
    if (_userId != null && senderId == _userId) return;
    _perConv[convId] = (_perConv[convId] ?? 0) + 1;
    _recomputeTotal();
  }

  void _onConversationRead(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final convId = map['conversationId']?.toString();
    final userId = map['userId']?.toString();
    if (convId == null) return;
    // Read markers from other devices/users shouldn't clear MY count.
    if (_userId != null && userId != _userId) return;
    if (_perConv[convId] == 0) return;
    _perConv[convId] = 0;
    _recomputeTotal();
  }

  void _onMessageDeleted(dynamic data) {
    // If a message I haven't read yet is deleted, the server doesn't push
    // a decremented count — we'd over-show by 1. Cheapest fix: re-sync.
    if (data is! Map) return;
    _refreshFromServer();
  }

  void _onMembershipChanged(dynamic _) {
    _refreshFromServer();
  }

  void _recomputeTotal() {
    total.value = _perConv.values.fold<int>(0, (s, n) => s + n);
  }
}
