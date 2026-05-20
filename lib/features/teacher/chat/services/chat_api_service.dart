// REST layer for the chat service.
//
// Separate Dio instance from `ApiService` because:
//   - Chat lives on a different host/port (AppConfig.chatBaseUrl).
//   - The chat service speaks the same JWT but is independent of main's
//     `tokens` table revocation.
//
// One Dio interceptor reads `SharedPreferences['token']` per request (same
// pattern as the main API service in this app). 401 = log a warning; we
// don't auto-logout from the chat — the main app's interceptor does that.

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../models/chat_models.dart';

class ChatApiService {
  ChatApiService() : _dio = _buildDio();

  static ChatApiService? _instance;
  static ChatApiService get instance => _instance ??= ChatApiService();

  final Dio _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.chatBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  // ---- Conversations -------------------------------------------------------

  /// `GET /chat/me/conversations?page=&limit=`.
  Future<List<ChatConversation>> listMyConversations({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/chat/me/conversations',
      queryParameters: {'page': page, 'limit': limit},
    );
    _ensureSuccess(res);
    final data = res.data['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => ChatConversation.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// `POST /chat/conversations/private` — open or reuse a 1-on-1 with peerId.
  /// Returns the full conversation header + members tuple.
  Future<Map<String, dynamic>> openPrivate(String peerId) async {
    final res = await _dio.post(
      '/chat/conversations/private',
      data: {'peerId': peerId},
    );
    _ensureSuccess(res);
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// `GET /chat/conversations/:id` — full header + members.
  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    final res = await _dio.get('/chat/conversations/$conversationId');
    _ensureSuccess(res);
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// `GET /chat/conversations/:id/messages?before=&limit=` — cursor pagination.
  Future<List<ChatMessage>> listMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  }) async {
    final res = await _dio.get(
      '/chat/conversations/$conversationId/messages',
      queryParameters: {
        if (before != null && before.isNotEmpty) 'before': before,
        'limit': limit,
      },
    );
    _ensureSuccess(res);
    final data = res.data['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// `POST /chat/conversations/:id/read` — snap last-read.
  Future<void> markRead(String conversationId, {String? lastReadMessageId}) async {
    final res = await _dio.post(
      '/chat/conversations/$conversationId/read',
      data: {
        if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
      },
    );
    _ensureSuccess(res);
  }

  // ---- Messages ------------------------------------------------------------

  /// `POST /chat/messages` — body or attachments (or both). Returns the row
  /// the server persisted (with sender + attachments populated).
  Future<ChatMessage> sendMessage({
    required String conversationId,
    String? body,
    List<String>? attachmentIds,
    String? replyToMessageId,
  }) async {
    final res = await _dio.post(
      '/chat/messages',
      data: {
        'conversationId': conversationId,
        if (body != null && body.isNotEmpty) 'body': body,
        if (attachmentIds != null && attachmentIds.isNotEmpty)
          'attachmentIds': attachmentIds,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      },
    );
    _ensureSuccess(res);
    return ChatMessage.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// `DELETE /chat/messages/:id` — sender ≤5min, or owner/admin anytime.
  Future<void> deleteMessage(String messageId) async {
    final res = await _dio.delete('/chat/messages/$messageId');
    _ensureSuccess(res);
  }

  /// `POST /chat/messages/:id/pin` — owner/admin only.
  Future<void> togglePin(String messageId, bool pinned) async {
    final res = await _dio.post(
      '/chat/messages/$messageId/pin',
      data: {'pinned': pinned},
    );
    _ensureSuccess(res);
  }

  // ---- Groups --------------------------------------------------------------

  /// `POST /chat/groups` — teacher creates. Returns the created conversation.
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
    String? courseId,
    ConversationMode mode = ConversationMode.open,
  }) async {
    final res = await _dio.post('/chat/groups', data: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (courseId != null && courseId.isNotEmpty) 'courseId': courseId,
      'mode':
          mode == ConversationMode.announceOnly ? 'announce_only' : 'open',
    });
    _ensureSuccess(res);
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// `PUT /chat/groups/:id` — owner only.
  Future<Map<String, dynamic>> updateGroup(
    String conversationId, {
    String? name,
    String? description,
    String? imagePath,
    ConversationMode? mode,
  }) async {
    final res = await _dio.put('/chat/groups/$conversationId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (imagePath != null) 'imagePath': imagePath,
      if (mode != null)
        'mode':
            mode == ConversationMode.announceOnly ? 'announce_only' : 'open',
    });
    _ensureSuccess(res);
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// `DELETE /chat/groups/:id` — owner only (archive forever).
  Future<void> archiveGroup(String conversationId) async {
    final res = await _dio.delete('/chat/groups/$conversationId');
    _ensureSuccess(res);
  }

  /// `GET /chat/groups/:id/members`.
  Future<List<ChatMember>> listMembers(String conversationId) async {
    final res = await _dio.get('/chat/groups/$conversationId/members');
    _ensureSuccess(res);
    final data = res.data['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => ChatMember.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// `POST /chat/groups/:id/members` — bulk add.
  Future<Map<String, dynamic>> addMembers(
    String conversationId,
    List<String> userIds,
  ) async {
    final res = await _dio.post(
      '/chat/groups/$conversationId/members',
      data: {'userIds': userIds},
    );
    _ensureSuccess(res);
    return Map<String, dynamic>.from(res.data['data'] ?? {});
  }

  /// `DELETE /chat/groups/:id/members/:memberId`.
  Future<void> removeMember(String conversationId, String memberId) async {
    final res = await _dio.delete(
      '/chat/groups/$conversationId/members/$memberId',
    );
    _ensureSuccess(res);
  }

  /// `PATCH /chat/groups/:id/members/:memberId` — mute/unmute, promote/demote.
  Future<void> updateMember(
    String conversationId,
    String memberId, {
    MemberRole? role,
    DateTime? muteUntil,
    bool unmute = false,
  }) async {
    final res = await _dio.patch(
      '/chat/groups/$conversationId/members/$memberId',
      data: {
        if (role != null) 'role': role == MemberRole.admin ? 'admin' : 'member',
        if (unmute)
          'muteUntil': null
        else if (muteUntil != null)
          'muteUntil': muteUntil.toUtc().toIso8601String(),
      },
    );
    _ensureSuccess(res);
  }

  // ---- Attachments ---------------------------------------------------------

  /// `POST /chat/attachments` — multipart upload. Returns the persisted row.
  /// Caller passes the file bytes + name; mime is detected server-side.
  Future<ChatAttachment> uploadAttachment({
    required String conversationId,
    required String filePath,
    String? declaredMime,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'conversationId': conversationId,
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: declaredMime != null
            ? DioMediaType.parse(declaredMime)
            : null,
      ),
    });
    final res = await _dio.post(
      '/chat/attachments',
      data: form,
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          onProgress(sent / total);
        }
      },
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
    _ensureSuccess(res);
    final att = Map<String, dynamic>.from(
      (res.data['data'] ?? const {})['attachment'] ?? const {},
    );
    return ChatAttachment.fromJson(att);
  }

  // ---- Teacher roster (lives on MAIN API, not chat) -----------------------

  /// Builds a Dio bound to the MAIN API host with the current JWT. Chat lives
  /// on its own host, so roster / course endpoints need a separate client.
  Future<Dio> _buildMainApiDio() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }

  /// Convenience wrapper kept for backward compat — returns just the rows.
  /// New callers should use [fetchTeacherStudentsPaged].
  Future<List<({String id, String name})>> fetchTeacherStudents({
    int page = 1,
    int limit = 100,
    String? search,
  }) async {
    final paged = await fetchTeacherStudentsPaged(
      page: page,
      limit: limit,
      search: search,
    );
    return paged.rows;
  }

  /// `GET /api/teacher/students?page=&limit=&q=` — paginated + server-side
  /// search by name OR phone. The MAIN API caps `limit` at MAX_LIMIT=100 (Zod
  /// `paginationQuerySchema`). Callers that need more should page.
  Future<({
    List<({String id, String name})> rows,
    int total,
    int page,
    int totalPages,
  })> fetchTeacherStudentsPaged({
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    final mainDio = await _buildMainApiDio();
    final res = await mainDio.get(
      '/teacher/students',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      },
    );
    _ensureMainApiSuccess(res, 'فشل تحميل الطلاب');
    final body = res.data is Map ? res.data as Map : const {};
    final rows = _extractRosterRows(body['data']);
    final pagination = (body['meta'] is Map)
        ? (body['meta'] as Map)['pagination']
        : null;
    final total = _asInt(pagination is Map ? pagination['total'] : null);
    final totalPages = _asInt(
      pagination is Map ? pagination['totalPages'] : null,
      fallback: rows.isEmpty ? 0 : 1,
    );
    return (rows: rows, total: total, page: page, totalPages: totalPages);
  }

  /// `GET /api/teacher/students/courses/names` — the teacher's own courses
  /// (id + course_name), used by the picker's "by-course" tab.
  Future<List<({String id, String name})>> fetchTeacherCourseNames() async {
    final mainDio = await _buildMainApiDio();
    final res = await mainDio.get('/teacher/students/courses/names');
    _ensureMainApiSuccess(res, 'فشل تحميل الكورسات');
    final raw = res.data is Map ? (res.data as Map)['data'] : null;
    final list = raw is List
        ? raw
        : (raw is Map && raw['data'] is List ? raw['data'] as List : const []);
    return list
        .whereType<Map>()
        .map((m) => (
              id: (m['id'] ?? '').toString(),
              name: (m['course_name'] ?? m['courseName'] ?? '').toString(),
            ))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  /// `GET /api/teacher/students/by-course/:courseId` — full list (no
  /// pagination) of confirmed students on one course. Picker uses this when
  /// the teacher taps a course to bulk-add its roster.
  Future<List<({String id, String name})>> fetchStudentsByCourse(
    String courseId,
  ) async {
    final mainDio = await _buildMainApiDio();
    final res = await mainDio.get('/teacher/students/by-course/$courseId');
    _ensureMainApiSuccess(res, 'فشل تحميل طلاب الكورس');
    return _extractRosterRows(
      res.data is Map ? (res.data as Map)['data'] : null,
    );
  }

  void _ensureMainApiSuccess(Response res, String fallbackMessage) {
    if (res.statusCode == null ||
        res.statusCode! >= 400 ||
        (res.data is Map && res.data['success'] == false)) {
      throw ChatApiException(
        (res.data is Map ? res.data['message']?.toString() : null) ??
            fallbackMessage,
        res.statusCode ?? 0,
        res.data,
      );
    }
  }

  List<({String id, String name})> _extractRosterRows(dynamic raw) {
    final list = raw is List
        ? raw
        : (raw is Map && raw['data'] is List ? raw['data'] as List : const []);
    return list
        .whereType<Map>()
        .map((m) => (
              id: (m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
            ))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  // ---- Helpers -------------------------------------------------------------

  void _ensureSuccess(Response res) {
    final ok = res.statusCode != null && res.statusCode! < 400;
    if (ok && res.data is Map && res.data['success'] == true) return;
    final msg = (res.data is Map && res.data['message'] is String)
        ? res.data['message'] as String
        : 'فشل في معالجة الطلب';
    throw ChatApiException(msg, res.statusCode ?? 0, res.data);
  }
}

class ChatApiException implements Exception {
  ChatApiException(this.message, this.statusCode, this.body);
  final String message;
  final int statusCode;
  final dynamic body;
  @override
  String toString() => 'ChatApiException($statusCode): $message';
}
