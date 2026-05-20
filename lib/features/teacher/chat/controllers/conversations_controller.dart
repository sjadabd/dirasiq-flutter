// Conversations list controller.
//
// Holds the list of conversations the teacher is in, the loading state, and
// the socket subscriptions that keep it fresh:
//
//   - `message:new`     → bump the matching conversation to the top with a
//                         fresh last-message preview + unread++ (unless this
//                         is the conversation currently being viewed, which
//                         we don't know about here — the conversation screen
//                         itself zeroes the unread count when it mounts).
//   - `conversation:read` → if it's us, zero the unread on that conversation.
//   - `group:updated`    → re-fetch the affected row (rare; cheap).
//   - `member:added` / `member:removed` → re-fetch the list (rare).
//   - socket `connect`   → re-fetch (we may have missed events while offline).

import 'package:get/get.dart';

import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';
import '../services/chat_unread_service.dart';

class ConversationsController extends GetxController {
  final RxList<ChatConversation> conversations = <ChatConversation>[].obs;
  final RxBool loading = false.obs;
  final RxBool refreshing = false.obs;
  final RxnString error = RxnString();

  final ChatApiService _api = ChatApiService.instance;
  final ChatSocketService _sock = ChatSocketService.instance;
  final List<void Function()> _unsubs = [];
  String? _myUserId;

  /// Total unread count across all conversations — drives the drawer / nav badge.
  RxInt get totalUnread {
    final r = RxInt(0);
    everAll([conversations], (_) {
      r.value = conversations.fold<int>(0, (s, c) => s + c.unreadCount);
    });
    r.value = conversations.fold<int>(0, (s, c) => s + c.unreadCount);
    return r;
  }

  /// Called by the screen on first build. Loads the list, connects the socket
  /// if not already connected, and wires the event subscriptions.
  Future<void> initialize({required String myUserId}) async {
    _myUserId = myUserId;
    _wireSocket();
    try {
      await _sock.connect();
    } catch (_) {
      // Socket failure shouldn't block the list — REST still works.
    }
    await fetch();
  }

  Future<void> fetch({bool isRefresh = false}) async {
    if (isRefresh) {
      refreshing.value = true;
    } else {
      loading.value = true;
    }
    error.value = null;
    try {
      final list = await _api.listMyConversations(limit: 50);
      conversations.assignAll(list);
    } catch (e) {
      error.value = _humanise(e);
    } finally {
      loading.value = false;
      refreshing.value = false;
    }
  }

  /// Called by the conversation screen on mount so we can stop the list-level
  /// unread counter from over-counting messages the user is actively looking at.
  /// Also nudges the global badge service so the navbar dot drops without
  /// waiting for the server's `conversation:read` round-trip.
  void markConversationOpened(String conversationId) {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final c = conversations[idx];
      if (c.unreadCount != 0) {
        c.unreadCount = 0;
        conversations.refresh();
      }
    }
    // Optimistic — server broadcast is the source of truth and will land
    // moments later, but the user shouldn't see a stale badge in between.
    try {
      ChatUnreadService.instance.markConversationRead(conversationId);
    } catch (_) {
      // Service not registered (cold-start edge case).
    }
  }

  // ---------------------------------------------------------------------------
  //  Socket wiring
  // ---------------------------------------------------------------------------

  void _wireSocket() {
    _unsubs
      ..add(_sock.on('message:new', _onMessageNew))
      ..add(_sock.on('conversation:read', _onConversationRead))
      ..add(_sock.on('group:updated', _onGroupUpdated))
      ..add(_sock.on('member:added', _onMembershipChanged))
      ..add(_sock.on('member:removed', _onMembershipChanged));
    _sock.onConnected.listen((_) {
      // We may have missed events; pull the canonical list.
      fetch(isRefresh: true);
    });
  }

  void _onMessageNew(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final convId = map['conversationId']?.toString();
    if (convId == null) return;
    final msg = ChatMessage.fromJson(map);
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) {
      // Brand-new conversation (group add or first message); pull fresh list.
      fetch(isRefresh: true);
      return;
    }
    final c = conversations[idx];
    c.lastMessage = msg;
    c.lastMessageAt = msg.createdAt;
    // Don't bump unread if I sent the message myself.
    if (_myUserId != null && msg.senderId != _myUserId) {
      c.unreadCount = c.unreadCount + 1;
    }
    // Move to the top.
    conversations
      ..removeAt(idx)
      ..insert(0, c);
  }

  void _onConversationRead(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final convId = map['conversationId']?.toString();
    final userId = map['userId']?.toString();
    if (convId == null || userId == null) return;
    if (userId != _myUserId) return; // someone else's read marker; ignore
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) return;
    conversations[idx].unreadCount = 0;
    conversations.refresh();
  }

  void _onGroupUpdated(dynamic data) {
    // Cheap path: re-fetch the list. Group updates are rare enough.
    fetch(isRefresh: true);
  }

  void _onMembershipChanged(dynamic data) {
    fetch(isRefresh: true);
  }

  @override
  void onClose() {
    for (final u in _unsubs) {
      u();
    }
    super.onClose();
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'تحقّق من الإنترنت ثم حاول مجدّداً.';
    }
    return 'تعذّر تحميل المحادثات.';
  }
}
